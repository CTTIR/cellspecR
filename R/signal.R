# Signal selection policies and marker-name mappings.

.cs_signal_policy_columns <- c(
  "marker", "compartment", "statistic", "fallback_compartment", "min_value"
)

.cs_signal_compartments <- function() {
  .cs_vocab_values("compartment")
}

.cs_signal_statistics <- function() {
  .cs_vocab_values("intensity_statistic")
}

.cs_recycle_signal_argument <- function(x, n, arg, call) {
  if (length(x) == 1L || length(x) == n) {
    return(rep(x, length.out = n))
  }
  .cs_abort(
    c(
      "{.arg {arg}} must have length 1 or the number of markers ({n}).",
      "x" = "Got length {length(x)} for {n} marker{?s}."
    ),
    call = call
  )
}

.cs_validate_signal_policy <- function(policy,
                                       arg = "policy",
                                       require_class = TRUE,
                                       call = rlang::caller_env()) {
  if (!is.data.frame(policy) || (require_class && !inherits(policy, "cs_signal_policy"))) {
    expected <- if (require_class) "a `cs_signal_policy` data frame" else "a data frame"
    .cs_abort(
      c(
        "{.arg {arg}} must be {expected}.",
        "x" = "Got {.obj_type_friendly {policy}}."
      ),
      call = call
    )
  }
  if (!identical(names(policy), .cs_signal_policy_columns)) {
    .cs_abort(
      c(
        "{.arg {arg}} has the wrong columns.",
        "x" = paste0(
          "Expected columns: ",
          paste(.cs_signal_policy_columns, collapse = ", "),
          "."
        )
      ),
      call = call
    )
  }
  if (nrow(policy) < 1L) {
    .cs_abort("{.arg {arg}} must contain at least one marker.", call = call)
  }
  if (!is.character(policy$marker) ||
      !is.character(policy$compartment) ||
      !is.character(policy$statistic) ||
      !is.character(policy$fallback_compartment) ||
      !is.numeric(policy$min_value)) {
    .cs_abort(
      c(
        "{.arg {arg}} has invalid column types.",
        "x" = "The first four columns must be character and `min_value` must be numeric."
      ),
      call = call
    )
  }
  if (anyNA(policy$marker) || any(!nzchar(policy$marker)) ||
      any(policy$marker != trimws(policy$marker)) ||
      any(grepl(":", policy$marker, fixed = TRUE)) ||
      anyDuplicated(policy$marker)) {
    .cs_abort(
      c(
        "{.arg {arg}} contains invalid or duplicated markers.",
        "x" = "Markers must be unique, trimmed, non-empty and contain no `:`."
      ),
      call = call
    )
  }
  compartments <- .cs_signal_compartments()
  if (anyNA(policy$compartment) || any(!policy$compartment %in% compartments)) {
    .cs_abort(
      c(
        "{.arg {arg}} contains an invalid preferred compartment.",
        "x" = paste0("Allowed values are ", paste(compartments, collapse = ", "), ".")
      ),
      call = call
    )
  }
  statistics <- .cs_signal_statistics()
  if (anyNA(policy$statistic) || any(!policy$statistic %in% statistics)) {
    .cs_abort(
      c(
        "{.arg {arg}} contains an invalid intensity statistic.",
        "x" = paste0("Allowed values are ", paste(statistics, collapse = ", "), ".")
      ),
      call = call
    )
  }
  fallback <- policy$fallback_compartment
  fallback_bad <- !is.na(fallback) &
    (!nzchar(fallback) | fallback != trimws(fallback) |
      !fallback %in% .cs_signal_compartments())
  if (any(fallback_bad)) {
    .cs_abort(
      c(
        "{.arg {arg}} contains an invalid fallback compartment.",
        "x" = "Fallback compartments must be `NA` or one of the compartment vocabulary values."
      ),
      call = call
    )
  }
  if (anyNA(policy$min_value) || any(!is.finite(policy$min_value)) ||
      any(policy$min_value < 0)) {
    .cs_abort(
      c(
        "{.arg {arg}} contains an invalid `min_value`.",
        "x" = "Values must be finite and greater than or equal to zero."
      ),
      call = call
    )
  }
  invisible(policy)
}

