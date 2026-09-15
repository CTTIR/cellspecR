# Access the components of a cellspec object

**\[experimental\]**

Accessors return the components of a `cellspec` object. Use them instead
of `x$cells` so code keeps working if the internal layout changes.

## Usage

``` r
cs_cells(x)

cs_measurements(x)

cs_dictionary(x)

cs_images(x)

cs_channels(x)

cs_provenance(x)

cs_adjacency(x)
```

## Arguments

- x:

  A `cellspec` object.

## Value

- `cs_cells()`: data frame, one row per cell.

- `cs_measurements()`: double matrix, cells x features, column names are
  feature identifiers.

- `cs_dictionary()`: data frame, one row per measurement column.

- `cs_images()`: data frame, one row per image.

- `cs_channels()`: data frame, one row per image and channel.

- `cs_provenance()`: list with `producer`, `reader`, `created_utc`,
  `inputs`, `counts`, `parameters` and `history`.

- `cs_adjacency()`: data frame of cell-cell contacts, or `NULL`.

## See also

[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md)

Other object:
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

## Examples

``` r
x <- cs_example()
head(cs_cells(x))
#>   cell_id image_id sample_id        x         y    area     x_px     y_px
#> 1       1     img1        s1 355.8867 441.65396 36.5329 711.7733 883.3079
#> 2       2     img1        s1 331.0488 479.92247 54.2466 662.0976 959.8449
#> 3       3     img1        s1 113.7938 270.56093 78.4704 227.5877 541.1219
#> 4       4     img1        s1 108.9166 120.10323 52.8604 217.8332 240.2065
#> 5       5     img1        s1 399.6320 455.57838 67.7371 799.2640 911.1568
#> 6       6     img1        s1 235.4871  88.79277 61.8434 470.9741 177.5855
dim(cs_measurements(x))
#> [1] 80 19
cs_dictionary(x)[1:3, ]
#>         feature_id      kind marker compartment statistic unit
#> 1   cell:DAPI:mean intensity   DAPI        cell      mean a.u.
#> 2 cell:DAPI:median intensity   DAPI        cell    median a.u.
#> 3   cell:CD3e:mean intensity   CD3e        cell      mean a.u.
#>          source_name marker_source
#> 1   Cell: DAPI: Mean          <NA>
#> 2 Cell: DAPI: Median          <NA>
#> 3   Cell: CD3e: Mean          <NA>
cs_images(x)
#>   image_id sample_id pixel_size width_px height_px  platform
#> 1     img1        s1        0.5     1024      1024 simulated
#> 2     img2        s2        0.5     1024      1024 simulated
cs_channels(x)
#>   image_id channel_index    channel_name          marker
#> 1     img1             1            DAPI            DAPI
#> 2     img1             2            CD3e            CD3e
#> 3     img1             3 Pan-Cytokeratin Pan-Cytokeratin
#> 4     img1             4           FOXP3           FOXP3
#> 5     img2             1            DAPI            DAPI
#> 6     img2             2            CD3e            CD3e
#> 7     img2             3 Pan-Cytokeratin Pan-Cytokeratin
#> 8     img2             4           FOXP3           FOXP3
names(cs_provenance(x))
#> [1] "producer"    "reader"      "parameters"  "created_utc" "inputs"     
#> [6] "counts"      "history"    
cs_adjacency(x)
#> NULL
```
