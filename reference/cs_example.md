# A small synthetic cellspec object

**\[experimental\]**

Builds a small, deterministic `cellspec` object for examples and
experiments: two images from two samples, 40 cells each, four markers
(`DAPI`, `CD3e`, `Pan-Cytokeratin`, `FOXP3`) measured as mean and median
in the cell and nucleus compartments, cell and nucleus areas, and one
tool-specific column. The values are simulated, not measured. The random
number generator state of the session is left untouched.

## Usage

``` r
cs_example()
```

## Value

A valid `cellspec` object with 80 cells and 19 features.

## See also

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

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
#>   source    simulate 1.0.0 (cellspecR simulator 0.0.0.9000)
cs_validate(x)
#> <cellspec validation> 45 checks: 0 fail, 0 warn, 0 skip, 45 pass
#> pass 45 other checks
```
