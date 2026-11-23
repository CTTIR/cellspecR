# Plot cellspec quality-control views

Draws a centroid map, marker distribution, feature-support heatmap, cell
area distribution, or an overview of up to four panels with their
legends below. The overview leaves out the area panel when the cells
table has no `area` column and the marker panel when there are no
intensity features or no finite values to draw.

The map follows the image frame: the origin is at the top left and `y`
increases downwards. The map, the marker plot and the area histogram
draw one panel per image, because overlaid images hide each other. The
panels follow the order of the images table and share one common axis
range, so an image with a different extent or offset fills only part of
its panel. With more than `max_panels` images the panels would be too
small to read: the images are then pooled in one panel and the subtitle
says so. The overview gives each view half the width and pools above
half that number. The marker plot shows one marker: a violin per
intensity source (statistic on the axis, compartments side by side). The
support heatmap lists the features from top to bottom and leaves out
axis labels that would overprint their neighbours in a small panel. Maps
and marker plots of large objects use a deterministic subsample of
`max_points` cells; the support heatmap and the area histogram always
use every cell.

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
  max_panels = 12L,
  ...
)
```

## Arguments

- x:

  A `cellspec` object.

- type:

  Plot type: `"overview"`, `"map"`, `"marker"`, `"support"` or `"area"`.

- colour_by:

  A cells or measurement column that colours the points of the map.
  Without it all points have the same colour.

- marker:

  Marker shown by the marker plot. Defaults to the first marker of
  `policy` or, without a policy, the first marker returned by
  [`cs_markers()`](https://cttir.github.io/cellspecR/reference/cs_features.md).

- policy:

  Optional signal policy for the marker plot. When it covers `marker`,
  the plot shows the signal selected by
  [`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md)
  instead of the individual sources.

- max_points:

  Maximum number of cells drawn by the map and the marker plot.

- seed:

  Seed used for deterministic subsampling. The random number generator
  state of the session is left untouched.

- max_panels:

  Largest number of images drawn as separate panels by the map, the
  marker plot and the area histogram; the overview uses half of it,
  rounded up. With more images, all images share one panel. Subset the
  object or raise the value for a larger device.

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
x <- cs_example()
plot(x, type = "map")

plot(x, type = "marker", marker = "CD3e")

plot(x, type = "support")
```
