test_that("parquet canonical write and read preserve components", {
  x <- sim_object(adjacency = TRUE)
  path <- file.path(tempdir(), "cellspec round trip \u00e4")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)

  expect_invisible(cs_write(x, path))
  expect_true(file.exists(file.path(path, "cells.parquet")))
  expect_true(file.exists(file.path(path, "cellspec.json")))
  expect_true(file.exists(file.path(path, "MANIFEST.sha256")))
  expect_true(file.exists(file.path(path, "DONE")))
  expect_true(all(cs_verify(path)$ok))

  y <- cs_read_cellspec(path)
  expect_identical(cs_cells(y), cs_cells(x))
  expect_identical(cs_dictionary(y), cs_dictionary(x))
  expect_identical(cs_images(y), cs_images(x))
  expect_identical(cs_channels(y), cs_channels(x))
  expect_identical(cs_measurements(y), cs_measurements(x))
  expect_identical(cs_adjacency(y), cs_adjacency(x))
})

test_that("tsv.gz is an exact round trip for doubles and empty metadata", {
  p <- min_parts()
  p$images$platform <- "laboratory \u00b5"
  p$images$subject_id <- NA_character_
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  path <- file.path(tempdir(), "cellspec tsv \u00df")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)

  cs_write(x, path, format = "tsv.gz")
  expect_true(file.exists(file.path(path, "cells.tsv.gz")))
  y <- cs_read_cellspec(path)
  expect_identical(cs_cells(y), cs_cells(x))
  expect_identical(cs_dictionary(y), cs_dictionary(x))
  expect_identical(cs_images(y), cs_images(x))
  expect_identical(cs_channels(y), cs_channels(x))
  expect_identical(cs_measurements(y), cs_measurements(x))
})

test_that("a changed data byte fails integrity verification", {
  path <- tempfile("cellspec-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  cs_write(min_object(), path)
  data_path <- file.path(path, "cells.parquet")
  raw <- readBin(data_path, what = "raw", n = file.info(data_path)$size)
  raw[[length(raw)]] <- as.raw(bitwXor(as.integer(raw[[length(raw)]]), 1L))
  con <- file(data_path, open = "wb")
  writeBin(raw, con)
  close(con)

  report <- cs_verify(path)
  expect_true(any(report$file == "cells.parquet" & !report$ok))
  expect_error(cs_read_cellspec(path), class = "cellspec_error_integrity")
})

test_that("DONE is required and interrupted staging is cleaned", {
  path <- tempfile("cellspec-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  cs_write(min_object(), path)
  unlink(file.path(path, "DONE"))
  expect_error(cs_read_cellspec(path), class = "cellspec_error_integrity")

  interrupted <- tempfile("cellspec-interrupted-")
  on.exit(unlink(interrupted, recursive = TRUE, force = TRUE), add = TRUE)
  withr::local_options(c(cellspecR.test_write_hook = function(stage) {
    rlang::abort("simulated interrupted write")
  }))
  expect_error(cs_write(min_object(), interrupted), "simulated interrupted write")
  expect_false(dir.exists(interrupted))
  expect_length(list.files(dirname(interrupted),
                           pattern = paste0("^", basename(interrupted),
                                             "\\.partial-")), 0L)
})

test_that("existing destinations require explicit overwrite", {
  path <- tempfile("cellspec-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  cs_write(min_object(), path)
  expect_error(cs_write(min_object(), path), class = "cellspec_error_format")
  expect_invisible(cs_write(min_object(), path, overwrite = TRUE))
  expect_true(all(cs_verify(path)$ok))
})
