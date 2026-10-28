# Minimal local review app for cellspec exports.

.cs_app_require <- function(package, call = rlang::caller_env()) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .cs_abort(
      c("The cellspec app needs {.pkg {package}}.", "i" = "Install {.pkg {package}} to use {.fn cs_app}."),
      class = "cellspec_error_format", call = call
    )
  }
  invisible(TRUE)
}

#' Create the cellspec review application
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Builds a local Shiny application for reading an export, reviewing format
#' detection and validation, and downloading the resulting tables. The
#' function returns an application object; launch it with `shiny::runApp()`.
#'
#' @param path Optional initial file or directory path. The user can also
#'   select a file in the application.
#' @param max_upload_mb Maximum upload size in MB. It is applied as the
#'   `shiny.maxRequestSize` option while the application runs and the previous
#'   value is restored when it stops.
#' @param allow_local_paths Whether a local path field is available.
#' @param max_plot_points Maximum cells passed to plots.
#' @param ... Reserved for launcher settings.
#' @return A `shiny.appobj`.
#' @family app
#' @export
#' @examples
#' if (requireNamespace("shiny", quietly = TRUE)) {
#'   app <- cs_app()
#'   inherits(app, "shiny.appobj")
#' }
cs_app <- function(path = NULL, max_upload_mb = 2048,
                   allow_local_paths = FALSE, max_plot_points = 50000L, ...) {
  call <- rlang::caller_env()
  .cs_app_require("shiny", call = call)
  .cs_check_string(path, allow_null = TRUE, arg = "path", call = call)
  .cs_check_number(max_upload_mb, min = 1, arg = "max_upload_mb", call = call)
  .cs_check_flag(allow_local_paths, arg = "allow_local_paths", call = call)
  .cs_check_count(max_plot_points, min = 1L, arg = "max_plot_points", call = call)
  if (!is.null(path)) .cs_check_path(path, arg = "path", call = call)
  dots <- list(...)
  if (length(dots) > 0L && is.null(names(dots))) {
    .cs_abort("Additional app arguments must be named.", call = call)
  }
  .cs_app_object(
    initial_path = path,
    max_upload_mb = max_upload_mb,
    allow_local_paths = allow_local_paths,
    max_plot_points = max_plot_points
  )
}

# Sets the Shiny upload limit and returns a function that restores the
# previous value.
.cs_app_upload_limit <- function(max_upload_mb) {
  old <- options(shiny.maxRequestSize = max_upload_mb * 1024^2)
  function() options(old)
}

.cs_app_object <- function(initial_path, max_upload_mb, allow_local_paths,
                           max_plot_points) {
  shiny::shinyApp(
    ui = .cs_app_ui(initial_path, max_upload_mb, allow_local_paths),
    server = function(input, output, session) {
      .cs_app_server(input, output, session, initial_path, allow_local_paths, max_plot_points)
    },
    onStart = function() {
      shiny::onStop(.cs_app_upload_limit(max_upload_mb))
    }
  )
}
