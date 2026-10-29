# cellspecR (development version)

* Standardize the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.

* `cs_read_npy()` and `cs_read_npz()` read NumPy array files and archives in
  base R (booleans, integers, floats, complex, fixed-width strings; C or
  Fortran order); `cs_write_npy()` and `cs_write_npz()` write them without an
  external zip program.
* Signal policies can declare separate preferred and fallback finite domains, including negative finite measurements. Existing minimum-domain defaults and five-column policies remain unchanged. Extended seven-column policies preserve both domains through JSON and CSV.

* Signal-policy I/O preserves structured error classes when parser diagnostics
  or paths contain literal braces.

* Canonical TSV decimal conversion now preserves double precision on platforms
  where extended precision equals double precision, including macOS ARM.
  The 17-digit file format and exact-value round-trip contract are unchanged.

* Header-only TSV exports now write a complete gzip stream, including empty
  cell and adjacency tables. Their declared column types survive read-back.

* QuPath readers recognize compartment-first cell area and nuclear morphology
  with explicit units. Whole-cell area is kept separately from nuclear area;
  shape dictionaries retain the original headers and dimensional units.
* The segmantR reader converts one-based pixel-index centroid means to the
  image's pixel-edge coordinate frame and converts pixel area to square
  micrometres. Unrecognised centroid conventions are rejected. Crop, pyramid
  and anisotropic transforms must be handled explicitly before image integration.
  Raw shape measurements retain their pixel or radian units.

* `cs_write(overwrite = TRUE)` now replaces only an empty directory or
  earlier `cs_write()` output: a directory whose `cellspec.json` carries the
  cellspec format marker and which holds no files other than those
  `cs_write()` creates. Any other directory is left untouched and an error
  names the unexpected entries.

* Tiled QuPath done markers with `header_sha256` now verify header lines
  longer than 1,024 bytes instead of reporting a missing header, and check
  the decompressed header line of gzip-compressed (`.gz`) tiles instead of
  their compressed bytes.

* `cs_app()` now applies `max_upload_mb` as the Shiny upload limit while the
  application runs and restores the previous limit when it stops; uploads
  were previously capped at the 5 MB Shiny default.

* The default `plot()` overview leaves out the area panel when the cells table
  has no `area` column and the marker panel when there are no intensity
  features, instead of failing.

* `cs_as_anndata()` now defaults to `policy = NULL` and derives the policy
  the same way as `cs_as_spe()`.

* `other` features whose source names clean to the same identifier are
  numbered with `make.unique(sep = "_")` instead of aborting the read. This
  covers unmapped numeric columns kept by `keep_other = TRUE` and
  measurements mapped with `kind = "other"`, also with `keep_other = FALSE`.
  Suffixes already in use are skipped: columns "a b", "a_b" and "a_b_1"
  become `other:a_b`, `other:a_b_2` and `other:a_b_1`.

* `summary()` and its print method handle valid objects without images.

* `cs_read_cellspec()` checks the row counts declared in `cellspec.json`
  before reading and reports a missing or malformed `n_rows` as a
  `cellspec_error_format`.

* `cs_write()` no longer advances the session random number generator when
  it names its staging and backup directories.

* Gzip-compressed tables and canonical `tsv.gz` files are decompressed in R
  on every platform instead of through an external `gzip` program. The
  result is checked against the gzip trailer (CRC-32 and length), so a
  truncated or corrupt file raises a `cellspec_error_format` instead of
  loading only part of its rows. A file whose tail was zero-filled back to its
  original size counts as truncated. BGZF files (`bgzip`) are checked block by
  block, may hold nothing but BGZF blocks and must end with the BGZF
  end-of-file block; other files made of several gzip members, which cannot
  be checked completely, are read with a `cellspec_warning_integrity`
  warning.

* cellspecR now requires data.table 1.17.0 or later. Earlier versions write
  `fwrite(compress = "gzip")` output as several gzip members, which
  `cs_read_cellspec()` cannot fully check, so it would warn on the `tsv.gz`
  files written by `cs_write()`.

# cellspecR 1.0.0

First public release, on GitHub.

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
