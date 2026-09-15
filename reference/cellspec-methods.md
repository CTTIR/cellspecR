# Print, summarise and measure a cellspec object

**\[experimental\]**

[`print()`](https://rdrr.io/r/base/print.html) shows a compact overview
that fits in 80 columns: cells, images, samples, features by kind,
markers, pixel size, specification version and the adapter that produced
the object. [`summary()`](https://rdrr.io/r/base/summary.html) returns
one row per image. [`dim()`](https://rdrr.io/r/base/dim.html) returns
the number of cells and features.

## Usage

``` r
# S3 method for class 'cellspec'
print(x, ...)

# S3 method for class 'cellspec'
summary(object, ...)

# S3 method for class 'cellspec_summary'
print(x, ...)

# S3 method for class 'cellspec'
dim(x)
```

## Arguments

- x, object:

  A `cellspec` object (or, for the summary print method, a
  `cellspec_summary`).

- ...:

  Unused; for compatibility with the generics.

## Value

- [`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.

- [`summary()`](https://rdrr.io/r/base/summary.html) returns a data
  frame of class `cellspec_summary` with one row per image and the
  columns `image_id`, `sample_id` (character), `n_cells`, `n_markers`,
  `n_features` (integer; markers and features with at least one
  non-missing value in that image), `pixel_size`, `x_min`, `x_max`,
  `y_min`, `y_max` (double, micrometres) and `na_fraction` (double,
  fraction of missing measurement values in that image).

- [`dim()`](https://rdrr.io/r/base/dim.html) returns an integer vector
  `c(cells, features)`.

## See also

Other methods:
[`[.cellspec()`](https://cttir.github.io/cellspecR/reference/sub-.cellspec.md),
[`as.data.frame.cellspec()`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md),
[`plot.cellspec()`](https://cttir.github.io/cellspecR/reference/plot.cellspec.md)

## Examples

``` r
x <- cs_example()
x
#> <cellspec> spec 1.0.0
#>   cells     80 in 2 images (2 samples)
#>   features  19: 16 intensity, 2 shape, 1 other
#>   markers   4: DAPI, CD3e, Pan-Cytokeratin, FOXP3
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    simulate 1.0.0 (cellspecR simulator 1.0.0)
summary(x)
#> <cellspec summary> 2 images, 80 cells
#>  image_id sample_id n_cells n_markers n_features pixel_size  x_min  x_max
#>      img1        s1      40         4         19        0.5 22.498 504.86
#>      img2        s2      40         4         19        0.5 17.146 494.75
#>   y_min  y_max na_fraction
#>  20.589 508.74           0
#>   1.152 500.00           0
dim(x)
#> [1] 80 19
```
