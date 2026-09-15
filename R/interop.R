# Optional interoperability with Bioconductor and scverse objects.

.cs_interop_abort <- function(message, class = "cellspec_error_format",
                               call = rlang::caller_env()) {
  .cs_abort(message, class = class, call = call, .envir = parent.frame())
}

.cs_interop_require <- function(package, call = rlang::caller_env()) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .cs_interop_abort(
      c(
        "Optional interoperability needs {.pkg {package}}.",
        "i" = "Install {.pkg {package}} to use this conversion."
      ),
      call = call
    )
  }
  invisible(TRUE)
}

.cs_policy_default <- function(x, policy, call = rlang::caller_env()) {
  if (!is.null(policy)) return(policy)
  markers <- cs_markers(x)
  if (length(markers) == 0L) {
    .cs_interop_abort("A signal policy is required when the object has no intensity markers.", class = "cellspec_error_invalid", call = call)
  }
  rows <- lapply(markers, function(marker) {
    entries <- x$dictionary[x$dictionary$kind == "intensity" & x$dictionary$marker == marker, , drop = FALSE]
    pairs <- unique(entries[c("compartment", "statistic")])
    if (nrow(pairs) != 1L) {
      .cs_interop_abort(
        c(
          "{.arg policy} is required because marker {.val {marker}} has multiple intensity sources.",
          "i" = "Choose one compartment and statistic with {.fn cs_signal_policy}."
        ),
        class = "cellspec_error_invalid", call = call
      )
    }
    data.frame(
      marker = marker, compartment = pairs$compartment[[1L]],
      statistic = pairs$statistic[[1L]], fallback_compartment = NA_character_,
      min_value = 0, stringsAsFactors = FALSE
    )
  })
  .cs_signal_policy_data(do.call(rbind, rows), call = call)
}

#' Convert a cellspec object to SpatialExperiment
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Converts selected signals to the main assay, stores every raw measurement
#' in an `altExp`, and records the cellspec metadata needed for a lossless
#' round trip.
#'
#' @param x A `cellspec` object.
#' @param policy A signal policy. It is required when a marker has more than
#'   one compartment or statistic; otherwise it can be omitted.
#' @param assay_name Name of the main signal assay.
#' @return A `SpatialExperiment` with cells as columns, markers as rows,
#'   `spatialCoords` containing `x` and `y`, and a `measurements` altExp.
#' @family interoperability
#' @export
#' @examples
#' if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
#'   x <- cs_example()
#'   policy <- cs_signal_policy(cs_markers(x))
#'   spe <- cs_as_spe(x, policy)
#'   spe
#' }
cs_as_spe <- function(x, policy = NULL, assay_name = "intensity") {
  call <- rlang::caller_env()
  .cs_check_cellspec(x, call = call)
  .cs_interop_require("SpatialExperiment", call = call)
  .cs_interop_require("SingleCellExperiment", call = call)
  .cs_interop_require("S4Vectors", call = call)
  .cs_check_string(assay_name, arg = "assay_name", call = call)
  policy <- .cs_policy_default(x, policy, call = call)
  .cs_validate_signal_policy(policy, call = call)
  selected <- cs_signal_matrix(x, policy)$signal
  cell_keys <- make.unique(paste(x$cells$image_id, x$cells$cell_id, sep = "::"))
  rownames(selected) <- cell_keys
  colnames(selected) <- policy$marker
  assay_matrix <- t(selected)
  rownames(assay_matrix) <- policy$marker
  coldata <- x$cells[, setdiff(names(x$cells), c("x", "y")), drop = FALSE]
  coldata <- S4Vectors::DataFrame(coldata, row.names = cell_keys)
  coords <- as.matrix(x$cells[c("x", "y")])
  rownames(coords) <- cell_keys
  spe <- tryCatch(
    SpatialExperiment::SpatialExperiment(
      assays = stats::setNames(list(assay_matrix), assay_name),
      colData = coldata,
      spatialCoords = coords
    ),
    error = function(error) {
      .cs_interop_abort(
        c("Could not construct a {.cls SpatialExperiment}.", "x" = conditionMessage(error)),
        call = call
      )
    }
  )
  raw <- t(x$measurements)
  rownames(raw) <- x$dictionary$feature_id
  colnames(raw) <- cell_keys
  raw_exp <- SingleCellExperiment::SingleCellExperiment(
    assays = list(measurements = raw),
    rowData = S4Vectors::DataFrame(x$dictionary, row.names = x$dictionary$feature_id)
  )
  SingleCellExperiment::altExp(spe, "measurements") <- raw_exp
  S4Vectors::metadata(spe)$cellspec <- list(
    spec_version = x$spec_version,
    images = x$images,
    channels = x$channels,
    provenance = x$provenance,
    policy = policy,
    adjacency = x$adjacency,
    cells_columns = names(x$cells)
  )
  spe
}

