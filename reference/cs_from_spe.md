# Convert a SpatialExperiment back to cellspec

**\[experimental\]**

Reconstructs the cellspec components stored by
[`cs_as_spe()`](https://cttir.github.io/cellspecR/reference/cs_as_spe.md).

## Usage

``` r
cs_from_spe(spe)
```

## Arguments

- spe:

  A `SpatialExperiment` created by
  [`cs_as_spe()`](https://cttir.github.io/cellspecR/reference/cs_as_spe.md).

## Value

A validated `cellspec` object.

## See also

Other interoperability:
[`cs_as_anndata()`](https://cttir.github.io/cellspecR/reference/cs_as_anndata.md),
[`cs_as_spe()`](https://cttir.github.io/cellspecR/reference/cs_as_spe.md)

## Examples

``` r
if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
  x <- cs_example()
  policy <- cs_signal_policy(cs_markers(x))
  identical(cs_cells(x), cs_cells(cs_from_spe(cs_as_spe(x, policy))))
}
#> [1] TRUE
```
