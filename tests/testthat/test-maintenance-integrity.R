test_that("commit-time destination changes preserve unrelated data", {
  target <- withr::local_tempfile()
  write_done <- cellspecR:::.cs_write_done
  local_mocked_bindings(.cs_write_done = function(stage, manifest_path) {
    write_done(stage, manifest_path)
    dir.create(target)
    writeLines("keep", file.path(target, "source.txt"))
  })
  expect_error(cs_write(min_object(), target), class = "cellspec_error_format")
  expect_identical(readLines(file.path(target, "source.txt")), "keep")
  expect_identical(list.files(target), "source.txt")

  other <- withr::local_tempfile()
  local_mocked_bindings(.cs_write_done = write_done)
  cs_write(min_object(), other)
  local_mocked_bindings(.cs_write_done = function(stage, manifest_path) {
    write_done(stage, manifest_path)
    writeLines("keep", file.path(other, "notes.txt"))
  })
  expect_error(cs_write(min_object(), other, overwrite = TRUE), class = "cellspec_error_format")
  expect_identical(readLines(file.path(other, "notes.txt")), "keep")
  expect_s3_class(cs_read_cellspec(other, verify = FALSE), "cellspec")
})

test_that("verification sees hidden files and refuses external symlink members", {
  path <- withr::local_tempfile()
  cs_write(min_object(), path)
  writeLines("private", file.path(path, ".extra"))
  report <- cs_verify(path)
  expect_false(report$ok[report$file == ".extra"])
  expect_error(cs_read_cellspec(path), class = "cellspec_error_integrity")
  unlink(file.path(path, ".extra"))
  external <- withr::local_tempfile()
  expect_true(file.copy(file.path(path, "cells.parquet"), external))
  unlink(file.path(path, "cells.parquet"))
  linked <- suppressWarnings(file.symlink(external, file.path(path, "cells.parquet")))
  if (!linked) skip("This platform does not permit symbolic links")
  report <- cs_verify(path)
  expect_false(report$ok[report$file == "cells.parquet"])
  expect_error(cs_read_cellspec(path), class = "cellspec_error_integrity")
  expect_error(cs_write(min_object(), path, overwrite = TRUE), class = "cellspec_error_format")
  expect_true(file.exists(external))
})

test_that("manifest paths are portable and control-file links are refused", {
  path <- withr::local_tempfile()
  cs_write(min_object(), path)
  manifest <- file.path(path, "MANIFEST.sha256")
  original <- readLines(manifest)
  for (name in c("..\\outside", "C:outside", "/outside")) {
    writeLines(paste0(strrep("a", 64), "  ", name), manifest)
    expect_error(cs_verify(path), class = "cellspec_error_integrity")
  }
  writeLines(original, manifest)
  outside <- withr::local_tempfile()
  file.copy(manifest, outside)
  unlink(manifest)
  if (!suppressWarnings(file.symlink(outside, manifest))) skip("Symbolic links unavailable")
  expect_error(cs_verify(path), class = "cellspec_error_integrity")
})

test_that("delimited exports retain identifiers and reject dropped rows", {
  path <- withr::local_tempfile(fileext = ".tsv")
  header <- "Cell ID\tCentroid X um\tCentroid Y um\tDAPI: Mean"
  writeLines(c(header, "001\t1\t2\t3", "002\t2\t3\t4"), path)
  expect_identical(cs_cells(cs_read(path, format = "qupath"))$cell_id, c("001", "002"))
  writeLines(c(header, "9007199254740993\t1\t2\t3", "9007199254740994\t2\t3\t4"), path)
  expect_identical(cs_cells(cs_read(path, format = "qupath"))$cell_id,
    c("9007199254740993", "9007199254740994"))
  writeLines(c(header, "001\t1\t2\t3", "002\t2\t3\t4", "broken\trow"), path)
  expect_error(cs_read(path, format = "qupath"), class = "cellspec_error_format")
})

test_that("canonical sidecar types cannot silently truncate scientific metadata", {
  path <- withr::local_tempfile()
  cs_write(min_object(), path)
  sidecar <- file.path(path, "cellspec.json")
  original <- jsonlite::fromJSON(sidecar, simplifyVector = FALSE)
  for (value in list(1.5, 2^31, list(1L, 2L))) {
    doc <- original
    doc$channels$rows[[1L]]$channel_index <- value
    jsonlite::write_json(doc, sidecar, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
    expect_error(cs_read_cellspec(path, verify = FALSE), class = "cellspec_error_format")
  }
  doc <- original
  doc$format <- "another-format"
  jsonlite::write_json(doc, sidecar, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
  expect_error(cs_read_cellspec(path, verify = FALSE), class = "cellspec_error_format")
})

test_that("cell identity does not collide with separator characters", {
  latin <- iconv("\u00fc", from = "UTF-8", to = "latin1")
  expect_identical(cellspecR:::.cs_key(latin, "cell"),
    cellspecR:::.cs_key(enc2utf8(latin), "cell"))
  parts <- min_parts()
  parts$cells$image_id <- c("a\rb", "a", "a")
  parts$cells$cell_id <- c("c", "b\rc", "other")
  parts$images <- parts$images[c(1L, 1L), , drop = FALSE]
  parts$images$image_id <- c("a\rb", "a")
  parts$channels <- parts$channels[rep(1:3, 2), , drop = FALSE]
  parts$channels$image_id <- rep(c("a\rb", "a"), each = 3)
  x <- cs_new(parts$cells, parts$measurements, parts$dictionary, parts$images, parts$channels)
  expect_s3_class(x, "cellspec")
  expect_identical(cs_cells(x[1:2, ])$cell_id, c("c", "b\rc"))
})


test_that("foreign parser diagnostics are literal text rather than expressions", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(c("Cell ID\tCentroid X um\tCentroid Y um\tDAPI: Mean",
    "001\t1\t2\t3", "002\t2\t3\t4", "{1 + 1}\trow"), path)
  error <- tryCatch(cs_read(path, format = "qupath"), error = identity)
  expect_s3_class(error, "cellspec_error_format")
  expect_match(conditionMessage(error), "{1 + 1}", fixed = TRUE)
  bad_json <- withr::local_tempfile(lines = "{broken}")
  expect_error(cellspecR:::.cs_read_json(bad_json), class = "cellspec_error_format")
})
