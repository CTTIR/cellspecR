schema_path <- function() {
  system.file("schema", "cellspec-1.0.0.schema.json", package = "cellspecR")
}

test_that("the schema ships with the package and is valid JSON", {
  path <- schema_path()
  expect_true(file.exists(path))
  schema <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expect_identical(schema$properties$format$const, "cellspec")
  # Vocabularies in the schema match the R specification tables.
  voc <- cs_vocabulary("vocabularies")
  row <- schema$definitions$dictionary_row$properties
  expect_setequal(unlist(row$kind$enum), voc$value[voc$vocabulary == "kind"])
  expect_setequal(unlist(row$unit$enum), voc$value[voc$vocabulary == "unit"])
  comps <- unlist(row$compartment$enum)
  expect_setequal(comps[!vapply(row$compartment$enum, is.null, logical(1))],
                  voc$value[voc$vocabulary == "compartment"])
  cols <- cs_vocabulary("columns")
  must <- function(component) cols$column[cols$component == component & cols$requirement == "MUST"]
  expect_setequal(unlist(schema$definitions$dictionary_row$required), must("dictionary"))
  expect_setequal(unlist(schema$definitions$image_row$required), must("images"))
  expect_setequal(unlist(schema$definitions$channel_row$required), must("channels"))
})

test_that("a hand-written sidecar validates against the schema", {
  skip_if_not_installed("jsonvalidate")
  validate <- jsonvalidate::json_validator(schema_path(), engine = "ajv")
  example <- test_path("fixtures", "cellspec-sidecar-example.json")
  expect_true(validate(paste(readLines(example, encoding = "UTF-8"), collapse = "\n")))
})

test_that("the schema rejects malformed sidecars", {
  skip_if_not_installed("jsonvalidate")
  validate <- jsonvalidate::json_validator(schema_path(), engine = "ajv")
  example <- jsonlite::fromJSON(test_path("fixtures", "cellspec-sidecar-example.json"),
                                simplifyVector = FALSE)
  to_json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", pretty = FALSE)

  bad_version <- example
  bad_version$spec_version <- "2.0.0"
  expect_false(validate(to_json(bad_version)))

  bad_kind <- example
  bad_kind$dictionary$rows[[1]]$kind <- "texture"
  expect_false(validate(to_json(bad_kind)))

  no_pixel <- example
  no_pixel$images$rows[[1]]$pixel_size <- NULL
  expect_false(validate(to_json(no_pixel)))

  bad_hash <- example
  bad_hash$provenance$inputs[[1]]$sha256 <- "abc"
  expect_false(validate(to_json(bad_hash)))

  no_history <- example
  no_history$provenance$history <- NULL
  expect_false(validate(to_json(no_history)))
})
