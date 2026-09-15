test_that("cs_formats lists the available reader adapters", {
  formats <- cellspecR:::cs_formats()

  expect_named(formats, c("format", "adapter_version", "description",
                          "tested_with", "status"))
  expect_true(all(c("table", "qupath", "qupath_tiled", "mcquant", "segmantr", "inform") %in% formats$format))
  expect_identical(formats$status[[1L]], "stable")
})

test_that("cs_column_map validates mappings and measurement metadata", {
  metadata <- data.frame(
    source_name = "CD3e Mean",
    kind = "intensity",
    marker = "CD3e",
    compartment = "cell",
    statistic = "mean",
    unit = "a.u.",
    stringsAsFactors = FALSE
  )
  map <- cellspecR:::cs_column_map(
    cell_id = "Cell ID",
    x = "Centroid X",
    y = "Centroid Y",
    image_id = "Image",
    sample_id = "Sample",
    area = "Area",
    measurements = metadata
  )

  expect_s3_class(map, "cs_column_map")
  expect_identical(map$cell_id, "Cell ID")
  expect_identical(map$coordinate_unit, "um")
  expect_identical(map$measurements$source_name, "CD3e Mean")
  expect_error(
    cellspecR:::cs_column_map("id", "x", "x"),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::cs_column_map(
      "id", "x", "y",
      measurements = data.frame(source_name = "v", kind = "intensity",
                                marker = NA_character_, compartment = "cell",
                                statistic = "mean", unit = "a.u.")
    ),
    class = "cellspec_error_format"
  )
})

test_that("flat Cell Type tables are explicit and are not specialized", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(
    `Cell ID` = c("a", "b"),
    `Cell X Position` = c(1, 2),
    `Cell Y Position` = c(3, 4),
    `Cell Type` = c("T", "B"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ), path)
  detected <- cellspecR:::cs_detect_format(path, n_max = 1L)

  expect_identical(detected$format, "table")
  expect_true(detected$score[[1L]] < 0.9)
  expect_error(
    cellspecR:::cs_read(path, format = "auto"),
    class = "cellspec_error_ambiguous_format"
  )

  x <- cellspecR:::cs_read(
    path,
    format = "table",
    column_map = cellspecR:::cs_column_map(
      "Cell ID", "Cell X Position", "Cell Y Position"
    )
  )
  expect_identical(cellspecR:::cs_cells(x)$x, c(1, 2))
  expect_identical(cellspecR:::cs_cells(x)$y, c(3, 4))
  expect_identical(cellspecR:::cs_cells(x)$`Cell Type`, c("T", "B"))
})

test_that("missing IDs never fall back to row numbers", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(id = c("c1", NA), x = c(1, 2), y = c(3, 4)), path)
  map <- cellspecR:::cs_column_map("id", "x", "y")

  expect_error(
    cellspecR:::cs_read(path, format = "table", column_map = map),
    class = "cellspec_error_format"
  )
})

test_that("pixel coordinates require calibration and are converted", {
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(id = c("c1", "c2"), x = c(2, 4), y = c(3, 5)),
                     path, sep = "\t")
  map <- cellspecR:::cs_column_map("id", "x", "y", coordinate_unit = "px")

  expect_error(
    cellspecR:::cs_read(path, format = "table", column_map = map),
    class = "cellspec_error_units"
  )
  x <- cellspecR:::cs_read(path, format = "table", pixel_size = 0.5,
                           column_map = map)
  expect_identical(cellspecR:::cs_cells(x)$x, c(1, 2))
  expect_identical(cellspecR:::cs_cells(x)$y, c(1.5, 2.5))
  expect_identical(cellspecR:::cs_cells(x)$x_px, c(2, 4))
  expect_identical(cellspecR:::cs_images(x)$pixel_size, 0.5)
})

test_that("explicit numeric measurement mappings populate the dictionary", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(
    id = c("c1", "c2"), x = c(1, 2), y = c(3, 4), area_um2 = c(20, 25),
    stringsAsFactors = FALSE
  ), path)
  metadata <- data.frame(
    source_name = "area_um2",
    kind = "shape",
    marker = NA_character_,
    compartment = "cell",
    statistic = "area",
    unit = "um2",
    stringsAsFactors = FALSE
  )
  x <- cellspecR:::cs_read(
    path,
    format = "table",
    column_map = cellspecR:::cs_column_map("id", "x", "y", measurements = metadata)
  )

  expect_identical(colnames(cellspecR:::cs_measurements(x)), "cell:area")
  expect_identical(unname(cellspecR:::cs_measurements(x)[, 1]), c(20, 25))
  expect_identical(cellspecR:::cs_dictionary(x)$source_name, "area_um2")
  expect_identical(cellspecR:::cs_dictionary(x)$unit, "um2")
  expect_invisible(cellspecR:::cs_assert_valid(x))
})

test_that("unmapped numeric columns become other features and unsupported formats fail clearly", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(id = "c1", x = 1, y = 2, score = 0.25), path)
  x <- cellspecR:::cs_read(
    path,
    format = "table",
    column_map = cellspecR:::cs_column_map("id", "x", "y")
  )

  expect_identical(colnames(cellspecR:::cs_measurements(x)), "other:score")
  expect_error(
    cellspecR:::cs_read(path, format = "qupath",
                        column_map = cellspecR:::cs_column_map("id", "x", "y")),
    class = "cellspec_error_units"
  )
})
