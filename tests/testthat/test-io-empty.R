test_that("empty TSV cell and adjacency tables are valid gzip streams", {
  x <- cs_example()
  x$cells$integer_extra <- rep(NA_integer_, nrow(x$cells))
  x$cells$character_extra <- rep(NA_character_, nrow(x$cells))
  x$cells <- x$cells[FALSE, , drop = FALSE]
  x$measurements <- x$measurements[FALSE, , drop = FALSE]
  x$adjacency <- data.frame(
    image_id = character(), cell_id_a = character(), cell_id_b = character(),
    shared_boundary = double(), method = character()
  )
  path <- file.path(withr::local_tempdir(), "empty table")
  cs_write(x, path, format = "tsv.gz")
  expect_true(all(cs_verify(path)$ok))
  y <- cs_read_cellspec(path)
  expect_identical(y$cells, x$cells)
  expect_identical(y$measurements, x$measurements)
  expect_identical(y$adjacency, x$adjacency)
})
