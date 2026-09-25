# Adapter reference

[`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md)
is the machine-readable index of supported reader grammars. Each adapter
preserves the source column name in `dictionary$source_name` and records
its adapter and version in provenance.

``` r

cs_formats()
#>         format adapter_version
#> 1        table           1.0.0
#> 2       qupath           1.0.1
#> 3 qupath_tiled           1.0.1
#> 4      mcquant           1.0.0
#> 5     segmantr           1.0.1
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

The QuPath adapter accepts both channel-first headers such as
`DAPI: Mean` and compartment-first headers such as
`Nucleus: CD3e: Mean`. The tiled adapter adds an ownership pass over
outer tile boxes; halo rows are counted and dropped. MCQuant and
segmantR readers treat `centroid_col` as x and `centroid_row` as y, and
require pixel calibration.

When no grammar is decisive, `cs_read(format = "auto")` returns a
classified ambiguity error and lists the candidates. This prevents a
plausible but wrong column match from reaching downstream analysis.
