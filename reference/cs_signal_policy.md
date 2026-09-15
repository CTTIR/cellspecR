# Create a signal selection policy

**\[experimental\]**

Creates one validated row per marker. Signal policies make the selected
compartment, statistic, fallback and minimum usable value explicit.

## Usage

``` r
cs_signal_policy(
  marker,
  compartment = "cell",
  statistic = "mean",
  fallback_compartment = NA_character_,
  min_value = 0
)
```

## Arguments

- marker:

  Character vector of unique marker names.

- compartment:

  Preferred compartment for each marker. A single value is recycled
  across `marker`.

- statistic:

  Intensity statistic for each marker. A single value is recycled across
  `marker`.

- fallback_compartment:

  Optional fallback compartment for each marker; `NA` disables fallback.
  A single value is recycled across `marker`.

- min_value:

  Minimum usable value for each marker. Values below this threshold are
  unavailable. A single value is recycled across `marker`.

## Value

A data frame with class `cs_signal_policy` and columns `marker`,
`compartment`, `statistic`, `fallback_compartment` and `min_value`.

## See also

[`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md),
[`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md)

Other signals:
[`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md),
[`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md),
[`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md),
[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)

## Examples

``` r
cs_signal_policy(
  marker = c("PanCK", "FOXP3"),
  compartment = c("cytoplasm", "nucleus"),
  fallback_compartment = "cell"
)
#>   marker compartment statistic fallback_compartment min_value
#> 1  PanCK   cytoplasm      mean                 cell         0
#> 2  FOXP3     nucleus      mean                 cell         0
```
