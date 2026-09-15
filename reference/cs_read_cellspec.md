# Read a canonical cellspec directory

**\[experimental\]**

Reads the sidecar and cell table written by cs_write(), verifies the
manifest and DONE marker by default, and returns a validated object.
DONE is required even when verification is explicitly disabled.

## Usage

``` r
cs_read_cellspec(dir, verify = TRUE)
```

## Arguments

- dir:

  A canonical cellspec directory.

- verify:

  Whether to verify all manifest digests before reading data.

## Value

A validated cellspec object.

## See also

cs_write(), cs_verify()

Other canonical-format:
[`cs_verify()`](https://cttir.github.io/cellspecR/reference/cs_verify.md),
[`cs_write()`](https://cttir.github.io/cellspecR/reference/cs_write.md)

## Examples

``` r
path <- tempfile("cellspec-")
cs_write(cs_example(), path)
y <- cs_read_cellspec(path)
identical(cs_cells(y), cs_cells(cs_example()))
#> [1] TRUE
```
