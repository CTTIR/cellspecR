# Create the cellspec review application

**\[stable\]**

Builds a local Shiny application for reading an export, reviewing format
detection and validation, and downloading the resulting tables. The
function returns an application object; launch it with
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Usage

``` r
cs_app(
  path = NULL,
  max_upload_mb = 2048,
  allow_local_paths = FALSE,
  max_plot_points = 50000L,
  ...
)
```

## Arguments

- path:

  Optional initial file or directory path. The user can also select a
  file in the application.

- max_upload_mb:

  Maximum upload size shown to the application in MB.

- allow_local_paths:

  Whether a local path field is available.

- max_plot_points:

  Maximum cells passed to plots.

- ...:

  Reserved for launcher settings.

## Value

A `shiny.appobj`.

## Examples

``` r
if (requireNamespace("shiny", quietly = TRUE)) {
  app <- cs_app()
  inherits(app, "shiny.appobj")
}
#> [1] TRUE
```
