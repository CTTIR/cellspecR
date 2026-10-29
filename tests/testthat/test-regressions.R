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

test_that("overview_optional_panels: the default plot skips panels without data", {
  # plot(x) aborted when the cells table had no area column.
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("patchwork")
  no_area <- min_object()
  no_area$cells$area <- NULL
  expect_s3_class(plot(no_area), "patchwork")
  no_intensity <- min_object()[, "cell:area"]
  expect_false(any(cs_dictionary(no_intensity)$kind == "intensity"))
  expect_s3_class(plot(no_intensity), "patchwork")
})

test_that("anndata_default_policy: cs_as_anndata derives a policy like cs_as_spe", {
  # cs_as_anndata() had no default policy and failed with a missing argument.
  expect_null(formals(cs_as_anndata)$policy)
  skip_if_not_installed("anndataR")
  result <- tryCatch(cs_as_anndata(min_object()), error = identity)
  if (inherits(result, "error")) {
    expect_s3_class(result, "cellspec_error")
  } else {
    expect_true(inherits(result, "AbstractAnnData") || inherits(result, "AnnData"))
  }
})

test_that("other_id_collision: unmapped columns with clashing clean names are kept", {
  # "a b" and "a_b" both became other:a_b and aborted the read.
  path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = c("c1", "c2"), x = 1:2, y = 3:4, `a b` = c(1, 2),
               a_b = c(3, 4), check.names = FALSE),
    path, row.names = FALSE
  )
  x <- cs_read(path, format = "table", keep_other = TRUE,
               column_map = cs_column_map("id", "x", "y"))
  expect_identical(colnames(x$measurements), c("other:a_b", "other:a_b_1"))
  expect_identical(x$dictionary$source_name, c("a b", "a_b"))
  expect_identical(unname(x$measurements[, "other:a_b_1"]), c(3, 4))

  # The documented rule: make.unique() skips suffixes already taken, and
  # mapped `other` measurements are numbered too, also without keep_other.
  utils::write.csv(
    data.frame(id = c("c1", "c2"), x = 1:2, y = 3:4, `a b` = c(1, 2),
               a_b = c(3, 4), a_b_1 = c(5, 6), check.names = FALSE),
    path, row.names = FALSE
  )
  x <- cs_read(path, format = "table",
               column_map = cs_column_map("id", "x", "y"))
  expect_identical(colnames(x$measurements),
                   c("other:a_b", "other:a_b_2", "other:a_b_1"))
  expect_identical(unname(x$measurements[, "other:a_b_2"]), c(3, 4))
  mapped <- data.frame(
    source_name = c("a_b", "a b"), kind = "other", marker = NA,
    compartment = NA, statistic = "value", unit = "a.u."
  )
  x <- cs_read(path, format = "table", keep_other = FALSE, quiet = TRUE,
               column_map = cs_column_map("id", "x", "y",
                                          measurements = mapped))
  expect_identical(colnames(x$measurements), c("other:a_b", "other:a_b_1"))
  expect_identical(unname(x$measurements[, "other:a_b_1"]), c(1, 2))
})

test_that("summary_no_images: summary and print handle objects without images", {
  # summary() of a valid zero-image object failed in print().
  p <- min_parts()
  empty <- cs_new(p$cells[0, ], NULL, NULL, p$images[0, ], NULL)
  s <- summary(empty)
  expect_s3_class(s, "cellspec_summary")
  expect_identical(nrow(s), 0L)
  expect_identical(
    names(s),
    c("image_id", "sample_id", "n_cells", "n_markers", "n_features",
      "pixel_size", "x_min", "x_max", "y_min", "y_max", "na_fraction")
  )
  expect_type(s$x_min, "double")
  expect_type(s$n_cells, "integer")
  expect_output(print(s), "0 images, 0 cells")
  expect_output(print(empty), "<cellspec>")
})

