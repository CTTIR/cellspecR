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
