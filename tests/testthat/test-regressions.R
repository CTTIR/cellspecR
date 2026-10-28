# Regression tests are named after the bug they prevent (05_TESTING.md).

test_that("constant_channel_support: an all-zero marker is flagged", {
  # A blank channel must be visible before any correction.
  x <- cs_example()
  x$measurements[, cs_features(x, marker = "FOXP3", statistic = "mean")] <- 0
  s <- cs_feature_support(x)
  expect_true(all(s$support[s$marker == "FOXP3"] == "constant"))
  r <- cs_validate(x, level = "semantic")
  expect_identical(r$status[r$check == "feature_support"], "warn")
  expect_match(r$message[r$check == "feature_support"], "FOXP3")
})

test_that("subset_alignment: subsetting never misaligns measurements or adjacency", {
  # phenoscapR's `[` left @spatial stale after subsetting rows.
  x <- sim_object()
  h <- row_hashes(x)
  withr::local_seed(3)
  for (k in 1:25) {
    i <- sort(sample(nrow(x), sample(nrow(x), 1)))
    y <- x[sample(i), ]
    expect_identical(sort(row_hashes(y)), sort(h[i]))
    adj <- cs_adjacency(y)
    keys <- paste(cs_cells(y)$image_id, cs_cells(y)$cell_id)
    expect_true(all(paste(adj$image_id, adj$cell_id_a) %in% keys))
    expect_true(all(paste(adj$image_id, adj$cell_id_b) %in% keys))
  }
})

test_that("overwrite_foreign_directory: cs_write never replaces unrelated folders", {
  # overwrite = TRUE used to replace any directory, deleting its files.
  path <- withr::local_tempfile(pattern = "user-folder-")
  dir.create(path)
  writeLines("precious", file.path(path, "notes.txt"))
  expect_error(
    cs_write(min_object(), path, overwrite = TRUE),
    class = "cellspec_error_format"
  )
  expect_identical(list.files(path, all.files = TRUE, no.. = TRUE), "notes.txt")
  expect_identical(readLines(file.path(path, "notes.txt")), "precious")
  expect_length(list.files(dirname(path),
                           pattern = paste0("^", basename(path), "\\.partial-")), 0L)

  empty <- withr::local_tempfile(pattern = "empty-folder-")
  dir.create(empty)
  cs_write(min_object(), empty, overwrite = TRUE)
  expect_true(all(cs_verify(empty)$ok))
  cs_write(min_object(), empty, overwrite = TRUE)
  expect_true(all(cs_verify(empty)$ok))
})

test_that("tile_long_header: header_sha256 covers headers longer than 1 KiB", {
  # Only the first 1024 bytes were searched for the end of the header line.
  dir <- withr::local_tempdir(pattern = "tiles-long-header-")
  markers <- sprintf("LongMarkerName%03d", 1:80)
  tile <- data.frame(
    cell_id = "c1", centroid_x_um = 5, centroid_y_um = 5,
    matrix(1, nrow = 1L, ncol = length(markers),
           dimnames = list(NULL, paste0("Cell: ", markers, ": Mean"))),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  file <- file.path(dir, "tileA.tsv")
  data.table::fwrite(tile, file, sep = "\t")
  bytes <- readBin(file, "raw", file.size(file))
  header_end <- match(as.raw(10L), bytes)
  expect_gt(header_end, 1024L)
  done <- data.frame(
    key = c("csv_sha256", "data_rows", "columns", "bytes", "header_sha256",
            "xmin_um", "xmax_um", "ymin_um", "ymax_um"),
    value = c(
      digest::digest(file = file, algo = "sha256"), "1",
      as.character(ncol(tile)), as.character(file.size(file)),
      digest::digest(bytes[seq_len(header_end)], algo = "sha256",
                     serialize = FALSE),
      "0", "100", "0", "100"
    )
  )
  utils::write.table(done, file.path(dir, "tileA.done.tsv"), sep = "\t",
                     quote = FALSE, row.names = FALSE)
  x <- cs_read(dir, format = "qupath_tiled", image_id = "image-1")
  expect_identical(x$cells$cell_id, "c1")
  expect_identical(ncol(x$measurements), length(markers))
})

test_that("app_upload_limit: cs_app applies max_upload_mb while it runs", {
  # max_upload_mb was validated but Shiny kept its 5 MB upload default.
  skip_if_not_installed("shiny")
  withr::local_options(shiny.maxRequestSize = NULL)
  restore <- cellspecR:::.cs_app_upload_limit(3)
  expect_identical(getOption("shiny.maxRequestSize"), 3 * 1024^2)
  restore()
  expect_null(getOption("shiny.maxRequestSize"))

  app <- cs_app(max_upload_mb = 3)
  cancel_restore <- app$onStart()
  on.exit(cancel_restore(), add = TRUE)
  expect_identical(getOption("shiny.maxRequestSize"), 3 * 1024^2)
})
