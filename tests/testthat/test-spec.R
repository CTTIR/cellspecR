test_that("cs_spec_version() is a semantic version of major 1", {
  v <- cs_spec_version()
  expect_type(v, "character")
  expect_length(v, 1L)
  expect_match(v, "^1\\.[0-9]+\\.[0-9]+$")
})

test_that("cs_vocabulary() returns the column table", {
  cols <- cs_vocabulary("columns")
  expect_s3_class(cols, "data.frame")
  expect_named(cols, c("component", "column", "type", "requirement", "description"))
  expect_setequal(unique(cols$component), c("cells", "dictionary", "images", "channels", "adjacency"))
  expect_true(all(cols$type %in% c("character", "double", "integer")))
  expect_true(all(cols$requirement %in% c("MUST", "SHOULD", "MAY")))
  expect_false(anyDuplicated(paste(cols$component, cols$column)) > 0L)
  must_cells <- cols$column[cols$component == "cells" & cols$requirement == "MUST"]
  expect_identical(must_cells, c("cell_id", "image_id", "sample_id", "x", "y"))
})

test_that("cs_vocabulary() returns the vocabularies", {
  voc <- cs_vocabulary("vocabularies")
  expect_named(voc, c("vocabulary", "value", "description"))
  expect_identical(
    voc$value[voc$vocabulary == "compartment"],
    c("cell", "nucleus", "cytoplasm", "membrane")
  )
  expect_identical(
    voc$value[voc$vocabulary == "intensity_statistic"],
    c("mean", "median", "sd", "min", "max", "sum", "variance")
  )
  expect_true(all(c("a.u.", "um", "um2", "1") %in% voc$value[voc$vocabulary == "unit"]))
  expect_false(anyDuplicated(paste(voc$vocabulary, voc$value)) > 0L)
})

test_that("cs_vocabulary() defaults to columns and rejects unknown tables", {
  expect_identical(cs_vocabulary(), cs_vocabulary("columns"))
  expect_error(cs_vocabulary("nope"))
})

test_that("the validation catalogue has unique names and known levels", {
  checks <- cellspecR:::.cs_checks()
  expect_false(anyDuplicated(checks$check) > 0L)
  expect_true(all(checks$level %in% c("structure", "semantic")))
})
