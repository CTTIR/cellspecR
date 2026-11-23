# Detect the format of a cell table

Reads only the header and at most `n_max` data rows and scores the input
against the reader grammars listed by
[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md).
A generic table is deliberately returned as a low-confidence candidate
because its biological meaning cannot be inferred safely without an
explicit column map. `cs_read(format = "auto")` selects a format only
when exactly one candidate scores at least 0.9 and no other candidate
comes within 0.1 of it.

## Usage

``` r
cs_detect_format(path, n_max = 50L)
```

## Arguments

- path:

  A delimited table file, an RDS file holding a data frame, or a
  directory of tiled tables.

- n_max:

  Maximum number of data rows to inspect after the header.

## Value

A data frame with one row per candidate format (specialised readers
first, the generic table last) and the columns `format` (character),
`score` (double between 0 and 1) and `evidence` (character, what
matched).

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
