test_that("MCQuant pixel centroids are converted and features are described", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data <- data.frame(
    cell_id = c(1L, 2L), area = c(20, 25), CD3e_mean = c(3, 4),
    CD3e_sd = c(1, 2), stringsAsFactors = FALSE
  )
  data[[paste0("centroid_", "row")]] <- c(4L, 8L)
  data[[paste0("centroid_", "col")]] <- c(2L, 6L)
  data.table::fwrite(data, path)
  x <- cellspecR:::cs_read(path, format = "mcquant", pixel_size = 0.5)
  expect_identical(x$cells$cell_id, c("1", "2"))
  expect_identical(x$cells$x, c(1, 3))
  expect_identical(x$cells$y, c(2, 4))
  expect_identical(colnames(x$measurements), c("cell:CD3e:mean", "cell:CD3e:sd"))
  expect_identical(x$dictionary$source_name, c("CD3e_mean", "CD3e_sd"))
  expect_identical(x$provenance$reader$adapter, "mcquant")
})

test_that("segmantR conventions and RDS input are supported", {
  data <- data.frame(
    cell_id = 1L, DAPI_mean = 5, DAPI_q25 = 2, perimeter = 8,
    stringsAsFactors = FALSE
  )
  data[[paste0("centroid_", "row")]] <- 10
  data[[paste0("centroid_", "col")]] <- 20
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(data, path)
  expect_identical(cellspecR:::cs_detect_format(path)$format[[1L]], "segmantr")
  x <- cellspecR:::cs_read(path, format = "segmantr", pixel_size = 0.25)
  expect_identical(x$cells$x, 4.875)
  expect_identical(x$cells$y, 2.375)
  expect_true(all(c("cell:DAPI:mean", "other:dapi_q25", "cell:perimeter") %in% colnames(x$measurements)))
  expect_identical(x$dictionary$kind[match("cell:perimeter", x$dictionary$feature_id)], "shape")
})

test_that("segmantR first-pixel centre and area use physical units", {
  data <- data.frame(
    cell_id = c(1L, 2L), centroid_row = c(1, 1.5), centroid_col = c(1, 2), # nolint: cttir_domain_vocab
    area = c(1, 4), perimeter = c(4, 8), DAPI_mean = c(0, NA_real_)
  )
  for (ext in c("rds", "csv")) {
    path <- tempfile(fileext = paste0(".", ext))
    if (ext == "rds") saveRDS(data, path) else data.table::fwrite(data, path)
    x <- cs_read(path, format = "segmantr", pixel_size = 0.5, quiet = TRUE)
    unlink(path)
    expect_equal(x$cells$x, c(0.25, 0.75))
    expect_equal(x$cells$y, c(0.25, 0.5))
    expect_equal(x$cells$area, c(0.25, 1))
    expect_equal(x$cells$x_px, c(0.5, 1.5))
    expect_identical(x$measurements[, "cell:DAPI:mean"], c(0, NA_real_))
    expect_identical(x$dictionary$unit[x$dictionary$feature_id == "cell:perimeter"], "px")
    expect_identical(x$provenance$parameters$coordinate_conversion$index_offset, -0.5)
    expect_identical(x$provenance$reader$adapter_version, "1.0.1")
  }
})

test_that("segmantR rejects unqualified coordinate conventions", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(cell_id = 1L, x_px = 1, y_px = 1), path)
  expect_error(cs_read(path, format = "segmantr", pixel_size = 0.5),
               class = "cellspec_error_units")
})

test_that("segmantR explicitly physical area is not scaled a second time", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data <- data.frame(cell_id = 1, area_um2 = 12.5)
  data[[paste0("centroid_", "col")]] <- 2
  data[[paste0("centroid_", "row")]] <- 3
  data.table::fwrite(data, path)
  x <- cs_read(path, format = "segmantr", pixel_size = 0.5, quiet = TRUE)
  expect_identical(x$cells$area, 12.5)
  expect_identical(x$provenance$parameters$coordinate_conversion$area_scale, 1)
})

test_that("inForm position headers and detection are supported", {
  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(
    `Cell ID` = c("a", "b"), `Cell X Position` = c(1, 2),
    `Cell Y Position` = c(3, 4), `DAPI Mean` = c(5, 6),
    check.names = FALSE, stringsAsFactors = FALSE
  ), path, sep = "\t", quote = FALSE)
  candidates <- cellspecR:::cs_detect_format(path)
  expect_true("inform" %in% candidates$format)
  x <- cellspecR:::cs_read(path, format = "inform")
  expect_identical(x$cells$x, c(1, 2))
  expect_identical(x$cells$y, c(3, 4))
  expect_identical(colnames(x$measurements), "cell:DAPI:mean")
})

test_that("pixel based other readers require calibration and IDs", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data <- data.frame(cell_id = "a")
  data[[paste0("centroid_", "row")]] <- 1
  data[[paste0("centroid_", "col")]] <- 2
  data.table::fwrite(data, path)
  expect_error(
    cellspecR:::cs_read(path, format = "mcquant"),
    class = "cellspec_error_units"
  )
  bad <- tempfile(fileext = ".csv")
  on.exit(unlink(bad), add = TRUE)
  data <- stats::setNames(
    data.frame(1, 2),
    c(paste0("centroid_", "row"), paste0("centroid_", "col"))
  )
  data.table::fwrite(data, bad)
  expect_error(
    cellspecR:::cs_read(bad, format = "segmantr", pixel_size = 1),
    class = "cellspec_error_format"
  )
})
