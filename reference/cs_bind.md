# Combine cellspec objects from different images

`cs_bind()` combines cell tables, measurements and metadata from one or
more `cellspec` objects. Objects must describe different images and must
use the same measurement dictionary.

## Usage

``` r
cs_bind(...)
```

## Arguments

- ...:

  `cellspec` objects to combine.

## Value

A combined `cellspec` object.

## See also

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

## Examples

``` r
cs_bind(cs_example())
#> <cellspec> spec 1.0.0
#>   cells     80 in 2 images (2 samples)
#>   features  19: 16 intensity, 2 shape, 1 other
#>   markers   4: DAPI, CD3e, Pan-Cytokeratin, FOXP3
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    cs_bind 1.0.0 (cellspecR simulator 0.0.0.9000)
```
