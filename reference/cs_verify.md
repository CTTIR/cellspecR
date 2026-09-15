# Verify a canonical cellspec directory

**\[experimental\]**

Recomputes every digest in MANIFEST.sha256 and checks the DONE marker
against the manifest digest. The returned report has one row per
declared file plus DONE; it does not hide a failed digest behind an
error.

## Usage

``` r
cs_verify(dir)
```

## Arguments

- dir:

  A cellspec directory written by cs_write().

## Value

A data frame with character columns file, expected and observed, and
logical column ok. ok is FALSE for a missing, modified or unexpected
file, or for an invalid DONE marker.

## See also

cs_read_cellspec()

Other canonical-format:
[`cs_read_cellspec()`](https://cttir.github.io/cellspecR/reference/cs_read_cellspec.md),
[`cs_write()`](https://cttir.github.io/cellspecR/reference/cs_write.md)

## Examples

``` r
path <- tempfile("cellspec-")
cs_write(cs_example(), path)
cs_verify(path)
#>                        file
#> cells.parquet cells.parquet
#> cellspec.json cellspec.json
#> 1                      DONE
#>                                                                       expected
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json e23259ccf6c744a826d59f00258bffdee0e98903ef9308b4abfc2d9dc996a6f4
#> 1             489212cfabd36e232f1afd801d229a0a7557d54aa09083fbcec08611ff246cbc
#>                                                                       observed
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json e23259ccf6c744a826d59f00258bffdee0e98903ef9308b4abfc2d9dc996a6f4
#> 1             489212cfabd36e232f1afd801d229a0a7557d54aa09083fbcec08611ff246cbc
#>                 ok
#> cells.parquet TRUE
#> cellspec.json TRUE
#> 1             TRUE
```
