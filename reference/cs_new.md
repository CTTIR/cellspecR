# Create a cellspec object

**\[experimental\]**

Builds a `cellspec` object from its components and checks it against the
structure rules of the specification. Tool exports are normally read
with
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md);
use `cs_new()` when you already hold the pieces in memory, for example
in another package that produces cell tables.

Inputs are normalised before validation: any data frame subclass becomes
a plain `data.frame` without row names, factors become character
vectors, identifier columns (`cell_id`, `image_id`, `sample_id`,
`subject_id`) are converted to character, whole-number doubles in
integer columns become integers, and `NaN`/`Inf` in `measurements`
become `NA` (counted in `provenance$counts$nonfinite_converted`). A
missing `sample_id` column in `cells` is filled from `images`.

## Usage

``` r
cs_new(
  cells,
  measurements = NULL,
  dictionary = NULL,
  images,
  channels = NULL,
  provenance = NULL,
  adjacency = NULL
)
```

## Arguments

- cells:

  A data frame with one row per cell and at least the columns `cell_id`,
  `image_id`, `sample_id` (or a `sample_id` in `images`), `x` and `y`
  (centroids in micrometres).

- measurements:

  A numeric matrix (or data frame of numeric columns) with one row per
  cell, in the row order of `cells`, and column names equal to
  `dictionary$feature_id`. `NULL` means no features.

- dictionary:

  A data frame describing each measurement column (see
  [`cs_vocabulary()`](https://cttir.github.io/cellspecR/reference/cs_vocabulary.md)).
  `NULL` is allowed only when there are no features.

- images:

  A data frame with one row per image and at least `image_id`,
  `sample_id` and `pixel_size`.

- channels:

  A data frame with one row per image and channel (`image_id`,
  `channel_index`, `channel_name`, `marker`), or `NULL` when no
  intensity features exist.

- provenance:

  A list describing the origin of the data. Missing fields are filled
  with defaults; `NULL` records the object as built by `cs_new()`.

- adjacency:

  Optional data frame of cell-cell contacts (`image_id`, `cell_id_a`,
  `cell_id_b`, `shared_boundary`, `method`).

## Value

A `cellspec` object: a list of class `"cellspec"` with elements
`spec_version` (string), `cells` (data frame), `measurements` (double
matrix), `dictionary`, `images`, `channels` (data frames), `provenance`
(list) and `adjacency` (data frame or `NULL`).

## See also

[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md)
for every column and rule;
[`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)
for the checks applied.

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

## Examples

``` r
cells <- data.frame(
  cell_id = c("1", "2", "3"),
  image_id = "img1",
  sample_id = "s1",
  x = c(10, 20, 30),
  y = c(5, 15, 25),
  area = c(50, 62.5, 48)
)
measurements <- cbind(
  "cell:CD3e:mean" = c(120, 8, 95),
  "nucleus:FOXP3:mean" = c(3, 1, 40)
)
dictionary <- data.frame(
  feature_id = colnames(measurements),
  kind = "intensity",
  marker = c("CD3e", "FOXP3"),
  compartment = c("cell", "nucleus"),
  statistic = "mean",
  unit = "a.u.",
  source_name = c("Cell: CD3e: Mean", "Nucleus: FOXP3: Mean")
)
images <- data.frame(image_id = "img1", sample_id = "s1", pixel_size = 0.5)
channels <- data.frame(
  image_id = "img1",
  channel_index = 1:3,
  channel_name = c("DAPI", "CD3e", "FOXP3"),
  marker = c("DAPI", "CD3e", "FOXP3")
)
x <- cs_new(cells, measurements, dictionary, images, channels)
x
#> <cellspec> spec 1.0.0
#>   cells     3 in 1 image (1 sample)
#>   features  2: 2 intensity
#>   markers   2: CD3e, FOXP3
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    cs_new
```
