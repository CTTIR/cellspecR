# cellspecR 1.2.0

* `cs_read_npy()` and `cs_read_npz()` refuse a fixed-width string with a NUL
  character before its end as `cellspec_error_format`; before, R stopped with
  the error `embedded nul in string`.
* `cs_read_cellspec()` returns text with double quotes unchanged from
  `tsv.gz` directories. A value such as `x"y` in a character column (or a
  column name with a quote) came back as `x""y`, because the quote doubling of
  the writer was not undone; the checksums could not notice, since the file
  itself was intact. Existing directories are read correctly without being
  rewritten. Parquet storage was not affected.
* Numeric identifiers passed to `cs_new()` are no longer padded with decimals
  when one of them is fractional: `c(1, 2, 3.5)` gives `"1"`, `"2"`, `"3.5"`
  instead of `"1.0"`, `"2.0"`, `"3.5"`.
* Readers that apply a `marker_map` now record the marker name used in the
  export: `dictionary$marker_source` holds it for every renamed marker and
  `channels$channel_name` keeps it, while `marker` carries the mapped name, as
  the specification describes. Both used to hold only the mapped name.
  `cs_column_map()` accepts an optional `marker_source` column in
  `measurements` for the same purpose.
* The review app opens a directory written by `cs_write()`, as the README
  describes: `cs_app(path = <directory>)` reads it with `cs_read_cellspec()`
  and reports a failed integrity verification. Before, such a directory was
  rejected as a tiled export without tile tables.
* `cs_write_npy()` and `cs_write_npz()` report a destination whose directory
  does not exist, or that is itself a directory, as `cellspec_error_io`
  before writing; before, the base R error "cannot open the connection" and a
  warning surfaced.
* `cs_read_signal_policy()` reads CSV policies as text. Marker names that look
  like numbers or logical values (`"1"`, `"007"`, `"TRUE"`) no longer fail
  with "invalid column types", and `min_value` is restored exactly; values
  such as `1e-20` could come back one unit in the last place off.
* `cs_as_spe()` keeps `cells` column names that are not syntactic R names,
  such as the `Cell Type` column kept by the QuPath reader. They were turned
  into `Cell.Type`, and `cs_from_spe()` then failed with "undefined columns
  selected". `cs_from_spe()` also restores such names in objects converted by
  earlier versions and reports a missing column as `cellspec_error_format`.
* `cs_as_spe()` and `cs_as_anndata()` convert objects without cells.
* `cs_read()` with the default `format = "auto"` now selects the QuPath
  reader for a complete QuPath export. Its detection score, the sum of the
  weights 0.05, 0.25, 0.35 and 0.25, came out as 0.8999999999999999 in
  floating point and never reached the decisive 0.9, so automatic detection
  (also in the review app) failed with an ambiguity error that named a single
  candidate. The score is rounded and the threshold tolerates rounding.
* `plot(x, type = "marker")` and the marker panel of the overview drew wrong
  data: every value was repeated once per cell and attributed to the wrong
  compartment and statistic, and memory use grew with the square of the number
  of cells. The plot now shows one marker with one violin per compartment and
  statistic, subsamples to `max_points` cells and names the marker in its
  title. Without `marker` it shows the first marker; before, all markers were
  pooled, which is the bug-fix change of that default.
* A marker plot without finite values to draw fails with a
  `cellspec_error_invalid` error instead of a `ggplot2` error at print time, and
  the overview leaves that panel out.
* The centroid map uses a reversed `y` axis with the original coordinates in
  place of negated values, so axis labels match `cs_cells(x)$y`.
* The plot overview places legends below its panels, and the getting-started
  vignette now shows the quality-control plots. Plotting needs `ggplot2`
  3.3.0 or later.
* `x[0, ]` and `x[, 0]` now select no cells and no features, as in base R.
  Zero positions used to select everything, so an empty selection silently
  returned the complete object. Zeros mixed with other positions are ignored.
* When replacement and automatic restoration both fail, report the retained
  original backup directory explicitly so it can be recovered before retrying.
* Schema columns must be plain vectors of their declared type. Matrix, array,
  factor and other classed columns are rejected before downstream use. The
  canonical writer applies the same rule to extra metadata columns, preventing
  matrix columns from being silently truncated during TSV output.
* Detect native symbolic links, dangling links and Windows junctions without
  relying on the Windows `Sys.readlink()` stub; retain manifest and overwrite
  boundaries across platforms.
* Preserve existing NumPy files when input validation fails. Decode signed and
  unsigned integer boundaries exactly in both byte orders, including `int32`
  minimum and 64-bit integers in the supported range +/-2^53. Reject duplicate
  archive names and unsupported array dimensions.
* Recheck overwrite permission and destination contents immediately before
  committing canonical writes; refuse symbolic-link destinations and members.
  This protects late-arriving unrelated files, but is not a concurrent-writer lock.
* Include hidden files in integrity verification and refuse symlink members and
  unsafe portable manifest paths. Checksums establish consistency, not authorship.
* Treat external parser diagnostics as literal text so braces cannot be
  evaluated as formatting expressions and structured error classes survive.
* Reject partial delimited reads with parser warnings, preserve leading-zero
  and large integer identifiers, and reject lossy sidecar integer conversions.
  Use unambiguous composite cell keys even when identifiers contain separators.
* The review app retains upload filenames for RDS/gzip dispatch and image
  identity, and clears review results when inputs change or a read fails.
* AnnData documentation and examples use the native R in-memory backend;
  interoperability tests now require successful conversion when installed.
* Prepare the first CRAN submission: print snapshots no longer embed the
  package version, and the version is aligned across `DESCRIPTION`,
  `CITATION.cff`, `.zenodo.json` and the README.

# cellspecR 1.1.0

* Functions released in 1.0.0 are no longer marked experimental; like the
  package, they are stable. The NumPy readers and writers added in this
  version are experimental.

* The MCQuant, segmantR and inForm readers derive image and sample
  identifiers of an RDS table from its file name, as for delimited files;
  before, they came from a temporary copy and differed between reads.

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

* `cs_formats()` reports segmantR 0.2.0, the version the segmantR reader
  was tested with, instead of the non-existent segmantR 0.5.

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
