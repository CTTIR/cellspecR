# List the available cellspec readers

**\[experimental\]**

Lists the adapters implemented by this build of cellspecR. The generic
table adapter accepts delimited files when the source columns are mapped
explicitly with
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md).

## Usage

``` r
cs_formats()
```

## Value

A data frame with `format`, `adapter_version`, `description`,
`tested_with` and `status` columns.

## See also

[`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md),
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md),
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

Other adapters:
[`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md),
[`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md),
[`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)

## Examples

``` r
cs_formats()
#>         format adapter_version
#> 1        table           1.0.0
#> 2       qupath           1.0.0
#> 3 qupath_tiled           1.0.0
#> 4      mcquant           1.0.0
#> 5     segmantr           1.0.0
#> 6       inform           1.0.0
#>                                            description
#> 1 Generic delimited table with an explicit column map.
#> 2            QuPath colon-delimited measurement export
#> 3          Tiled QuPath tables with centroid ownership
#> 4                   MCMICRO MCQuant measurement export
#> 5                               segmantR feature table
#> 6                        inForm cell segmentation data
#>                                    tested_with       status
#> 1 CSV, TSV and gzip-compressed delimited files       stable
#> 2                       QuPath 0.6.0 and 0.7.0 experimental
#> 3                                 QuPath 0.7.0 experimental
#> 4                              MCMICRO/MCQuant experimental
#> 5                                 segmantR 0.5 experimental
#> 6                              inForm/phenoptr experimental
```
