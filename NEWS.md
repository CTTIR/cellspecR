# cellspecR (development version)

* Standardize the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.

* `cs_read_npy()` and `cs_read_npz()` read NumPy array files and archives in
  base R (booleans, integers, floats, complex, fixed-width strings; C or
  Fortran order); `cs_write_npy()` and `cs_write_npz()` write them without an
  external zip program.
* Signal policies can declare separate preferred and fallback finite domains, including negative finite measurements. Existing minimum-domain defaults and five-column policies remain unchanged. Extended seven-column policies preserve both domains through JSON and CSV.

* Canonical TSV decimal conversion now preserves double precision on platforms
  where extended precision equals double precision, including macOS ARM.
  The 17-digit file format and exact-value roundtrip contract are unchanged.

* Header-only TSV exports now write a complete gzip stream, including empty
  cell and adjacency tables. Their declared column types survive read-back.

* QuPath readers recognize compartment-first cell area and nuclear morphology
  with explicit units. Whole-cell area is kept separately from nuclear area;
  shape dictionaries retain the original headers and dimensional units.
* The segmantR reader converts one-based pixel-index centroid means to the
  image's pixel-edge coordinate frame and converts pixel area to square
  micrometres. Unrecognized centroid conventions are rejected. Crop, pyramid
  and anisotropic transforms must be handled explicitly before image integration.
  Raw shape measurements retain their pixel or radian units.

* `cs_write(overwrite = TRUE)` now replaces only an empty directory or an
  existing cellspec directory; any other directory is left untouched and an
  error is raised.

* Tiled QuPath done markers with `header_sha256` now verify header lines
  longer than 1,024 bytes instead of reporting a missing header.

* `cs_app()` now applies `max_upload_mb` as the Shiny upload limit while the
  application runs and restores the previous limit when it stops; uploads
  were previously capped at the 5 MB Shiny default.

* The default `plot()` overview leaves out the area panel when the cells table
  has no `area` column and the marker panel when there are no intensity
  features, instead of failing.

* `cs_as_anndata()` now defaults to `policy = NULL` and derives the policy
  the same way as `cs_as_spe()`.

* With `keep_other = TRUE`, unmapped numeric columns whose names clean to the
  same identifier (for example "a b" and "a_b") are numbered
  (`other:a_b`, `other:a_b_1`) instead of aborting the read.

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

* Signal-policy I/O preserves structured error classes when parser diagnostics or paths contain literal braces.
