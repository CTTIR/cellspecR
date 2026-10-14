# Convert a cellspec object to SpatialExperiment

**\[experimental\]**

Converts selected signals to the main assay, stores every raw
measurement in an `altExp`, and records the cellspec metadata needed for
a lossless round trip.

## Usage

``` r
cs_as_spe(x, policy = NULL, assay_name = "intensity")
```

## Arguments

- x:

  A `cellspec` object.

- policy:

  A signal policy. It is required when a marker has more than one
  compartment or statistic; otherwise it can be omitted.

- assay_name:

  Name of the main signal assay.

## Value

A `SpatialExperiment` with cells as columns, markers as rows,
`spatialCoords` containing `x` and `y`, and a `measurements` altExp.

## See also

Other interoperability:
[`cs_as_anndata()`](https://cttir.github.io/cellspecR/reference/cs_as_anndata.md),
[`cs_from_spe()`](https://cttir.github.io/cellspecR/reference/cs_from_spe.md)

## Examples

``` r
if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
  x <- cs_example()
  policy <- cs_signal_policy(cs_markers(x))
  spe <- cs_as_spe(x, policy)
  spe
}
#> class: SpatialExperiment 
#> dim: 4 80 
#> metadata(1): cellspec
#> assays(1): intensity
#> rownames(4): DAPI CD3e Pan-Cytokeratin FOXP3
#> rowData names(0):
#> colnames(80): img1::1 img1::2 ... img2::39 img2::40
#> colData names(6): cell_id image_id ... x_px y_px
#> reducedDimNames(0):
#> mainExpName: NULL
#> altExpNames(1): measurements
#> spatialCoords names(2) : x y
#> imgData names(0):
```
