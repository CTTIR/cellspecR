test_that("SpatialExperiment conversion preserves cellspec components", {
  skip_if_not_installed("SpatialExperiment")
  skip_if_not_installed("SingleCellExperiment")
  skip_if_not_installed("S4Vectors")
  x <- cs_example()
  policy <- cs_signal_policy(cs_markers(x))
  spe <- cs_as_spe(x, policy)
  expect_s4_class(spe, "SpatialExperiment")
  expect_identical(dim(spe), c(4L, 80L))
  expect_true("measurements" %in% SingleCellExperiment::altExpNames(spe))
  y <- cs_from_spe(spe)
  expect_identical(y$cells, x$cells)
  expect_identical(y$measurements, x$measurements)
  expect_identical(y$dictionary, x$dictionary)
  expect_identical(y$images, x$images)
  expect_identical(y$channels, x$channels)
})

test_that("SpatialExperiment conversion requires cellspec metadata", {
  skip_if_not_installed("SpatialExperiment")
  skip_if_not_installed("S4Vectors")
  empty <- SpatialExperiment::SpatialExperiment()
  expect_error(cs_from_spe(empty), class = "cellspec_error_format")
})

test_that("AnnData conversion is guarded by anndataR", {
  skip_if_not_installed("anndataR")
  x <- cs_example()
  policy <- cs_signal_policy(cs_markers(x))
  result <- cs_as_anndata(x, policy)
  expect_true(inherits(result, "AbstractAnnData") || inherits(result, "AnnData"))
  expect_identical(dim(result), c(80L, 4L))
  expect_equal(unname(result$X), unname(cs_signal_matrix(x, policy)$signal))
})

test_that("interop defaults and failure contracts are explicit", {
  expect_error(
    cellspecR:::.cs_interop_require("package-that-is-not-installed"),
    class = "cellspec_error"
  )
  expect_error(
    cs_as_spe(min_object(), assay_name = ""),
    class = "cellspec_error"
  )
  expect_error(
    cs_from_spe(list()),
    class = "cellspec_error"
  )

  empty_parts <- min_parts()
  empty_parts$measurements <- matrix(numeric(), nrow = nrow(empty_parts$cells), ncol = 0L)
  empty_parts$dictionary <- empty_parts$dictionary[FALSE, , drop = FALSE]
  empty_parts$channels <- empty_parts$channels[FALSE, , drop = FALSE]
  empty_object <- cs_new(
    empty_parts$cells, empty_parts$measurements, empty_parts$dictionary,
    empty_parts$images, empty_parts$channels
  )
  expect_error(
    cellspecR:::.cs_policy_default(empty_object, NULL, rlang::caller_env()),
    class = "cellspec_error"
  )
})

test_that("SpatialExperiment conversion derives a single-source default policy", {
  skip_if_not_installed("SpatialExperiment")
  skip_if_not_installed("SingleCellExperiment")
  skip_if_not_installed("S4Vectors")
  single_source <- min_object()
  expect_s4_class(cs_as_spe(single_source), "SpatialExperiment")
  multiple_source <- cs_example()
  expect_error(
    cs_as_spe(multiple_source),
    class = "cellspec_error"
  )
})

test_that("SpatialExperiment round trips keep non-syntactic cells columns", {
  skip_if_not_installed("SpatialExperiment")
  skip_if_not_installed("SingleCellExperiment")
  skip_if_not_installed("S4Vectors")
  path <- system.file("extdata", "qupath-0.7.0-instanseg.tsv", package = "cellspecR")
  x <- cs_read(path, format = "qupath")
  expect_true("Cell Type" %in% names(x$cells))
  policy <- cs_signal_policy(cs_markers(x))
  spe <- cs_as_spe(x, policy)
  expect_true("Cell Type" %in% names(SummarizedExperiment::colData(spe)))
  y <- cs_from_spe(spe)
  for (component in names(x)) {
    expect_identical(y[[component]], x[[component]], info = component)
  }

  # Objects written before the names were kept carry syntactic names.
  legacy <- spe
  coldata <- SummarizedExperiment::colData(legacy)
  names(coldata)[names(coldata) == "Cell Type"] <- "Cell.Type"
  SummarizedExperiment::colData(legacy) <- coldata
  expect_identical(cs_from_spe(legacy)$cells, x$cells)

  # A column that is really gone is a classed error, not a subsetting error.
  broken <- spe
  SummarizedExperiment::colData(broken)[["Cell Type"]] <- NULL
  expect_error(cs_from_spe(broken), class = "cellspec_error_format")
})

test_that("objects without cells convert to SpatialExperiment and AnnData", {
  x <- sim_object()[0, ]
  policy <- cs_signal_policy(cs_markers(x))
  if (requireNamespace("SpatialExperiment", quietly = TRUE) &&
        requireNamespace("SingleCellExperiment", quietly = TRUE)) {
    expect_no_warning(spe <- cs_as_spe(x, policy))
    expect_identical(dim(spe), c(3L, 0L))
    y <- cs_from_spe(spe)
    for (component in names(x)) {
      expect_identical(y[[component]], x[[component]], info = component)
    }
  }
  skip_if_not_installed("anndataR")
  expect_identical(dim(cs_as_anndata(x, policy)), c(0L, 3L))
})
