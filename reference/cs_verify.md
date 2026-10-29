# Verify a canonical cellspec directory

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
#> cellspec.json 2621502627126eef19d95160f430f69084db903db7bed152bb9283c9fc0cd685
#> 1             aea709f5612c5c2a31e1da03012003ef8e5880c556edea4fffe8a35a91905461
#>                                                                       observed
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json 2621502627126eef19d95160f430f69084db903db7bed152bb9283c9fc0cd685
#> 1             aea709f5612c5c2a31e1da03012003ef8e5880c556edea4fffe8a35a91905461
#>                 ok
#> cells.parquet TRUE
#> cellspec.json TRUE
#> 1             TRUE
```
