# Verify a canonical cellspec directory

Recomputes every digest in MANIFEST.sha256 and checks the DONE marker
against the manifest digest. The returned report has one row per
declared file plus DONE; it does not hide a failed digest behind an
error. Hidden files are included. Symbolic-link members are refused, so
a verified directory does not depend on files outside it. Checksums
detect changes; they do not authenticate the producer of a directory.

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
[`cs_read_cellspec()`](https://cttir.github.io/cellspecR/dev/reference/cs_read_cellspec.md),
[`cs_write()`](https://cttir.github.io/cellspecR/dev/reference/cs_write.md)

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
#> cellspec.json 789a70c4bc699d8eb2196e50458a9965082d8437a775d7e5e3d384c7d95cd376
#> 1             8b9e0f45af4252aad714ceb2eaf05ed773de68d616703237b0d1489880577dba
#>                                                                       observed
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json 789a70c4bc699d8eb2196e50458a9965082d8437a775d7e5e3d384c7d95cd376
#> 1             8b9e0f45af4252aad714ceb2eaf05ed773de68d616703237b0d1489880577dba
#>                 ok
#> cells.parquet TRUE
#> cellspec.json TRUE
#> 1             TRUE
```
