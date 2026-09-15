# The cellspec 1.0 specification as data. The validator, the constructor, the
# writer, the JSON schema test and the specification vignette all read these
# objects, so a rule is written down exactly once.

.cs_spec_version <- "1.0.0"

# One row per specified column of a component. `type` is the R storage type
# the column must have ("character", "double", "integer"); `requirement`
# follows RFC 2119 (MUST, SHOULD, MAY).
.cs_columns <- function() {
  rows <- list(
    # cells
    c("cells", "cell_id", "character", "MUST", "Cell identifier, unique within `image_id`, never recycled."),
    c("cells", "image_id", "character", "MUST", "Key into `images`."),
    c("cells", "sample_id", "character", "MUST", "Biological sample (slide or section); constant per image."),
    c("cells", "x", "double", "MUST", "Centroid, micrometres, image frame."),
    c("cells", "y", "double", "MUST", "Centroid, micrometres, image frame."),
    c("cells", "area", "double", "SHOULD", "Whole-cell area, square micrometres."),
    c("cells", "x_px", "double", "MAY", "Centroid in full-resolution pixels."),
    c("cells", "y_px", "double", "MAY", "Centroid in full-resolution pixels."),
    c("cells", "object_type", "character", "MAY", "Object type as exported by the tool, e.g. `cell`."),
    c("cells", "parent", "character", "MAY", "Parent annotation name as exported by the tool."),
    c("cells", "classification", "character", "MAY", "Class assigned inside the source tool."),
    c("cells", "tile_id", "character", "MAY", "Tile that owns the cell in tiled runs."),
    c("cells", "region__<layer>", "character", "MAY", "Region label for annotation layer `<layer>`."),
    c("cells", "boundary_distance__<layer>", "double", "MAY", "Signed distance to the region boundary of `<layer>`, micrometres, negative inside."),
    # dictionary
    c("dictionary", "feature_id", "character", "MUST", "Unique key; equals the measurement column name."),
    c("dictionary", "kind", "character", "MUST", "`intensity`, `shape` or `other`."),
    c("dictionary", "marker", "character", "MUST", "Marker name for intensity features, otherwise `NA`."),
    c("dictionary", "compartment", "character", "MUST", "Compartment for intensity and shape features, otherwise `NA`."),
    c("dictionary", "statistic", "character", "MUST", "Statistic from the vocabulary (free text for `other`)."),
    c("dictionary", "unit", "character", "MUST", "Unit from the vocabulary."),
    c("dictionary", "source_name", "character", "MUST", "The exact original column header."),
    c("dictionary", "marker_source", "character", "MAY", "Marker name before applying a marker map."),
    # images
    c("images", "image_id", "character", "MUST", "Unique image identifier."),
    c("images", "sample_id", "character", "MUST", "Biological sample of the image."),
    c("images", "subject_id", "character", "MAY", "Pseudonymised subject identifier."),
    c("images", "pixel_size", "double", "MUST", "Micrometres per pixel at full resolution."),
    c("images", "pixel_size_y", "double", "MAY", "Only when pixels are not square."),
    c("images", "width_px", "integer", "SHOULD", "Full-resolution width in pixels."),
    c("images", "height_px", "integer", "SHOULD", "Full-resolution height in pixels."),
    c("images", "platform", "character", "MAY", "Imaging platform, e.g. `PhenoCycler-Fusion`."),
    c("images", "source_image", "character", "MAY", "Image file name (not a full path)."),
    c("images", "source_image_sha256", "character", "MAY", "SHA-256 of the image file."),
    c("images", "geometry_ref", "character", "MAY", "Relative path to a GeoJSON file of cell outlines."),
    # channels
    c("channels", "image_id", "character", "MUST", "Key into `images`."),
    c("channels", "channel_index", "integer", "MUST", "1-based, contiguous per image."),
    c("channels", "channel_name", "character", "MUST", "Channel name as stored in the image."),
    c("channels", "marker", "character", "MUST", "Marker after mapping; equals `channel_name` when unmapped."),
    # adjacency
    c("adjacency", "image_id", "character", "MUST", "Image of both cells."),
    c("adjacency", "cell_id_a", "character", "MUST", "Smaller cell identifier of the pair (byte order)."),
    c("adjacency", "cell_id_b", "character", "MUST", "Larger cell identifier of the pair."),
    c("adjacency", "shared_boundary", "double", "MUST", "Shared boundary length, micrometres."),
    c("adjacency", "method", "character", "MUST", "How contacts were derived.")
  )
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(out) <- c("component", "column", "type", "requirement", "description")
  out
}

