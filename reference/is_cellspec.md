# Test for a cellspec object

**\[experimental\]**

## Usage

``` r
is_cellspec(x)
```

## Arguments

- x:

  Any R object.

## Value

`TRUE` if `x` inherits from `"cellspec"`, otherwise `FALSE`. The object
is not validated; use
[`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)
for that.

## See also

Other object:
[`cs_accessors`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
[`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md),
[`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md),
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
[`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md),
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md)

## Examples

``` r
is_cellspec(cs_example())
#> [1] TRUE
is_cellspec(data.frame())
#> [1] FALSE
```
