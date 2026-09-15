# Detect the generic table format

**\[experimental\]**

Reads only the header and at most `n_max` data rows. A generic table is
deliberately returned as a low-confidence candidate because its
biological meaning cannot be inferred safely without an explicit column
map.

## Usage

``` r
cs_detect_format(path, n_max = 50L)
```

## Arguments

- path:

  A delimited table file.

- n_max:

  Maximum number of data rows to inspect after the header.

## Value

A data frame with `format`, `score` and `evidence` columns.

## See also

[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md),
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

Other adapters:
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md),
[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md),
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

## Examples

``` r
path <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(id = 1, x = 2, y = 3), path, row.names = FALSE)
cs_detect_format(path)
#>   format score
#> 1  table   0.5
#>                                                                evidence
#> 1 Readable delimited table with 3 columns; explicit column_map required
```
