# Server logic for the cellspec review app.

.cs_app_server <- function(input, output, session, initial_path,
                            allow_local_paths, max_plot_points) {
  state <- shiny::reactiveVal(NULL)
  detection <- shiny::reactiveVal(NULL)
  log <- shiny::reactiveVal(if (is.null(initial_path)) "Ready to read an export." else paste("Initial path:", initial_path))
  append_log <- function(message) log(c(log(), paste(format(Sys.time(), "%H:%M:%S"), message)))
  selected_path <- shiny::reactive({
    upload <- input$f_export
    if (!is.null(upload) && nrow(upload) > 0L) return(upload$datapath[[1L]])
    local_value <- input$local_path
    if (allow_local_paths && !is.null(local_value) && nzchar(local_value)) return(local_value)
    initial_path
  })
  output$status <- shiny::renderText(paste(log(), collapse = "\n"))
  output$detection <- shiny::renderTable(detection())
  output$validation <- shiny::renderTable({
    x <- state()
    if (is.null(x)) return(NULL)
    cs_validate(x)
  })
  output$download_validation <- shiny::downloadHandler(
    filename = function() "cellspec-validation.csv",
    content = function(file) {
      x <- state()
      table <- if (is.null(x)) {
        data.frame(check = "read", status = "not_run", stringsAsFactors = FALSE)
      } else {
        cs_validate(x)
      }
      data.table::fwrite(table, file)
    }
  )
  output$cells <- shiny::renderTable({
    x <- state()
    if (is.null(x)) return(NULL)
    utils::head(x$cells, 100L)
  })
  output$dictionary <- shiny::renderTable({
    x <- state()
    if (is.null(x)) return(NULL)
    x$dictionary
  })
  output$download_dictionary <- shiny::downloadHandler(
    filename = function() "cellspec-dictionary.csv",
    content = function(file) {
      x <- state()
      table <- if (is.null(x)) .cs_empty_df("dictionary") else x$dictionary
      data.table::fwrite(table, file)
    }
  )
  output$images <- shiny::renderTable({
    x <- state()
    if (is.null(x)) return(NULL)
    x$images
  })
  output$overview <- shiny::renderPlot({
    x <- state()
    if (is.null(x) || !requireNamespace("ggplot2", quietly = TRUE)) return(NULL)
    plot(x, type = "map", max_points = max_plot_points)
  })
  shiny::observeEvent(input$btn_read, {
    path <- selected_path()
    if (is.null(path) || !nzchar(path)) {
      append_log("Choose an export or supply a local path.")
      return()
    }
    if (!file.exists(path)) {
      append_log("The selected path does not exist.")
      return()
    }
    fmt <- input$format
    if (is.null(fmt) || !nzchar(fmt)) fmt <- "auto"
    size <- input$pixel_size
    if (length(size) == 0L || is.na(size)) size <- NULL
    candidate <- tryCatch(cs_detect_format(path), error = function(error) error)
    if (inherits(candidate, "error")) {
      append_log(conditionMessage(candidate))
    } else {
      detection(candidate)
    }
    result <- tryCatch(
      cs_read(path, format = fmt, pixel_size = size),
      error = function(error) error
    )
    if (inherits(result, "error")) {
      append_log(conditionMessage(result))
      return()
    }
    state(result)
    append_log(paste("Read", nrow(result$cells), "cells with", result$provenance$reader$adapter, "adapter."))
  }, ignoreInit = TRUE)
}