.cs_signal_policy_data <- function(policy, call = rlang::caller_env()) {
  if (!is.data.frame(policy)) {
    .cs_abort("{.arg policy} must be a data frame.", call = call)
  }
  if (is.logical(policy$fallback_compartment) &&
      all(is.na(policy$fallback_compartment))) {
    policy$fallback_compartment <- rep(NA_character_, nrow(policy))
  }
  if (is.integer(policy$min_value)) {
    policy$min_value <- as.double(policy$min_value)
  }
  class(policy) <- c("cs_signal_policy", "data.frame")
  .cs_validate_signal_policy(policy, call = call)
  policy
}

.cs_signal_policy_format <- function(path, format, call) {
  if (!is.null(format)) {
    .cs_check_string(format, arg = "format", call = call)
    if (!format %in% c("json", "csv")) {
      .cs_abort(
        c(
          "{.arg format} must be `json` or `csv`.",
          "x" = "Got {.val {format}}."
        ),
        call = call
      )
    }
    return(format)
  }
  ext <- tolower(sub("^.*[.]", "", path))
  if (!ext %in% c("json", "csv")) {
    .cs_abort(
      c(
        "Cannot determine the signal policy format from {.path {path}}.",
        "i" = "Supply {.arg format} as `json` or `csv`."
      ),
      call = call
    )
  }
  ext
}

.cs_check_signal_destination <- function(path, call) {
  parent <- dirname(path)
  if (dir.exists(path) || !dir.exists(parent)) {
    .cs_abort(
      c(
        "{.arg path} must name a writable file location.",
        "x" = "The destination or its parent directory is not usable."
      ),
      class = "cellspec_error_format",
      call = call
    )
  }
  invisible(path)
}

#' Create a signal selection policy
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates one validated row per marker. Signal policies make the selected
#' compartment, statistic, fallback and minimum usable value explicit.
#'
#' @param marker Character vector of unique marker names.
#' @param compartment Preferred compartment for each marker. A single value is
#'   recycled across `marker`.
#' @param statistic Intensity statistic for each marker. A single value is
#'   recycled across `marker`.
#' @param fallback_compartment Optional fallback compartment for each marker;
#'   `NA` disables fallback. A single value is recycled across `marker`.
#' @param min_value Minimum usable value for each marker. Values below this
#'   threshold are unavailable. A single value is recycled across `marker`.
#' @return A data frame with class `cs_signal_policy` and columns `marker`,
#'   `compartment`, `statistic`, `fallback_compartment` and `min_value`.
#' @family signals
#' @seealso [cs_signal_matrix()], [cs_marker_map()]
#' @export
#' @examples
#' cs_signal_policy(
#'   marker = c("PanCK", "FOXP3"),
#'   compartment = c("cytoplasm", "nucleus"),
#'   fallback_compartment = "cell"
#' )
cs_signal_policy <- function(marker,
                             compartment = "cell",
                             statistic = "mean",
                             fallback_compartment = NA_character_,
                             min_value = 0) {
  call <- rlang::caller_env()
  if (!is.character(marker) || length(marker) < 1L) {
    .cs_abort("{.arg marker} must be a non-empty character vector.", call = call)
  }
  n <- length(marker)
  args <- list(
    compartment = compartment,
    statistic = statistic,
    fallback_compartment = fallback_compartment,
    min_value = min_value
  )
  for (nm in names(args)) {
    value <- args[[nm]]
    if (nm == "min_value") {
      if (!is.numeric(value) || length(value) < 1L) {
        .cs_abort("{.arg min_value} must be a numeric vector.", call = call)
      }
    } else if (!is.character(value) || length(value) < 1L) {
      .cs_abort("{.arg {nm}} must be a non-empty character vector.", call = call)
    }
    args[[nm]] <- .cs_recycle_signal_argument(value, n, nm, call)
  }
  policy <- data.frame(
    marker = marker,
    compartment = args$compartment,
    statistic = args$statistic,
    fallback_compartment = args$fallback_compartment,
    min_value = as.double(args$min_value),
    stringsAsFactors = FALSE
  )
  class(policy) <- c("cs_signal_policy", "data.frame")
  .cs_validate_signal_policy(policy, call = call)
  policy
}

