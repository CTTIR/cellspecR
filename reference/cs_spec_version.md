# Version of the cellspec specification

**\[experimental\]**

Returns the version of the `cellspec` format that this build of
cellspecR writes and validates. Readers of major version 1 accept every
1.y file whose minor version is not newer than their own.

## Usage

``` r
cs_spec_version()
```

## Value

A single string in semantic versioning form, for example `"1.0.0"`.

## See also

[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md)

Other specification:
[`cs_vocabulary()`](https://cttir.github.io/cellspecR/reference/cs_vocabulary.md)

## Examples

``` r
cs_spec_version()
#> [1] "1.0.0"
```