#' Convert a SpatialExperiment back to cellspec
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reconstructs the cellspec components stored by [cs_as_spe()].
#'
#' @param spe A `SpatialExperiment` created by [cs_as_spe()].
#' @return A validated `cellspec` object.
#' @family interoperability
#' @export
#' @examples
#' if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
#'   x <- cs_example()
#'   policy <- cs_signal_policy(cs_markers(x))
#'   identical(cs_cells(x), cs_cells(cs_from_spe(cs_as_spe(x, policy))))
#' }
cs_from_spe <- function(spe) {
  call <- rlang::caller_env()
  .cs_interop_require("SpatialExperiment", call = call)
  if (!inherits(spe, "SpatialExperiment")) {
    .cs_interop_abort("{.arg spe} must be a {.cls SpatialExperiment}.", call = call)
  }
  meta <- S4Vectors::metadata(spe)$cellspec
  if (!is.list(meta) || is.null(meta$images) || is.null(meta$channels) || is.null(meta$provenance)) {
    .cs_interop_abort("{.arg spe} has no cellspec conversion metadata.", call = call)
  }
  cells <- as.data.frame(SummarizedExperiment::colData(spe), stringsAsFactors = FALSE)
  coords <- SpatialExperiment::spatialCoords(spe)
  if (!all(c("x", "y") %in% colnames(coords))) {
    .cs_interop_abort("{.arg spe} must contain x and y spatial coordinates.", class = "cellspec_error_units", call = call)
  }
  cells$x <- as.double(coords[, "x"])
  cells$y <- as.double(coords[, "y"])
  cells <- cells[, unique(c(meta$cells_columns, "x", "y")), drop = FALSE]
  if (!"cell_id" %in% names(cells) || !"image_id" %in% names(cells)) {
    .cs_interop_abort("The SpatialExperiment colData lacks cellspec cell and image identifiers.", call = call)
  }
  raw_exp <- tryCatch(SingleCellExperiment::altExp(spe, "measurements"), error = function(e) NULL)
  if (is.null(raw_exp)) {
    .cs_interop_abort("The SpatialExperiment has no `measurements` altExp.", call = call)
  }
  measurements <- t(SummarizedExperiment::assay(raw_exp, "measurements"))
  dictionary <- as.data.frame(SummarizedExperiment::rowData(raw_exp), stringsAsFactors = FALSE)
  if (!"feature_id" %in% names(dictionary)) dictionary$feature_id <- rownames(dictionary)
  rownames(measurements) <- NULL
  colnames(measurements) <- dictionary$feature_id
  result <- .cs_build(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = meta$images,
    channels = meta$channels,
    provenance = meta$provenance,
    adjacency = meta$adjacency,
    adapter = "SpatialExperiment"
  )
  cs_assert_valid(result, level = "structure", call = call)
  result
}

#' Convert a cellspec object to AnnData
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates an AnnData object with cells in `obs`, selected marker signals in
#' `X`, and `x`/`y` in `obsm$spatial`. The optional `anndataR` package and its
#' Python runtime are required.
#'
#' @param x A `cellspec` object.
#' @param policy Signal policy used to form `X`.
#' @return An AnnData object supplied by `anndataR`.
#' @family interoperability
#' @export
#' @examples
#' if (requireNamespace("anndataR", quietly = TRUE)) {
#'   x <- cs_example()
#'   cs_as_anndata(x, cs_signal_policy(cs_markers(x)))
#' }
cs_as_anndata <- function(x, policy) {
  call <- rlang::caller_env()
  .cs_check_cellspec(x, call = call)
  .cs_interop_require("anndataR", call = call)
  policy <- .cs_policy_default(x, policy, call = call)
  .cs_validate_signal_policy(policy, call = call)
  signal <- cs_signal_matrix(x, policy)$signal
  cell_keys <- make.unique(paste(x$cells$image_id, x$cells$cell_id, sep = "::"))
  rownames(signal) <- cell_keys
  obs <- as.data.frame(x$cells, stringsAsFactors = FALSE)
  rownames(obs) <- cell_keys
  var <- data.frame(marker = policy$marker, row.names = policy$marker, stringsAsFactors = FALSE)
  obsm <- list(spatial = as.matrix(x$cells[c("x", "y")]))
  result <- tryCatch(
    anndataR::AnnData(X = signal, obs = obs, var = var, obsm = obsm,
                      uns = list(cellspec = list(
                        spec_version = x$spec_version,
                        images = x$images, channels = x$channels,
                        provenance = x$provenance, policy = policy
                      ))),
    error = function(error) {
      .cs_interop_abort(
        c("Could not construct AnnData through {.pkg anndataR}.", "x" = conditionMessage(error)),
        call = call
      )
    }
  )
  result
}
