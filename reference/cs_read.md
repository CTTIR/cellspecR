# Read a delimited table into a cellspec object

Reads a delimited cell table using a format-specific adapter or an
explicit
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md).
See
[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md)
for supported formats.

The `segmantr` adapter expects the one-based row and column centroid
means returned by `segmantR::sg_extract_features()`. It subtracts 0.5
before converting to micrometres and scales pixel `area` by
`pixel_size^2`. Coordinates refer to the supplied image: cropped or
downsampled inputs require an explicit external frame transform before
combining with a full-resolution image. This adapter assumes square
pixels. Shape measurements retain source units in the feature
dictionary.

## Usage

``` r
cs_read(
  path,
  format = "auto",
  pixel_size = NULL,
  image_id = NULL,
  sample_id = NULL,
  marker_map = NULL,
  column_map = NULL,
  tile_bounds = NULL,
  verify_done = TRUE,
  keep_other = TRUE,
  keep_paths = FALSE,
  quiet = FALSE
)
```

## Arguments

- path:

  One delimited table file.

- format:

  Reader format. Use `"table"` for this adapter or `"auto"` to request
  conservative detection.

- pixel_size:

  Micrometres per pixel. Required for pixel coordinates;
  micrometre-coordinate tables use `1` when no calibration is supplied.

- image_id:

  Optional scalar image identifier overriding the mapped column;
  otherwise the mapped column or file basename is used.

- sample_id:

  Optional scalar sample identifier overriding the mapped column;
  otherwise the mapped column or image identifier is used.

- marker_map:

  Reserved for future adapters; not used by the table adapter.

- column_map:

  A validated object returned by
  [`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md).

- tile_bounds:

  Optional tile-bound data frame for `format = "qupath_tiled"`, with
  `tile_id`, `xmin`, `xmax`, `ymin` and `ymax` in micrometres.

- verify_done:

  Whether tiled readers should verify optional `.done.tsv` metadata
  against each source file.

- keep_other:

  Whether unmapped numeric columns become `other` measurements and other
  unmapped columns are retained in `cells`. Every `other` feature,
  whether kept here or mapped with `kind = "other"` in `column_map`
  (also when `keep_other = FALSE`), is identified as `other:` followed
  by its source name in lower case, with each run of characters other
  than `a-z` and `0-9` replaced by `_` and leading or trailing `_`
  removed (`value` if nothing is left). Identifiers that clash are made
  unique by [`make.unique()`](https://rdrr.io/r/base/make.unique.html)
  with `sep = "_"`, mapped measurements first in the order given, then
  unmapped columns in table order; a suffix that is already taken is
  skipped, so columns `a b`, `a_b` and `a_b_1` become `other:a_b`,
  `other:a_b_2` and `other:a_b_1`.

- keep_paths:

  Whether the full input path may be recorded in provenance.

- quiet:

  Reserved for consistency with future readers; suppresses the
  informational warning about dropped columns when `keep_other = FALSE`.

## Value

A validated `cellspec` object.

## Compressed input

Input files whose names end in `.gz` are decompressed in R and checked
against their gzip trailer before they are parsed, for every format. A
truncated or corrupt file, also one zero-filled back to its original
size, raises an error of class `cellspec_error_format`. A BGZF file
(written by `bgzip`) is checked block by block and must end with its
end-of-file block. Other files made of several gzip members, such as
concatenated `.gz` files, can be checked only in their last member; they
are read with a warning of class `cellspec_warning_integrity`.

## See also

[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md),
[`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md),
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md)

Other adapters:
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md),
[`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md),
[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md)

## Examples

``` r
path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(id = c("c1", "c2"), x = 1:2, y = 3:4),
                 path, row.names = FALSE)
map <- cs_column_map("id", "x", "y")
x <- cs_read(path, format = "table", column_map = map)
dim(x)
#> [1] 2 0
```
