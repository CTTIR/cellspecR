# Create a marker-name mapping

**\[experimental\]**

Builds a two-column mapping from source marker names to canonical marker
names. Source names must be unique; several source names may map to the
same canonical name when they represent the same marker across files.

## Usage

``` r
cs_marker_map(from, to)
```

## Arguments

- from:

  Character vector of source marker names.

- to:

  Character vector of canonical marker names, the same length as `from`.

## Value

A two-column data frame with character columns `from` and `to`.

## See also

[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md)

Other signals:
[`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md),
[`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md),
[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md),
[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)

## Examples

``` r
cs_marker_map(c("PanCK", "CD68"), c("Pan-Cytokeratin", "CD68"))
#>    from              to
#> 1 PanCK Pan-Cytokeratin
#> 2  CD68            CD68
```