#' Select one signal per cell and marker
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Applies a `cs_signal_policy` to the intensity measurements in a
#' `cellspec` object. A preferred value is used when it is non-missing and at
#' least the row's `min_value`; otherwise the configured fallback is tested.
#'
#' @param x A `cellspec` object.
#' @param policy A `cs_signal_policy` created by [cs_signal_policy()].
#' @param image_id Optional image identifier. When supplied, only cells from
#'   that image are returned.
#' @return A list with `signal`, a cells by markers numeric matrix, `source`, a
#'   character matrix describing the selected source, and `policy`, the
#'   validated policy. Source values are `"<compartment>:<statistic>"`,
#'   `"fallback:<compartment>:<statistic>"` or `"unavailable"`.
#' @family signals
#' @seealso [cs_signal_policy()]
#' @export
#' @examples
#' x <- cs_example()
#' policy <- cs_signal_policy(cs_markers(x))
#' selected <- cs_signal_matrix(x, policy)
#' selected$signal[, 1:2]
cs_signal_matrix <- function(x, policy, image_id = NULL) {
  call <- rlang::caller_env()
  .cs_check_cellspec(x, call = call)
  .cs_validate_signal_policy(policy, call = call)
  if (!is.null(image_id)) {
    .cs_check_string(image_id, arg = "image_id", call = call)
    if (!image_id %in% x$images$image_id) {
      .cs_abort(
        c(
          "{.arg image_id} is not present in {.arg x}.",
          "x" = "No image has identifier {.val {image_id}}."
        ),
        class = "cellspec_error_invalid",
        call = call
      )
    }
  }
  keep <- if (is.null(image_id)) {
    rep(TRUE, nrow(x$cells))
  } else {
    x$cells$image_id == image_id
  }
  rows <- which(keep)
  markers <- policy$marker
  signal <- matrix(
    NA_real_,
    nrow = length(rows),
    ncol = nrow(policy),
    dimnames = list(x$cells$cell_id[rows], markers)
  )
  source <- matrix(
    "unavailable",
    nrow = length(rows),
    ncol = nrow(policy),
    dimnames = list(x$cells$cell_id[rows], markers)
  )

  for (j in seq_len(nrow(policy))) {
    preferred_id <- cs_features(
      x,
      kind = "intensity",
      marker = policy$marker[[j]],
      compartment = policy$compartment[[j]],
      statistic = policy$statistic[[j]]
    )
    preferred <- if (length(preferred_id) == 0L) {
      rep(NA_real_, length(rows))
    } else {
      x$measurements[rows, preferred_id[[1L]], drop = TRUE]
    }
    preferred_ok <- !is.na(preferred) & is.finite(preferred) &
      preferred >= policy$min_value[[j]]
    if (any(preferred_ok)) {
      signal[preferred_ok, j] <- preferred[preferred_ok]
      source[preferred_ok, j] <- paste0(
        policy$compartment[[j]], ":", policy$statistic[[j]]
      )
    }

    fallback <- policy$fallback_compartment[[j]]
    if (!is.na(fallback)) {
      fallback_id <- cs_features(
        x,
        kind = "intensity",
        marker = policy$marker[[j]],
        compartment = fallback,
        statistic = policy$statistic[[j]]
      )
      fallback_values <- if (length(fallback_id) == 0L) {
        rep(NA_real_, length(rows))
      } else {
        x$measurements[rows, fallback_id[[1L]], drop = TRUE]
      }
      fallback_ok <- !preferred_ok & !is.na(fallback_values) &
        is.finite(fallback_values) & fallback_values >= policy$min_value[[j]]
      if (any(fallback_ok)) {
        signal[fallback_ok, j] <- fallback_values[fallback_ok]
        source[fallback_ok, j] <- paste0(
          "fallback:", fallback, ":", policy$statistic[[j]]
        )
      }
    }
  }
  list(signal = signal, source = source, policy = policy)
}

