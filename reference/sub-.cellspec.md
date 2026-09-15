# Subset a cellspec object by cells and features

**\[experimental\]**

`x[i, j]` keeps the cells selected by `i` and the features selected by
`j`. All components stay aligned: `cells` and `measurements` rows are
subset together, dictionary rows follow the kept features, and adjacency
contacts whose cells were removed are dropped. `images` and `channels`
are kept unchanged.

## Usage

``` r
# S3 method for class 'cellspec'
x[i, j, ..., drop = FALSE]
```

## Arguments

- x:

  A `cellspec` object.

- i:

  Cells to keep: a logical vector with one value per cell, or positive
  or negative integer positions. Missing means all cells.

- j:

  Features to keep: a character vector of feature identifiers, a logical
  vector with one value per feature, or integer positions. Missing means
  all features.

- ...:

  Not used; must be empty.

- drop:

  Not used; subsetting always returns a `cellspec` object.

## Value

A `cellspec` object.

## See also

Other methods:
[`as.data.frame.cellspec()`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md),
[`cellspec-methods`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md),
[`plot.cellspec()`](https://cttir.github.io/cellspecR/reference/plot.cellspec.md)

## Examples

``` r
x <- cs_example()
dim(x)
#> [1] 80 19
big <- x[cs_cells(x)$area > 60, ]
dim(big)
#> [1] 47 19
means <- x[, cs_features(x, statistic = "mean")]
dim(means)
#> [1] 80  8
```
