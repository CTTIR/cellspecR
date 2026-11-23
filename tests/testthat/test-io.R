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
  local_mocked_bindings(.cs_write_done = function(stage, manifest_path) {
    rlang::abort("simulated interrupted write")
  })
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

test_that("both storage formats return text with quotes and separators unchanged", {
  x <- sim_object()
  n <- nrow(x$cells)
  text <- c(
    "x\"y", "\"", "\"\"", "\"abc", "abc\"", "a\\b", "x\\\"y", "a\"\"b",
    "tab\there", "line\nbreak", "", NA, "NA", " \"q\" ", "\\",
    "he said \"hi\", twice", "'single'", "a,b", " lead ", "ünï"
  )
  x$cells$note <- rep(text, length.out = n)
  # A column name with a quote must come back as it was, too.
  x$cells[["cell \"type\""]] <- rep(c("T \"reg\"", "B"), length.out = n)
  x$cells$flag <- rep(c(TRUE, FALSE, NA), length.out = n)
  x$images$platform <- c("scanner \"A\"", "NA")
  x$adjacency$method[] <- "mask_touching"
  for (format in c("parquet", "tsv.gz")) {
    dir <- tempfile("cellspec-text-")
    cs_write(x, dir, format = format)
    y <- cs_read_cellspec(dir)
    for (component in c("cells", "measurements", "dictionary", "images",
                        "channels", "adjacency")) {
      expect_identical(y[[component]], x[[component]],
                       info = paste(format, component))
    }
    unlink(dir, recursive = TRUE)
  }

  # A table without rows keeps a quoted column name as well.
  empty <- x[0, ]
  dir <- tempfile("cellspec-text-")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  cs_write(empty, dir, format = "tsv.gz")
  expect_identical(cs_read_cellspec(dir)$cells, empty$cells)
  expect_identical(cellspecR:::.cs_tsv_unquote(c("a\"\"b", NA, "")), c("a\"b", NA, ""))
})
