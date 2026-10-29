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

## Compressed input

Tables written with `cs_write(format = "tsv.gz")` are decompressed in R
and checked against their gzip trailer, also when `verify = FALSE`. A
truncated or corrupt file, also one zero-filled back to its original
size, raises an error of class `cellspec_error_format`. A BGZF file
(written by `bgzip`) is checked block by block and must end with its
end-of-file block. Other files made of several gzip members can be
checked only in their last member; they are read with a warning of class
`cellspec_warning_integrity`.

## See also

cs_write(), cs_verify()

Other canonical-format:
[`cs_verify()`](https://cttir.github.io/cellspecR/dev/reference/cs_verify.md),
[`cs_write()`](https://cttir.github.io/cellspecR/dev/reference/cs_write.md)

## Examples

``` r
path <- tempfile("cellspec-")
cs_write(cs_example(), path)
y <- cs_read_cellspec(path)
identical(cs_cells(y), cs_cells(cs_example()))
#> [1] TRUE
```
