# Interoperability with SpatialExperiment and AnnData

The SpatialExperiment conversion keeps the selected signal as the main
assay, all raw measurements as an alternative experiment, and stores the
images, channels, provenance and policy in metadata.

``` r

if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
  spe <- cs_as_spe(x, policy)
  dim(spe)
  y <- cs_from_spe(spe)
  identical(cs_measurements(x), cs_measurements(y))
} else {
  message("Install SpatialExperiment to run this section.")
}
#> [1] TRUE
```

AnnData conversion is optional and requires an `anndataR` installation
with a working Python AnnData runtime.

``` r

if (requireNamespace("anndataR", quietly = TRUE)) {
  result <- tryCatch(cs_as_anndata(x, policy), error = function(e) e)
  if (inherits(result, "error")) message(conditionMessage(result)) else result
} else {
  message("Install anndataR to run this section.")
}
#> InMemoryAnnData object with n_obs × n_vars = 80 × 4
#>     obs: 'cell_id', 'image_id', 'sample_id', 'x', 'y', 'area', 'x_px', 'y_px'
#>     var: 'marker'
#>     uns: 'cellspec'
#>     obsm: 'spatial'
```
