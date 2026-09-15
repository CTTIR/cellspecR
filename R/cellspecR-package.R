#' cellspecR: Read, Validate and Store Multiplexed Imaging Cell Tables
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' cellspecR defines `cellspec`, one table format for segmented cells from
#' multiplexed tissue images, reads the exports of common image-analysis tools
#' into it, checks the result, and writes it to disk with a checksum manifest
#' so that later analysis steps can prove what they read.
#'
#' The format is described in `vignette("specification", package = "cellspecR")`.
#'
#' @section Main functions:
#' * Specification: [cs_spec_version()], [cs_vocabulary()].
#' * Object: [cs_new()], [cs_cells()], [cs_measurements()], [cs_dictionary()],
#'   [cs_images()], [cs_channels()], [cs_provenance()], [cs_adjacency()],
#'   [cs_features()], [cs_markers()], [is_cellspec()].
#' * Methods: [print.cellspec()], [summary.cellspec()], [dim.cellspec()],
#'   \code{[.cellspec}, [as.data.frame.cellspec()].
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
