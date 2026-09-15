# Merge tiled cellspec objects using centroid ownership

Every centroid is assigned to the half open outer box containing it. A
centroid found in more than one box is an error. Cells in a tile whose
centroid is owned by another tile, or by no tile, are treated as halo
cells and dropped.

## Usage

``` r
cs_merge_tiles(tiles, tile_bounds, ownership = "centroid", tolerance = 1e-09)
```

## Arguments

- tiles:

  A named or positional list of `cellspec` tile objects. Names, when
  supplied, must equal `tile_bounds$tile_id`.

- tile_bounds:

  A data frame with `tile_id`, `xmin`, `xmax`, `ymin` and `ymax` in
  micrometres.

- ownership:

  Ownership method. The only supported value is `"centroid"`.

- tolerance:

  Non-negative tolerance used to snap coordinates close to a box
  boundary before applying its half open comparisons.

## Value

A merged `cellspec` object.

## See also

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

## Examples

``` r
tile_bounds <- data.frame(
  tile_id = "tile-1", xmin = 0, xmax = 10000, ymin = 0, ymax = 10000
)
cs_merge_tiles(list(cs_example()), tile_bounds)
#> <cellspec> spec 1.0.0
#>   cells     80 in 2 images (2 samples)
#>   features  19: 16 intensity, 2 shape, 1 other
#>   markers   4: DAPI, CD3e, Pan-Cytokeratin, FOXP3
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    cs_merge_tiles 1.0.0 (cellspecR simulator 0.0.0.9000)
```
