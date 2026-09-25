# cellspecR (development version)

* QuPath readers recognize compartment-first cell area and nuclear morphology
  with explicit units. Whole-cell area is kept separately from nuclear area;
  shape dictionaries retain the original headers and dimensional units.
* The segmantR reader converts one-based pixel-index centroid means to the
  image's pixel-edge coordinate frame and converts pixel area to square
  micrometres. Unrecognized centroid conventions are rejected. Crop, pyramid
  and anisotropic transforms must be handled explicitly before image integration.
  Raw shape measurements retain their pixel or radian units.

# cellspecR 1.0.0

Initial CRAN release.

## Specification

* Added the cellspec 1.0 table contract, JSON Schema and vocabulary tables for
  segmented cells from multiplexed tissue images.

## Readers

* Added readers for QuPath, tiled QuPath, MCQuant, segmantR, inForm and mapped
  generic CSV/TSV tables, with format detection and provenance records.

## Validation

* Added structural and semantic validation, actionable reports, feature
  support summaries and deterministic synthetic examples.

## Canonical format

* Added Parquet storage with an exact text fallback, JSON sidecars, SHA-256
  manifests, completion markers and atomic staging.

## Signals

* Added explicit signal policies, marker maps and selected signal matrices with
  JSON and CSV persistence.

## Interoperability

* Added guarded conversion to and from SpatialExperiment and AnnData objects.

## Methods

* Added tile binding and merge helpers, cellspec subsetting and coercion, and
  quality-control map, marker, support, area and overview plots.

## Interactive front-end

* Added a local Shiny review app for reading exports, inspecting validation and
  downloading review tables.
