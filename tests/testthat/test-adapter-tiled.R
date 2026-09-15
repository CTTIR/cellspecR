tiled_table <- function(path, ids, x_um, x_px) {
  data.table::fwrite(
    data.frame(
      sample = rep("sample-1", length(ids)),
      cell_id = ids,
      centroid_x_px = x_px,
      centroid_y_px = rep(10, length(ids)),
      centroid_x_um = x_um,
      centroid_y_um = rep(5, length(ids)),
      `CD3e: Mean` = seq_along(ids),
      check.names = FALSE,
      stringsAsFactors = FALSE
    ),
    path,
    sep = "\t",
    quote = FALSE
  )
}

test_that("tiled QuPath directories detect and merge by centroid ownership", {
  dir <- tempfile("tiles-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  tiled_table(file.path(dir, "left.tsv"), c("a", "halo"), c(5, 15), c(10, 30))
  tiled_table(file.path(dir, "right.tsv"), "b", 15, 30)
  bounds <- data.frame(
    tile_id = c("left", "right"),
    xmin = c(0, 10), xmax = c(10, 20), ymin = c(0, 0), ymax = c(20, 20),
    stringsAsFactors = FALSE
  )

  expect_identical(cellspecR:::cs_detect_format(dir)$format, "qupath_tiled")
  x <- cellspecR:::cs_read(
    dir,
    format = "qupath_tiled",
    tile_bounds = bounds,
    image_id = "image-1"
  )
  expect_identical(x$cells$cell_id, c("a", "b"))
  expect_identical(x$cells$tile_id, c("left", "right"))
  expect_identical(x$cells$x, c(5, 15))
  expect_identical(x$measurements[, "cell:CD3e:mean"], c(1, 1))
  expect_identical(x$provenance$reader$adapter, "qupath_tiled")
})

test_that("tiled reader verifies malformed done metadata", {
  dir <- tempfile("tiles-done-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "left.tsv")
  tiled_table(file, "a", 5, 10)
  writeLines(c("key\tvalue", "csv_sha256\tbad"), file.path(dir, "left.done.tsv"))
  bounds <- data.frame(
    tile_id = "left", xmin = 0, xmax = 10, ymin = 0, ymax = 20,
    stringsAsFactors = FALSE
  )
  expect_error(
    cellspecR:::cs_read(dir, format = "qupath_tiled", tile_bounds = bounds),
    class = "cellspec_error_format"
  )
})

test_that("tiled reader rejects nested inputs and duplicate ownership", {
  dir <- tempfile("tiles-invalid-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  nested <- file.path(dir, "nested")
  dir.create(nested)
  expect_error(
    cellspecR:::cs_read(dir, format = "qupath_tiled"),
    class = "cellspec_error_format"
  )
  unlink(nested, recursive = TRUE)

  tiled_table(file.path(dir, "left.tsv"), "a", 7, 14)
  tiled_table(file.path(dir, "right.tsv"), "outside", 19, 38)
  overlapping <- data.frame(
    tile_id = c("left", "right"), xmin = c(0, 5), xmax = c(10, 15),
    ymin = c(0, 0), ymax = c(20, 20), stringsAsFactors = FALSE
  )
  expect_error(
    cellspecR:::cs_read(
      dir, format = "qupath_tiled", tile_bounds = overlapping,
      image_id = "image-1"
    ),
    class = "cellspec_error_collision"
  )
})

test_that("tiled metadata helpers parse names and validate scalar values", {
  expect_identical(cellspecR:::.cs_tiled_table_name("/tmp/a.tsv"), "a.tsv")
  expect_identical(cellspecR:::.cs_tiled_stem("a.tsv.gz"), "a")
  expect_true(cellspecR:::.cs_tiled_is_bounds_name("TILE_BOUNDS.tsv"))
  expect_false(cellspecR:::.cs_tiled_is_bounds_name("tile-a.tsv"))

  marker_path <- tempfile(fileext = ".done.tsv")
  on.exit(unlink(marker_path), add = TRUE)
  writeLines(c("key\tvalue", "tile_id\tleft", "data_rows\t2"), marker_path)
  marker <- cellspecR:::.cs_tiled_read_done(marker_path)
  expect_identical(cellspecR:::.cs_tiled_done_value(marker, "tile_id"), "left")
  expect_null(cellspecR:::.cs_tiled_done_value(marker, "sample_id"))
  expect_identical(cellspecR:::.cs_tiled_number("2", "n", integer = TRUE), 2L)
  expect_identical(cellspecR:::.cs_tiled_number("2.5", "n"), 2.5)
  expect_error(
    cellspecR:::.cs_tiled_done_value(marker, "sample_id", required = TRUE),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_number("-1", "n", min = 0),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_number("two", "n"),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_number("", "n"),
    class = "cellspec_error_format"
  )
})

test_that("done markers support headers, gzip and malformed input diagnostics", {
  empty <- tempfile(fileext = ".done.tsv")
  malformed <- tempfile(fileext = ".done.tsv")
  duplicate <- tempfile(fileext = ".done.tsv")
  on.exit(unlink(c(empty, malformed, duplicate)), add = TRUE)
  file.create(empty)
  writeLines("key\tvalue\na", malformed)
  writeLines(c("key\tvalue", "a\t1", "a\t2"), duplicate)
  expect_error(
    cellspecR:::.cs_tiled_read_done(empty),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_read_done(malformed),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_read_done(duplicate),
    class = "cellspec_error_format"
  )
  path <- tempfile(fileext = ".done.tsv.gz")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    data.frame(key = c("tile_id", "status"), value = c("left", "validated")),
    path, sep = "\t", quote = FALSE, compress = "gzip"
  )
  marker <- cellspecR:::.cs_tiled_read_done(path)
  expect_identical(cellspecR:::.cs_tiled_done_value(marker, "status"), "validated")
})

test_that("tiled bounds and calibration forms are supported", {
  um <- structure(
    as.list(c(xmin_um = "1", xmax_um = "3", ymin_um = "2", ymax_um = "4")),
    class = "cs_tiled_done"
  )
  plain <- structure(
    as.list(c(xmin = "1", xmax = "3", ymin = "2", ymax = "4")),
    class = "cs_tiled_done"
  )
  px <- structure(
    as.list(c(core_x0_px = "0", core_x1_px = "10", core_y0_px = "2", core_y1_px = "8")),
    class = "cs_tiled_done"
  )
  expect_identical(
    cellspecR:::.cs_tiled_done_bounds(um, "u")[, c("xmin", "xmax", "ymin", "ymax")],
    data.frame(xmin = 1, xmax = 3, ymin = 2, ymax = 4)
  )
  expect_identical(
    cellspecR:::.cs_tiled_done_bounds(plain, "p")[, c("xmin", "xmax", "ymin", "ymax")],
    stats::setNames(data.frame(xmin = 1, xmax = 3, ymin = 2, ymax = 4),
                    c("xmin", "xmax", "ymin", "ymax"))
  )
  expect_identical(
    cellspecR:::.cs_tiled_done_bounds(px, "x", pixel_size = 0.5)[, c("xmin", "xmax", "ymin", "ymax")],
    data.frame(xmin = 0, xmax = 5, ymin = 1, ymax = 4)
  )
  expect_null(cellspecR:::.cs_tiled_done_bounds(structure(list(), class = "cs_tiled_done"), "none"))
  expect_error(
    cellspecR:::.cs_tiled_done_bounds(px, "x"),
    class = "cellspec_error_units"
  )
  expect_identical(
    cellspecR:::.cs_tiled_pixel_size(list(NULL, px), pixel_size = 0.5),
    0.5
  )
  expect_error(
    cellspecR:::.cs_tiled_pixel_size(list(px, structure(as.list(c(pixel_size = "1")), class = "cs_tiled_done")), pixel_size = 0.5),
    class = "cellspec_error_units"
  )
  expect_null(cellspecR:::.cs_tiled_pixel_size(list(NULL)))
})

test_that("tiled metadata and fallback reader retain supported measurements", {
  headers <- c(
    "Cell: Area", "Nucleus: Length µm", "Cell: Circularity",
    "Cell: Solidity", "Cell: Max diameter", "Cell: Min diameter",
    "Cell: CD3e: Mean", "Nucleus: FOXP3: Median", "Cell: Marker: Std.Dev."
  )
  metadata <- cellspecR:::.cs_tiled_metadata(headers)
  expect_true(all(c("area", "length", "circularity", "solidity", "max_diameter", "min_diameter", "mean", "median", "sd") %in% metadata$statistic))

  table <- data.frame(
    sample = "s", cell_id = "a", centroid_x_px = 2, centroid_y_px = 3,
    centroid_x_um = 1, centroid_y_um = 1.5, `Cell: CD3e: Mean` = 10,
    check.names = FALSE, stringsAsFactors = FALSE
  )
  file <- tempfile(fileext = ".tsv")
  on.exit(unlink(file), add = TRUE)
  data.table::fwrite(table, file, sep = "\t", quote = FALSE)
  result <- cellspecR:::.cs_tiled_fallback_read(
    file, table, image_id = "i", sample_id = "s", pixel_size = NULL,
    marker_map = NULL, keep_other = TRUE, keep_paths = FALSE, quiet = TRUE,
    call = rlang::caller_env()
  )
  expect_identical(result$cells$x_px, 2)
  expect_false(any(grepl("centroid_x_px", colnames(result$measurements))))
  expect_true("cell:CD3e:mean" %in% colnames(result$measurements))

  pixel <- table[c("sample", "cell_id", "centroid_x_px", "centroid_y_px", "Cell: CD3e: Mean")]
  result <- cellspecR:::.cs_tiled_fallback_read(
    file, pixel, image_id = "i", sample_id = "s", pixel_size = 0.5,
    marker_map = NULL, keep_other = TRUE, keep_paths = FALSE, quiet = TRUE,
    call = rlang::caller_env()
  )
  expect_identical(result$cells$x, 1)
  expect_error(
    cellspecR:::.cs_tiled_fallback_read(
      file, pixel, image_id = "i", sample_id = "s", pixel_size = NULL,
      marker_map = NULL, keep_other = TRUE, keep_paths = FALSE, quiet = TRUE,
      call = rlang::caller_env()
    ),
    class = "cellspec_error_units"
  )
})

test_that("tiled detection and done validation handle alternate layouts", {
  dir <- tempfile("tiles-layout-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  tiled_table(file.path(dir, "tile.tsv"), "a", 5, 10)
  expect_equal(cellspecR:::.cs_tiled_detect(dir)$score, 0.99)
  writeLines("a,b", file.path(dir, "notes.csv"))
  expect_true(length(cellspecR:::.cs_tiled_list_files(dir)) == 2L)
  unlink(file.path(dir, "tile.tsv"))
  writeLines("a,b", file.path(dir, "plain.csv"))
  expect_equal(cellspecR:::.cs_tiled_detect(dir)$score, 0)
  expect_error(
    cellspecR:::.cs_tiled_list_files(tempfile("missing-dir-")),
    class = "cellspec_error_format"
  )

  file <- file.path(dir, "valid.tsv")
  writeLines(c("cell_id\tcentroid_x_um\tcentroid_y_um", "a\t1\t2"), file)
  table <- cellspecR:::.cs_table_read(file)
  sha <- unname(cellspecR:::.cs_sha256_file(file))
  done <- structure(as.list(c(
    csv_sha256 = sha, data_rows = "1", columns = "3",
    bytes = as.character(file.info(file)$size), status = "validated"
  )), class = "cs_tiled_done")
  expect_invisible(cellspecR:::.cs_tiled_validate_done(done, file, table))
  expect_invisible(cellspecR:::.cs_tiled_validate_done(done, file, table, verify = FALSE))
  bad <- done
  bad$status <- "pending"
  expect_error(
    cellspecR:::.cs_tiled_validate_done(bad, file, table),
    class = "cellspec_error_format"
  )
})

test_that("tiled marker matching covers aliases and one-tile conventions", {
  dir <- tempfile("tiles-markers-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "tile.tsv")
  tiled_table(file, "a", 5, 10)
  marker <- file.path(dir, ".done.tsv")
  writeLines(c("key\tvalue", "tile_tag\ttile", "status\tvalidated"), marker)
  done <- cellspecR:::.cs_tiled_done_files(dir, file)
  expect_identical(cellspecR:::.cs_tiled_done_value(done[[1L]], "tile_tag"), "tile")
  expect_error(
    cellspecR:::.cs_tiled_done_value(
      structure(list(key = ""), class = "cs_tiled_done"), "key"
    ),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tiled_done_files(
      dir, c(file, file.path(dir, "second.tsv"))
    ),
    class = "cellspec_error"
  )

  header_only <- tempfile(fileext = ".done.tsv")
  on.exit(unlink(header_only), add = TRUE)
  writeLines("key\tvalue", header_only)
  expect_error(cellspecR:::.cs_tiled_read_done(header_only),
               class = "cellspec_error")
})

test_that("tiled validation catches digest, header, bounds and calibration failures", {
  dir <- tempfile("tiles-validation-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "tile.tsv")
  writeLines(c("cell_id\tcentroid_x_um\tcentroid_y_um", "a\t1\t2"), file)
  table <- cellspecR:::.cs_table_read(file)
  base <- structure(as.list(c(
    csv_sha256 = strrep("a", 64), data_rows = "1", columns = "3",
    bytes = as.character(file.info(file)$size)
  )), class = "cs_tiled_done")
  expect_error(
    cellspecR:::.cs_tiled_validate_done(base, file, table),
    class = "cellspec_error_format"
  )
  bad_sha <- base
  bad_sha$csv_sha256 <- "bad"
  expect_error(
    cellspecR:::.cs_tiled_validate_done(bad_sha, file, table, verify = FALSE),
    class = "cellspec_error_format"
  )
  good <- base
  good$csv_sha256 <- unname(cellspecR:::.cs_sha256_file(file))
  good$bytes <- as.character(file.info(file)$size + 1)
  expect_error(
    cellspecR:::.cs_tiled_validate_done(good, file, table),
    class = "cellspec_error_format"
  )
  good$bytes <- as.character(file.info(file)$size)
  good$header_sha256 <- strrep("b", 64)
  expect_error(
    cellspecR:::.cs_tiled_validate_done(good, file, table),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_check_directory(file),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tiled_pixel_size(list(NULL), pixel_size = 0),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tiled_id(file.path(dir, ".tsv")),
    class = "cellspec_error"
  )
})

test_that("tiled bounds files and read validation branches are exercised", {
  dir <- tempfile("tiles-bounds-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "tile.tsv")
  tiled_table(file, "a", 5, 10)
  bounds_file <- file.path(dir, "bounds.tsv")
  data.table::fwrite(
    data.frame(tile_id = "tile", xmin = 0, xmax = 10, ymin = 0, ymax = 20),
    bounds_file, sep = "\t", quote = FALSE
  )
  expect_identical(
    basename(cellspecR:::.cs_tiled_bounds_file(dir)),
    basename(bounds_file)
  )
  expect_equal(
    nrow(cellspecR:::.cs_tiled_bounds(dir, file, list(NULL), NULL)),
    1L
  )
  unlink(bounds_file)
  expect_error(
    cellspecR:::.cs_tiled_bounds(
      dir, file, list(NULL), NULL, pixel_size = NULL
    ),
    class = "cellspec_error_format"
  )
  expect_error(
    cellspecR:::.cs_tiled_read(
      dir, tile_bounds = data.frame(tile_id = "wrong", xmin = 0, xmax = 1, ymin = 0, ymax = 1),
      pixel_size = 1
    ),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tiled_read(
      dir, tile_bounds = data.frame(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
      pixel_size = 1
    ),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tiled_read(dir, tile_bounds = data.frame(
      tile_id = "tile", xmin = 0, xmax = 1, ymin = 0, ymax = 1
    ), marker_map = list()),
    class = "cellspec_error"
  )
})