#' Create a marker-name mapping
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Builds a two-column mapping from source marker names to canonical marker
#' names. Source names must be unique; several source names may map to the same
#' canonical name when they represent the same marker across files.
#'
#' @param from Character vector of source marker names.
#' @param to Character vector of canonical marker names, the same length as
#'   `from`.
#' @return A two-column data frame with character columns `from` and `to`.
#' @family signals
#' @seealso [cs_signal_policy()]
#' @export
#' @examples
#' cs_marker_map(c("PanCK", "CD68"), c("Pan-Cytokeratin", "CD68"))
cs_marker_map <- function(from, to) {
  call <- rlang::caller_env()
  if (!is.character(from) || !is.character(to) || length(from) != length(to)) {
    .cs_abort(
      c(
        "{.arg from} and {.arg to} must be character vectors of equal length.",
        "x" = "Got lengths {length(from)} and {length(to)}."
      ),
      call = call
    )
  }
  if (length(from) == 0L) {
    return(data.frame(from = character(), to = character(), stringsAsFactors = FALSE))
  }
  bad <- function(value) {
    anyNA(value) || any(!nzchar(value)) || any(value != trimws(value)) ||
      any(grepl(":", value, fixed = TRUE))
  }
  if (bad(from) || bad(to)) {
    .cs_abort(
      "Marker names in {.arg from} and {.arg to} must be non-empty, trimmed and contain no `:`.",
      call = call
    )
  }
  if (anyDuplicated(from)) {
    .cs_abort(
      "{.arg from} contains duplicated source marker names.",
      call = call
    )
  }
  data.frame(from = from, to = to, stringsAsFactors = FALSE)
}

#' Write a signal policy as JSON or CSV
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Writes a validated signal policy. The format is inferred from the `.json`
#' or `.csv` extension unless `format` is supplied explicitly.
#'
#' @param policy A `cs_signal_policy` object.
#' @param path Destination file path.
#' @param format Either `"json"` or `"csv"`; by default inferred from
#'   `path`.
#' @return `policy`, invisibly.
#' @family signals
#' @seealso [cs_read_signal_policy()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".json")
#' cs_write_signal_policy(cs_signal_policy("CD3e"), path)
cs_write_signal_policy <- function(policy, path, format = NULL) {
  call <- rlang::caller_env()
  .cs_validate_signal_policy(policy, call = call)
  .cs_check_string(path, call = call)
  .cs_check_signal_destination(path, call)
  format <- .cs_signal_policy_format(path, format, call)
  if (format == "json") {
    tryCatch(
      jsonlite::write_json(
        policy,
        path,
        dataframe = "rows",
        auto_unbox = TRUE,
        na = "null",
        digits = 17,
        pretty = TRUE
      ),
      error = function(e) {
        .cs_abort(
          c(
            "Could not write the signal policy to {.path {path}}.",
            "x" = conditionMessage(e)
          ),
          class = "cellspec_error_format",
          call = call
        )
      }
    )
  } else {
    csv <- policy
    min_text <- rep(NA_character_, nrow(csv))
    present <- !is.na(csv$min_value)
    min_text[present] <- sprintf("%.17g", csv$min_value[present])
    csv$min_value <- min_text
    tryCatch(
      data.table::fwrite(csv, path, na = "NA", quote = TRUE),
      error = function(e) {
        .cs_abort(
          c(
            "Could not write the signal policy to {.path {path}}.",
            "x" = conditionMessage(e)
          ),
          class = "cellspec_error_format",
          call = call
        )
      }
    )
  }
  invisible(policy)
}

#' Read a signal policy from JSON or CSV
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads and validates a policy written by [cs_write_signal_policy()]. The
#' format is inferred from the `.json` or `.csv` extension unless `format` is
#' supplied explicitly.
#'
#' @param path Source file path.
#' @param format Either `"json"` or `"csv"`; by default inferred from
#'   `path`.
#' @return A validated data frame with class `cs_signal_policy`.
#' @family signals
#' @seealso [cs_write_signal_policy()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".json")
#' cs_write_signal_policy(cs_signal_policy("CD3e"), path)
#' cs_read_signal_policy(path)
cs_read_signal_policy <- function(path, format = NULL) {
  call <- rlang::caller_env()
  .cs_check_path(path, call = call)
  format <- .cs_signal_policy_format(path, format, call)
  raw <- tryCatch(
    if (format == "json") {
      jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
    } else {
      data.table::fread(path, data.table = FALSE, encoding = "UTF-8")
    },
    error = function(e) {
      .cs_abort(
        c(
          "Could not read the signal policy from {.path {path}}.",
          "x" = conditionMessage(e)
        ),
        class = "cellspec_error_format",
        call = call
      )
    }
  )
  .cs_signal_policy_data(raw, call = call)
}
