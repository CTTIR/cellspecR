# Select features and markers by their dictionary entries

**\[experimental\]**

`cs_features()` returns the identifiers of measurement columns whose
dictionary entries match every supplied filter. Select features through
this function rather than by splitting `feature_id` strings; the
identifier layout is not part of the contract downstream code may parse.

`cs_markers()` returns the markers that have at least one intensity
feature.

## Usage

``` r
cs_features(
  x,
  kind = NULL,
  marker = NULL,
  compartment = NULL,
  statistic = NULL
)

cs_markers(x)
```

## Arguments

- x:

  A `cellspec` object.

- kind, marker, compartment, statistic:

  Character vectors of allowed values, or `NULL` for no filter on that
  column.

## Value

`cs_features()`: character vector of `feature_id` values in dictionary
order (length 0 when nothing matches). `cs_markers()`: character vector
of marker names in order of first appearance.

## See also

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
[`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)

## Examples

``` r
x <- cs_example()
cs_features(x, kind = "intensity", statistic = "mean")
#> [1] "cell:DAPI:mean"               "cell:CD3e:mean"              
#> [3] "cell:Pan-Cytokeratin:mean"    "cell:FOXP3:mean"             
#> [5] "nucleus:DAPI:mean"            "nucleus:CD3e:mean"           
#> [7] "nucleus:Pan-Cytokeratin:mean" "nucleus:FOXP3:mean"          
cs_features(x, marker = "FOXP3")
#> [1] "cell:FOXP3:mean"      "cell:FOXP3:median"    "nucleus:FOXP3:mean"  
#> [4] "nucleus:FOXP3:median"
cs_markers(x)
#> [1] "DAPI"            "CD3e"            "Pan-Cytokeratin" "FOXP3"          
```
