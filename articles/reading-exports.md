# Reading cell measurement exports

Readers are selected explicitly when a project contains more than one
possible grammar. The bundled synthetic export uses QuPath-style
headers.

``` r

path <- system.file("extdata", "qupath-0.7.0-instanseg.tsv", package = "cellspecR")
cs_detect_format(path)
#>   format score
#> 1 qupath   0.9
#> 2  table   0.5
#>                                                                 evidence
#> 1    cell identifier, micrometre centroids, colon-delimited measurements
#> 2 Readable delimited table with 10 columns; explicit column_map required
x <- cs_read(path, format = "qupath")
print(x)
#> <cellspec> spec 1.0.0
#>   cells     80 in 1 image (1 sample)
#>   features  5: 5 intensity
#>   markers   2: DAPI, CD3e
#>   pixel     1 um/px
#>   adjacency none
#>   source    qupath 1.0.0
cs_validate(x)
#> <cellspec validation> 45 checks: 0 fail, 0 warn, 0 skip, 45 pass
#> pass 45 other checks
```

For an unrecognised table, map the source columns and describe
measurements in the dictionary at the boundary.

``` r

map <- cs_column_map(
  cell_id = "Cell ID", x = "Centroid X um", y = "Centroid Y um",
  measurements = data.frame(
    source_name = "CD3e: Mean", kind = "intensity", marker = "CD3e",
    compartment = "cell", statistic = "mean", unit = "a.u."
  )
)
map
#> $cell_id
#> [1] "Cell ID"
#> 
#> $x
#> [1] "Centroid X um"
#> 
#> $y
#> [1] "Centroid Y um"
#> 
#> $image_id
#> NULL
#> 
#> $sample_id
#> NULL
#> 
#> $area
#> NULL
#> 
#> $coordinate_unit
#> [1] "um"
#> 
#> $measurements
#>   source_name      kind marker compartment statistic unit
#> 1  CD3e: Mean intensity   CD3e        cell      mean a.u.
#> 
#> attr(,"class")
#> [1] "cs_column_map" "list"
```

Pixel coordinates always need a calibration. A missing or inconsistent
unit is an error rather than a guess.
