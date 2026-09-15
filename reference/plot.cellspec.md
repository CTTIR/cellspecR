# Plot cellspec quality-control views

**\[experimental\]**

Draws a centroid map, marker distribution, feature-support heatmap, cell
area distribution, or a four-panel overview. Large objects are
subsampled deterministically for plotting.

## Usage

``` r
# S3 method for class 'cellspec'
plot(
  x,
  type = c("overview", "map", "marker", "support", "area"),
  colour_by = NULL,
  marker = NULL,
  policy = NULL,
  max_points = 50000L,
  seed = 1L,
  ...
)
```

## Arguments

- x:

  A `cellspec` object.

- type:

  Plot type: `"overview"`, `"map"`, `"marker"`, `"support"` or `"area"`.

- colour_by:

  A cells or measurement column used by the map.

- marker:

  Marker used by the marker plot.

- policy:

  Optional signal policy for the marker plot.

- max_points:

  Maximum number of cells used by a plot.

- seed:

  Seed used for deterministic subsampling.

- ...:

  Reserved for future plot-specific parameters.

## Value

A `ggplot` object, or a patchwork object for `type = "overview"`.

## See also

Other methods:
[`[.cellspec()`](https://cttir.github.io/cellspecR/reference/sub-.cellspec.md),
[`as.data.frame.cellspec()`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md),
[`cellspec-methods`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md)

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  plot(cs_example(), type = "map")
}
```
