# Validate a table column map

**\[experimental\]**

Creates a validated description of how a generic delimited table maps to
the cellspec columns. Source names are checked for shape here and
checked against the input table by
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md).

## Usage

``` r
cs_column_map(
  cell_id,
  x,
  y,
  image_id = NULL,
  sample_id = NULL,
  area = NULL,
  coordinate_unit = c("um", "px"),
  measurements = NULL
)
```

## Arguments

- cell_id:

  Source column containing the cell identifier.

- x:

  Source column containing the x coordinate.

- y:

  Source column containing the y coordinate.

- image_id:

  Optional source column containing image identifiers.

- sample_id:

  Optional source column containing sample identifiers.

- area:

  Optional source column containing positive cell areas.

- coordinate_unit:

  Coordinate unit for `x` and `y`: micrometres or pixels.

- measurements:

  Optional data frame with `source_name`, `kind`, `marker`,
  `compartment`, `statistic` and `unit` metadata columns.

## Value

An object of class `cs_column_map`, a named list with the mapped source
names, coordinate unit and validated measurement metadata.

## See also

[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

Other adapters:
[`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md),
[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md),
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

## Examples

``` r
cs_column_map(
  "Cell ID", "Centroid X", "Centroid Y",
  measurements = data.frame(
    source_name = "CD3e Mean", kind = "intensity", marker = "CD3e",
    compartment = "cell", statistic = "mean", unit = "a.u."
  )
)
#> $cell_id
#> [1] "Cell ID"
#> 
#> $x
#> [1] "Centroid X"
#> 
#> $y
#> [1] "Centroid Y"
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
#> 1   CD3e Mean intensity   CD3e        cell      mean a.u.
#> 
#> attr(,"class")
#> [1] "cs_column_map" "list"         
```
