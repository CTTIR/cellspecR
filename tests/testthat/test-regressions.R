# Regression tests are named after the bug they prevent (05_TESTING.md).

test_that("constant_channel_support: an all-zero marker is flagged", {
  # A blank channel must be visible before any correction (LCNEC audit F1).
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