# Controlled vocabularies: one row per allowed value.
.cs_vocab <- function() {
  rows <- list(
    c("kind", "intensity", "Signal of one marker in one compartment."),
    c("kind", "shape", "Morphology of one compartment."),
    c("kind", "other", "Anything else; kept with its original header."),
    c("compartment", "cell", "Whole cell."),
    c("compartment", "nucleus", "Nucleus."),
    c("compartment", "cytoplasm", "Cell minus nucleus."),
    c("compartment", "membrane", "Cell boundary band."),
    c("intensity_statistic", "mean", "Mean intensity."),
    c("intensity_statistic", "median", "Median intensity."),
    c("intensity_statistic", "sd", "Standard deviation."),
    c("intensity_statistic", "min", "Minimum."),
    c("intensity_statistic", "max", "Maximum."),
    c("intensity_statistic", "sum", "Sum (integrated intensity)."),
    c("intensity_statistic", "variance", "Variance."),
    c("shape_statistic", "area", "Area."),
    c("shape_statistic", "perimeter", "Perimeter."),
    c("shape_statistic", "length", "Boundary length."),
    c("shape_statistic", "circularity", "Circularity."),
    c("shape_statistic", "solidity", "Solidity (area / convex hull area)."),
    c("shape_statistic", "max_diameter", "Maximum diameter."),
    c("shape_statistic", "min_diameter", "Minimum diameter."),
    c("shape_statistic", "max_caliper", "Maximum caliper."),
    c("shape_statistic", "min_caliper", "Minimum caliper."),
    c("shape_statistic", "eccentricity", "Eccentricity."),
    c("shape_statistic", "major_axis_length", "Major axis of the fitted ellipse."),
    c("shape_statistic", "minor_axis_length", "Minor axis of the fitted ellipse."),
    c("shape_statistic", "extent", "Area / bounding box area."),
    c("shape_statistic", "orientation", "Angle of the major axis."),
    c("shape_statistic", "nucleus_cell_area_ratio", "Nucleus area / cell area."),
    c("unit", "a.u.", "Arbitrary intensity units, as exported."),
    c("unit", "um", "Micrometres."),
    c("unit", "um2", "Square micrometres."),
    c("unit", "px", "Pixels."),
    c("unit", "px2", "Square pixels."),
    c("unit", "rad", "Radians."),
    c("unit", "1", "Dimensionless."),
    c("adjacency_method", "mask_touching", "Label masks share at least one pixel edge."),
    c("adjacency_method", "polygon_intersection", "Cell polygons intersect or touch."),
    c("adjacency_method", "delaunay", "Delaunay triangulation of centroids."),
    c("support", "ok", "Marker has usable variation."),
    c("support", "constant", "All non-missing values are identical."),
    c("support", "near_constant", "The 1st and 99th percentiles are identical."),
    c("support", "mostly_na", "More than half of the values are missing.")
  )
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(out) <- c("vocabulary", "value", "description")
  out
}

.cs_vocab_values <- function(vocabulary) {
  v <- .cs_vocab()
  v$value[v$vocabulary == vocabulary]
}

.cs_required_columns <- function(component) {
  cols <- .cs_columns()
  cols$column[cols$component == component & cols$requirement == "MUST"]
}

# Named vector column -> type for the fixed (non-prefix) columns of a component.
.cs_column_types <- function(component) {
  cols <- .cs_columns()
  cols <- cols[cols$component == component & !grepl("<layer>", cols$column, fixed = TRUE), ]
  stats::setNames(cols$type, cols$column)
}

.cs_reserved_prefixes <- c(
  region = "region__",
  boundary_distance = "boundary_distance__",
  internal = "cs__"
)

.cs_layer_pattern <- "^[A-Za-z0-9][A-Za-z0-9_.-]*$"

# QuPath-style labels to cellspec statistics. Keys are compared after
# lower-casing, so `Mean` and `mean` map alike.
.cs_statistic_labels <- c(
  "mean" = "mean",
  "median" = "median",
  "std.dev." = "sd",
  "std.dev" = "sd",
  "std dev" = "sd",
  "sd" = "sd",
  "min" = "min",
  "max" = "max",
  "sum" = "sum",
  "variance" = "variance"
)

#' Version of the cellspec specification
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the version of the `cellspec` format that this build of cellspecR
#' writes and validates. Readers of major version 1 accept every 1.y file
#' whose minor version is not newer than their own.
#'
#' @return A single string in semantic versioning form, for example `"1.0.0"`.
#' @family specification
#' @seealso `vignette("specification", package = "cellspecR")`
#' @export
#' @examples
#' cs_spec_version()
cs_spec_version <- function() {
  .cs_spec_version
}

#' Columns and controlled vocabularies of the cellspec format
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the specification tables as data: the columns each component may
#' carry, and the allowed values of every controlled vocabulary. The
#' validator ([cs_validate()]) enforces exactly these tables, so other
#' packages can use them to build compatible objects.
#'
#' @param what Which table to return: `"columns"`, `"vocabularies"` or
#'   `"checks"`.
#' @return For `what = "columns"`, a data frame with one row per specified
#'   column and the character columns `component` (`"cells"`, `"dictionary"`,
#'   `"images"`, `"channels"`, `"adjacency"`), `column`, `type` (R storage
#'   type), `requirement` (`"MUST"`, `"SHOULD"`, `"MAY"`) and `description`.
#'   For `what = "vocabularies"`, a data frame with the character columns
#'   `vocabulary`, `value` and `description`. For `what = "checks"`, the
#'   validation catalogue used by [cs_validate()]: character columns `check`,
#'   `level` (`"structure"` or `"semantic"`) and `description`.
#' @family specification
#' @seealso `vignette("specification", package = "cellspecR")`
#' @export
#' @examples
#' cols <- cs_vocabulary("columns")
#' cols[cols$component == "cells", c("column", "type", "requirement")]
#'
#' voc <- cs_vocabulary("vocabularies")
#' voc$value[voc$vocabulary == "compartment"]
#'
#' head(cs_vocabulary("checks"))
cs_vocabulary <- function(what = c("columns", "vocabularies", "checks")) {
  what <- rlang::arg_match(what)
  switch(what,
    columns = .cs_columns(),
    vocabularies = .cs_vocab(),
    checks = .cs_checks()
  )
}
