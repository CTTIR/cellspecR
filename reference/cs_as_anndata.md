# Convert a cellspec object to AnnData

**\[experimental\]**

Creates an AnnData object with cells in `obs`, selected marker signals
in `X`, and `x`/`y` in `obsm$spatial`. The optional `anndataR` package
and its Python runtime are required.

## Usage

``` r
cs_as_anndata(x, policy)
```

## Arguments

- x:

  A `cellspec` object.

- policy:

  Signal policy used to form `X`.

## Value

An AnnData object supplied by `anndataR`.

## See also

Other interoperability:
[`cs_as_spe()`](https://cttir.github.io/cellspecR/reference/cs_as_spe.md),
[`cs_from_spe()`](https://cttir.github.io/cellspecR/reference/cs_from_spe.md)

## Examples

``` r
if (requireNamespace("anndataR", quietly = TRUE)) {
  x <- cs_example()
  cs_as_anndata(x, cs_signal_policy(cs_markers(x)))
}
#> InMemoryAnnData object with n_obs × n_vars = 80 × 4
#>     obs: 'cell_id', 'image_id', 'sample_id', 'x', 'y', 'area', 'x_px', 'y_px'
#>     var: 'marker'
#>     uns: 'cellspec'
#>     obsm: 'spatial'
```
