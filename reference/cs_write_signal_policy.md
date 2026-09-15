# Write a signal policy as JSON or CSV

**\[experimental\]**

Writes a validated signal policy. The format is inferred from the
`.json` or `.csv` extension unless `format` is supplied explicitly.

## Usage

``` r
cs_write_signal_policy(policy, path, format = NULL)
```

## Arguments

- policy:

  A `cs_signal_policy` object.

- path:

  Destination file path.

- format:

  Either `"json"` or `"csv"`; by default inferred from `path`.

## Value

`policy`, invisibly.

## See also

[`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md)

Other signals:
[`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md),
[`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md),
[`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md),
[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md)

## Examples

``` r
path <- tempfile(fileext = ".json")
cs_write_signal_policy(cs_signal_policy("CD3e"), path)
```
