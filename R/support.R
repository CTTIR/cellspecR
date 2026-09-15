#' Summarise the signal support of features per image
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Describes, for every image and feature, how much usable variation a
#' feature carries. A marker whose channel was blank, saturated or not
#' acquired shows up as `"constant"` or `"near_constant"` here before any
#' normalisation or gating hides the problem. Other packages (for example a
#' gating package) use the `support` column to declare markers non-callable.
#'
#' The `support` classes are assigned in this order:
#' 1. `"mostly_na"`: more than half of the values are missing.
#' 2. `"constant"`: all non-missing values are identical (for example an
#'    all-zero channel).
#' 3. `"near_constant"`: the 1st and 99th percentiles are identical, so at
#'    most about 1% of cells differ from the rest.
#' 4. `"ok"`: otherwise.
#'
#' @param x A `cellspec` object.
#' @param features Character vector of feature identifiers. Defaults to all
#'   mean intensity features.
#' @param zero_tol Values with absolute value at most `zero_tol` count as zero
#'   for `fraction_zero`.
#' @return A data frame with one row per image and feature and the columns
#'   `image_id`, `feature_id`, `marker`, `compartment`, `statistic`
#'   (character), `n`, `n_na` (integer), `fraction_zero`, `sd`, `mad`, `q01`,
#'   `q50`, `q99` (double, computed on non-missing values; `NA` when none)
#'   and `support` (character, see Details).
#' @family validation
#' @export
#' @examples
#' x <- cs_example()
#' cs_feature_support(x)
#'
#' # A blank channel is reported as constant
#' x$measurements[, "cell:FOXP3:mean"] <- 0
#' s <- cs_feature_support(x)
#' s[s$marker == "FOXP3", c("image_id", "feature_id", "support")]
cs_feature_support <- function(x,
                               features = cs_features(x, kind = "intensity", statistic = "mean"),
                               zero_tol = 0) {
  .cs_check_cellspec(x)
  .cs_check_number(zero_tol, min = 0)
  if (!is.character(features)) {
    .cs_abort(c(
      "{.arg features} must be a character vector of feature identifiers.",
      "x" = "Got {.obj_type_friendly {features}}."
    ))
  }
  dict <- x$dictionary
  unknown <- setdiff(features, dict$feature_id)
  if (length(unknown) > 0L) {
    .cs_abort(c(
      "{.arg features} must name existing features.",
      "x" = "Unknown feature{?s}: {.val {unknown}}."
    ))
  }
  m <- x$measurements
  rows_by_image <- split(seq_len(nrow(x$cells)), factor(x$cells$image_id, levels = unique(x$images$image_id)))
  rows_by_image <- rows_by_image[lengths(rows_by_image) > 0L]
  d_idx <- match(features, dict$feature_id)

  if (length(features) == 0L) {
    rows_by_image <- list()
  }
  out <- vector("list", length(rows_by_image))
  for (k in seq_along(rows_by_image)) {
    rows <- rows_by_image[[k]]
    stats_list <- lapply(features, function(f) .cs_support_stats(m[rows, f], zero_tol))
    s <- do.call(rbind, stats_list)
    out[[k]] <- data.frame(
      image_id = rep(names(rows_by_image)[[k]], length(features)),
      feature_id = features,
      marker = dict$marker[d_idx],
      compartment = dict$compartment[d_idx],
      statistic = dict$statistic[d_idx],
      n = rep(length(rows), length(features)),
      n_na = as.integer(s[, "n_na"]),
      fraction_zero = s[, "fraction_zero"],
      sd = s[, "sd"],
      mad = s[, "mad"],
      q01 = s[, "q01"],
      q50 = s[, "q50"],
      q99 = s[, "q99"],
      .range = s[, "range"],
      stringsAsFactors = FALSE
    )
  }
  if (length(out) == 0L) {
    res <- data.frame(
      image_id = character(), feature_id = character(), marker = character(),
      compartment = character(), statistic = character(), n = integer(),
      n_na = integer(), fraction_zero = double(), sd = double(), mad = double(),
      q01 = double(), q50 = double(), q99 = double(), .range = double(),
      stringsAsFactors = FALSE
    )
  } else {
    res <- do.call(rbind, out)
  }
  res$n <- as.integer(res$n)
  res$support <- .cs_support_class(res)
  res$.range <- NULL
  attr(res, "row.names") <- .set_row_names(nrow(res))
  res
}

.cs_support_stats <- function(v, zero_tol) {
  n_na <- sum(is.na(v))
  v <- v[!is.na(v)]
  if (length(v) == 0L) {
    return(c(n_na = n_na, fraction_zero = NA_real_, sd = NA_real_, mad = NA_real_,
             q01 = NA_real_, q50 = NA_real_, q99 = NA_real_, range = NA_real_))
  }
  q <- stats::quantile(v, c(0.01, 0.5, 0.99), names = FALSE, type = 7)
  c(
    n_na = n_na,
    fraction_zero = mean(abs(v) <= zero_tol),
    sd = if (length(v) > 1L) stats::sd(v) else NA_real_,
    mad = stats::mad(v),
    q01 = q[[1L]],
    q50 = q[[2L]],
    q99 = q[[3L]],
    range = max(v) - min(v)
  )
}

.cs_support_class <- function(res) {
  out <- rep("ok", nrow(res))
  n_valid <- res$n - res$n_na
  mostly_na <- n_valid == 0L | res$n_na > 0.5 * res$n
  # Exact range, not sd == 0: the standard deviation of identical values can
  # come out as a tiny positive number through rounding of the mean.
  constant <- !mostly_na & !is.na(res$.range) & res$.range == 0
  near <- !mostly_na & !constant & !is.na(res$q01) & res$q01 == res$q99
  out[near] <- "near_constant"
  out[constant] <- "constant"
  out[mostly_na] <- "mostly_na"
  out
}
