test_that("cs_app validates launcher arguments", {
  skip_if_not_installed("shiny")
  expect_error(cs_app(max_upload_mb = 0), class = "cellspec_error")
  expect_error(cs_app(max_plot_points = 0), class = "cellspec_error")
  expect_error(cs_app(path = tempfile()), class = "cellspec_error_format")
  app <- cs_app(allow_local_paths = TRUE)
  expect_s3_class(app, "shiny.appobj")
})

test_that("the app UI exposes the reader workflow", {
  skip_if_not_installed("shiny")
  ui <- cellspecR:::.cs_app_ui(allow_local_paths = TRUE)
  expect_true(inherits(ui, "shiny.tag") || inherits(ui, "shiny.tag.list"))
  expect_true(grepl("f_export", paste(capture.output(ui), collapse = " ")))
  expect_true(grepl("download_validation", paste(capture.output(ui), collapse = " ")))
  expect_true(grepl("download_dictionary", paste(capture.output(ui), collapse = " ")))
})

test_that("the app About panel reports release metadata", {
  skip_if_not_installed("shiny")
  about <- cellspecR:::.cs_app_about()
  rendered <- paste(capture.output(about), collapse = " ")
  expect_match(rendered, "About cellspecR")
  expect_match(rendered, "Version\\s+1\\.0\\.0")
  expect_match(rendered, "Specification\\s+1\\.0\\.0")
})

test_that("the app server reads a local export and exposes review tables", {
  skip_if_not_installed("shiny")
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    data.frame(
      `Cell ID` = c("a", "b"), `Centroid X um` = c(1, 2),
      `Centroid Y um` = c(3, 4), `DAPI: Mean` = c(10, 20),
      check.names = FALSE, stringsAsFactors = FALSE
    ),
    path, sep = "\t", quote = FALSE
  )

  shiny::testServer(
    function(input, output, session) {
      cellspecR:::.cs_app_server(
        input, output, session, initial_path = NULL,
        allow_local_paths = TRUE, max_plot_points = 10L
      )
    },
    {
      expect_match(output$status, "Ready to read")
      expect_null(output$validation)
      expect_null(output$cells)
      expect_null(output$dictionary)
      expect_null(output$images)
      session$setInputs(local_path = path, format = "qupath")
      session$flushReact()
      session$setInputs(btn_read = 1)
      session$flushReact()
      expect_match(output$status, "Read 2 cells")
      expect_match(output$validation, "cells_key_unique")
      expect_match(output$cells, "cell_id")
      expect_match(output$dictionary, "feature_id")
      expect_match(output$images, "image_id")
    }
  )
})

test_that("the app server accepts an uploaded file", {
  skip_if_not_installed("shiny")
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    stats::setNames(
      data.frame("a", 1, 2, 3, stringsAsFactors = FALSE),
      c("Cell ID", "Centroid X um", "Centroid Y um", "DAPI: Mean")
    ),
    path, sep = "\t", quote = FALSE
  )
  shiny::testServer(
    function(input, output, session) {
      cellspecR:::.cs_app_server(
        input, output, session, initial_path = NULL,
        allow_local_paths = FALSE, max_plot_points = 10L
      )
    },
    {
      session$setInputs(
        f_export = data.frame(
          name = basename(path), datapath = path, type = "text/tab-separated-values",
          size = file.info(path)$size, stringsAsFactors = FALSE
        ),
        format = "qupath"
      )
      session$flushReact()
      session$setInputs(btn_read = 1)
      session$flushReact()
      expect_match(output$status, "Read 1 cells")
    }
  )
})

test_that("the app download handlers write their current tables", {
  skip_if_not_installed("shiny")
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    stats::setNames(
      data.frame("a", 1, 2, 3, stringsAsFactors = FALSE),
      c("Cell ID", "Centroid X um", "Centroid Y um", "DAPI: Mean")
    ),
    path, sep = "\t", quote = FALSE
  )

  app <- cs_app(allow_local_paths = TRUE)
  server <- app$server()
  shiny::testServer(
    function(input, output, session) server(input, output, session),
    {
      register_download <- function(id) {
        render_function <- session$.__enclos_env__$private$outs[[id]]$func
        render_env <- base::environment(render_function)
        render_env$renderFunc(session, id)
        session$.__enclos_env__$private$file_generators$get(
          paste0("mock-session-", id)
        )
      }

      validation <- register_download("download_validation")
      dictionary <- register_download("download_dictionary")
      validation_file <- tempfile(fileext = ".csv")
      dictionary_file <- tempfile(fileext = ".csv")
      on.exit(unlink(c(validation_file, dictionary_file)), add = TRUE)
      validation$content(validation_file)
      dictionary$content(dictionary_file)
      expect_match(paste(readLines(validation_file), collapse = "\n"), "not_run")
      expect_match(paste(readLines(dictionary_file), collapse = "\n"), "feature_id")

      session$setInputs(local_path = path, format = "qupath")
      session$flushReact()
      session$setInputs(btn_read = 1)
      session$flushReact()
      session$flushOutput()
      session$flushReact()
      validation <- register_download("download_validation")
      dictionary <- register_download("download_dictionary")
      validation$content(validation_file)
      dictionary$content(dictionary_file)
      expect_match(paste(readLines(validation_file), collapse = "\n"), "cells_key_unique")
      expect_match(paste(readLines(dictionary_file), collapse = "\n"), "feature_id")
    }
  )
})

test_that("the app server reports a missing local path", {
  skip_if_not_installed("shiny")
  shiny::testServer(
    function(input, output, session) {
      cellspecR:::.cs_app_server(
        input, output, session, initial_path = NULL,
        allow_local_paths = TRUE, max_plot_points = 10L
      )
    },
    {
      session$setInputs(local_path = file.path(tempdir(), "missing-export.tsv"))
      session$flushReact()
      session$setInputs(btn_read = 1)
      session$flushReact()
      expect_match(output$status, "does not exist")
    }
  )
})

test_that("the app server reports missing input and unreadable exports", {
  skip_if_not_installed("shiny")
  bad <- tempfile(fileext = ".tsv")
  on.exit(unlink(bad), add = TRUE)
  file.create(bad)
  shiny::testServer(
    function(input, output, session) {
      cellspecR:::.cs_app_server(
        input, output, session, initial_path = NULL,
        allow_local_paths = TRUE, max_plot_points = 10L
      )
    },
    {
      session$setInputs(btn_read = 0)
      session$flushReact()
      session$setInputs(btn_read = 1)
      session$flushReact()
      expect_match(output$status, "Choose an export")
      session$setInputs(local_path = bad, format = NULL)
      session$flushReact()
      session$setInputs(btn_read = 2)
      session$flushReact()
      expect_match(output$status, "no columns")
    }
  )
})

test_that("the app uses an initial path when local paths are disabled", {
  skip_if_not_installed("shiny")
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    stats::setNames(
      data.frame("a", 1, 2, 3, stringsAsFactors = FALSE),
      c("Cell ID", "Centroid X um", "Centroid Y um", "DAPI: Mean")
    ),
    path, sep = "\t", quote = FALSE
  )
  shiny::testServer(
    function(input, output, session) {
      cellspecR:::.cs_app_server(
        input, output, session, initial_path = path,
        allow_local_paths = FALSE, max_plot_points = 10L
      )
    },
    {
      expect_match(output$status, "Initial path")
      session$setInputs(format = "qupath", btn_read = 1)
      session$flushReact()
      expect_match(output$status, "Read 1 cells")
    }
  )
})
