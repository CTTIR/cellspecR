# Read a signal policy from JSON or CSV

**\[experimental\]**

Reads and validates a policy written by
[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md).
The format is inferred from the `.json` or `.csv` extension unless
`format` is supplied explicitly.

## Usage

``` r
cs_read_signal_policy(path, format = NULL)
```

## Arguments

- path:

  Source file path.

- format:

  Either `"json"` or `"csv"`; by default inferred from `path`.

## Value

A validated data frame with class `cs_signal_policy`.

## See also

[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)

Other signals:
[`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md),
[`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md),
[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md),
[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)

## Examples

``` r
path <- tempfile(fileext = ".json")
cs_write_signal_policy(cs_signal_policy("CD3e"), path)
cs_read_signal_policy(path)
#>   marker compartment statistic fallback_compartment min_value
#> 1   CD3e        cell      mean                 <NA>         0
```