test_that("sidecar_missing_rows: a sidecar without n_rows raises a format error", {
  # A missing n_rows failed with an unclassed "missing value" error.
  rewrite <- function(path, edit) {
    sidecar <- file.path(path, "cellspec.json")
    doc <- jsonlite::fromJSON(sidecar, simplifyVector = FALSE)
    writeLines(jsonlite::toJSON(edit(doc), auto_unbox = TRUE, null = "null",
                                digits = NA, pretty = TRUE), sidecar)
  }
  path <- withr::local_tempfile(pattern = "cellspec-")
  cs_write(sim_object(), path)
  rewrite(path, function(doc) {
    doc$cells$n_rows <- NULL
    doc
  })
  expect_error(cs_read_cellspec(path, verify = FALSE),
               class = "cellspec_error_format")

  cs_write(sim_object(), path, overwrite = TRUE)
  rewrite(path, function(doc) {
    doc$adjacency$n_rows <- NULL
    doc
  })
  expect_error(cs_read_cellspec(path, verify = FALSE),
               class = "cellspec_error_format")
})

test_that("write_rng_state: cs_write leaves the random number stream alone", {
  # Staging and backup names were drawn with sample().
  path <- withr::local_tempfile(pattern = "cellspec-")
  withr::local_seed(20261029)
  before <- get(".Random.seed", envir = globalenv())
  cs_write(min_object(), path)
  cs_write(min_object(), path, overwrite = TRUE)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("gzip_in_r: compressed tables are read without an external gzip", {
  # Compressed tables were piped through the system gzip program.
  skip_on_os("windows")
  bin <- withr::local_tempdir(pattern = "fake-bin-")
  writeLines(c("#!/bin/sh", "exit 1"), file.path(bin, "gzip"))
  Sys.chmod(file.path(bin, "gzip"), "0755")
  withr::local_envvar(
    PATH = paste(bin, Sys.getenv("PATH"), sep = .Platform$path.sep)
  )

  table_path <- withr::local_tempfile(fileext = ".tsv.gz")
  data.table::fwrite(
    data.frame(id = c("a", "b"), x = c(1, 2), y = c(3, 4), value = c(1.5, 2.5)),
    table_path, sep = "\t", compress = "gzip"
  )
  x <- cs_read(table_path, format = "table",
               column_map = cs_column_map("id", "x", "y"))
  expect_identical(x$cells$cell_id, c("a", "b"))
  expect_identical(unname(x$measurements[, 1]), c(1.5, 2.5))

  path <- withr::local_tempfile(pattern = "cellspec-")
  cs_write(sim_object(), path, format = "tsv.gz")
  y <- cs_read_cellspec(path)
  expect_identical(y$cells, sim_object()$cells)
  expect_identical(y$measurements, sim_object()$measurements)
  expect_identical(y$adjacency, sim_object()$adjacency)
  expect_length(list.files(tempdir(), pattern = "^cellspec-gunzip-"), 0L)
})

test_that("gzip_truncated: a cut gzip table is an error, not a short table", {
  # gzfile() stops without a warning where a truncated stream ends, so half
  # a file loaded as half of the rows.
  n <- 4000L
  path <- withr::local_tempfile(fileext = ".tsv.gz")
  data.table::fwrite(
    data.frame(id = sprintf("c%05d", seq_len(n)), x = seq_len(n) / 7,
               y = seq_len(n) / 3, value = sqrt(seq_len(n))),
    path, sep = "\t", compress = "gzip"
  )
  map <- cs_column_map("id", "x", "y")
  expect_no_warning(x <- cs_read(path, format = "table", column_map = map))
  expect_identical(nrow(x$cells), n)

  bytes <- readBin(path, "raw", file.size(path))
  cut <- withr::local_tempfile(fileext = ".tsv.gz")
  for (keep in c(0.5, 0.99)) {
    writeBin(bytes[seq_len(floor(length(bytes) * keep))], cut)
    expect_error(cs_read(cut, format = "table", column_map = map),
                 "truncated", class = "cellspec_error_format")
  }
  # The trailer's length field is not checked by gzfile().
  bad_length <- bytes
  bad_length[[length(bytes)]] <- as.raw(255L)
  writeBin(bad_length, cut)
  expect_error(cs_read(cut, format = "table", column_map = map),
               "truncated", class = "cellspec_error_format")

  # A tail zero-filled back to the original size looked like the trailer of
  # an empty last member and loaded part of the rows with a warning.
  zero_fill <- function(bytes, keep) {
    c(bytes[seq_len(keep)], raw(length(bytes) - keep))
  }
  for (keep in c(0.3, 0.9)) {
    writeBin(zero_fill(bytes, floor(length(bytes) * keep)), cut)
    expect_error(cs_read(cut, format = "table", column_map = map),
                 "truncated", class = "cellspec_error_format")
  }
  parts <- gzip_table_parts()
  first <- bgzf_block(parts$first)
  bgzf <- c(first, bgzf_block(parts$second), bgzf_eof())
  writeBin(zero_fill(bgzf, length(first)), cut)
  expect_error(cs_read(cut, format = "table", column_map = map),
               "truncated", class = "cellspec_error_format")
  # A real empty last member still ends in zeros.
  empty <- gzip_member(raw())
  writeBin(c(gzip_member(c(parts$first, parts$second)), empty), cut)
  expect_warning(x <- cs_read(cut, format = "table", column_map = map),
                 class = "cellspec_warning_integrity")
  expect_identical(x$cells$cell_id, sprintf("c%03d", 1:60))

  dir <- withr::local_tempfile(pattern = "cellspec-")
  cs_write(sim_object(), dir, format = "tsv.gz")
  cells <- file.path(dir, "cells.tsv.gz")
  bytes <- readBin(cells, "raw", file.size(cells))
  writeBin(bytes[seq_len(floor(length(bytes) * 0.6))], cells)
  expect_error(cs_read_cellspec(dir, verify = FALSE),
               "truncated", class = "cellspec_error_format")
  writeBin(zero_fill(bytes, floor(length(bytes) * 0.6)), cells)
  expect_error(cs_read_cellspec(dir, verify = FALSE),
               "truncated", class = "cellspec_error_format")
  expect_length(list.files(tempdir(), pattern = "^cellspec-gunzip-"), 0L)
})

test_that("gzip_members: BGZF and concatenated gzip members are checked", {
  # Only a single-member stream can be checked against one trailer; BGZF
  # blocks are checked one by one, other members with a warning.
  parts <- gzip_table_parts()
  map <- cs_column_map("id", "x", "y")
  path <- withr::local_tempfile(fileext = ".tsv.gz")
  read <- function() cs_read(path, format = "table", column_map = map)

  bgzf <- c(bgzf_block(parts$first), bgzf_block(parts$second), bgzf_eof())
  writeBin(bgzf, path)
  expect_no_warning(x <- read())
  expect_identical(x$cells$cell_id, sprintf("c%03d", 1:60))
  expect_identical(unname(x$measurements[, "other:value"]), (1:60) / 2)
  writeBin(bgzf[seq_len(length(bgzf) - length(bgzf_eof()))], path)
  expect_error(read(), "end-of-file", class = "cellspec_error_format")
  writeBin(bgzf[seq_len(length(bgzf) - 40L)], path)
  expect_error(read(), "truncated", class = "cellspec_error_format")
  # Other data after BGZF blocks fell back to the check of the last trailer.
  writeBin(c(bgzf_block(parts$first), gzip_member(parts$second)), path)
  expect_error(read(), "not one", class = "cellspec_error_format")

  members <- c(gzip_member(parts$first), gzip_member(parts$second))
  writeBin(members, path)
  expect_warning(x <- read(), class = "cellspec_warning_integrity")
  expect_identical(x$cells$cell_id, sprintf("c%03d", 1:60))
  expect_identical(unname(x$measurements[, "other:value"]), (1:60) / 2)
  writeBin(members[seq_len(length(members) - 12L)], path)
  expect_error(read(), "truncated", class = "cellspec_error_format")

  # A tail beyond digest()'s integer offset is hashed from a copy.
  file <- withr::local_tempfile()
  writeBin(as.raw(rep_len(0:255, 5000L)), file)
  expect_identical(
    cellspecR:::.cs_crc32_tail(file, 5000, 1200, max_skip = 0),
    cellspecR:::.cs_crc32_tail(file, 5000, 1200)
  )
})

test_that("overwrite_foreign_files: only pure cs_write output is replaced", {
  # A MANIFEST.sha256 or cellspec.json was enough for overwrite = TRUE to
  # delete a folder, including files cs_write() never writes.
  path <- withr::local_tempfile(pattern = "release-")
  dir.create(path)
  writeLines("abc  notes.txt", file.path(path, "MANIFEST.sha256"))
  writeLines("precious", file.path(path, "notes.txt"))
  expect_error(cs_write(min_object(), path, overwrite = TRUE),
               "notes.txt", class = "cellspec_error_format")
  expect_identical(readLines(file.path(path, "notes.txt")), "precious")
  expect_setequal(list.files(path, all.files = TRUE, no.. = TRUE),
                  c("MANIFEST.sha256", "notes.txt"))

  out <- withr::local_tempfile(pattern = "cellspec-")
  cs_write(min_object(), out, format = "tsv.gz")
  writeLines("my notes", file.path(out, "analysis-notes.txt"))
  expect_error(cs_write(min_object(), out, overwrite = TRUE),
               "analysis-notes.txt", class = "cellspec_error_format")
  expect_true(file.exists(file.path(out, "analysis-notes.txt")))
  expect_true(file.exists(file.path(out, "cells.tsv.gz")))
  unlink(file.path(out, "analysis-notes.txt"))
  cs_write(min_object(), out, overwrite = TRUE)
  expect_true(all(cs_verify(out)$ok))
  expect_false(file.exists(file.path(out, "cells.tsv.gz")))

  writeLines('{"format": "other"}', file.path(out, "cellspec.json"))
  expect_error(cs_write(min_object(), out, overwrite = TRUE),
               "cellspec.json", class = "cellspec_error_format")
  expect_true(file.exists(file.path(out, "cells.parquet")))
})

test_that("tile_gz_header: header_sha256 of a gzip tile covers its text", {
  # The header digest was taken over the compressed bytes of a .tsv.gz tile.
  dir <- withr::local_tempdir(pattern = "tiles-gz-header-")
  tile <- data.frame(cell_id = "c1", centroid_x_um = 5, centroid_y_um = 5,
                     `Cell: CD3: Mean` = 1, check.names = FALSE)
  file <- file.path(dir, "tileA.tsv.gz")
  data.table::fwrite(tile, file, sep = "\t", compress = "gzip")
  con <- gzfile(file, open = "rb")
  text <- readBin(con, "raw", 4096L)
  close(con)
  header <- text[seq_len(match(as.raw(10L), text))]
  write_done <- function(header_sha256) {
    done <- data.frame(
      key = c("csv_sha256", "data_rows", "columns", "bytes", "header_sha256",
              "xmin_um", "xmax_um", "ymin_um", "ymax_um"),
      value = c(digest::digest(file = file, algo = "sha256"), "1", "4",
                as.character(file.size(file)), header_sha256,
                "0", "100", "0", "100")
    )
    utils::write.table(done, file.path(dir, "tileA.done.tsv"), sep = "\t",
                       quote = FALSE, row.names = FALSE)
  }
  write_done(digest::digest(header, algo = "sha256", serialize = FALSE))
  x <- cs_read(dir, format = "qupath_tiled", image_id = "image-1")
  expect_identical(x$cells$cell_id, "c1")

  write_done(digest::digest(rev(header), algo = "sha256", serialize = FALSE))
  expect_error(cs_read(dir, format = "qupath_tiled", image_id = "image-1"),
               "header_sha256", class = "cellspec_error_format")
})
