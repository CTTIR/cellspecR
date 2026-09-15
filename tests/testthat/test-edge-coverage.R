test_that("condition and input helpers cover their public failure contracts", {
  expect_identical(cellspecR:::.cs_examples(c("a", "b")), "\"a\", \"b\"")
  expect_identical(cellspecR:::.cs_examples(letters[1:7], n = 3L, quote = FALSE),
                   "a, b, c and 4 more")
  expect_invisible(cellspecR:::.cs_inform("quiet", quiet = TRUE))
  expect_message(cellspecR:::.cs_inform("visible", quiet = FALSE))
  expect_warning(cellspecR:::.cs_warn("a warning"))

  expect_invisible(cellspecR:::.cs_check_string(NULL, allow_null = TRUE))
  expect_invisible(cellspecR:::.cs_check_number(NULL, allow_null = TRUE))
  expect_invisible(cellspecR:::.cs_check_data_frame(NULL, allow_null = TRUE))
  expect_error(cellspecR:::.cs_check_string(character()), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_flag(NA), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_number(Inf), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_count(1.5), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_choice("x", "y"), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_data_frame(list()), class = "cellspec_error")
  expect_error(cellspecR:::.cs_check_cellspec(list()), class = "cellspec_error")
  expect_false(cellspecR:::.cs_safe_relative_path(NULL))
  expect_false(cellspecR:::.cs_safe_relative_path("/absolute"))
  expect_false(cellspecR:::.cs_safe_relative_path("../parent"))
  expect_true(cellspecR:::.cs_safe_relative_path("nested/file.tsv"))
})

test_that("table mapping and metadata validation reject unsafe descriptions", {
  valid <- data.frame(
    source_name = "CD3e Mean", kind = "intensity", marker = "CD3e",
    compartment = "cell", statistic = "mean", unit = "a.u.",
    stringsAsFactors = FALSE
  )
  expect_null(cellspecR:::.cs_table_mapping(NULL, "x", allow_null = TRUE))
  expect_error(cellspecR:::.cs_table_mapping("", "x"), class = "cellspec_error")
  expect_identical(cellspecR:::.cs_table_feature_id(valid),
                   "cell:CD3e:mean")
  other <- valid
  other$kind <- "other"
  other$marker <- NA_character_
  other$compartment <- NA_character_
  other$statistic <- "score"
  other$source_name <- "Score (%)"
  expect_identical(cellspecR:::.cs_table_feature_id(other), "other:score")
  expect_error(
    cellspecR:::.cs_table_feature_id(rbind(other, other)),
    class = "cellspec_error"
  )

  factor_meta <- valid
  factor_meta$source_name <- factor(factor_meta$source_name)
  expect_silent(cellspecR:::.cs_check_measurements(factor_meta))
  logical_meta <- valid
  logical_meta$marker <- NA
  logical_meta$kind <- "other"
  logical_meta$compartment <- NA
  expect_silent(cellspecR:::.cs_check_measurements(logical_meta))

  expect_error(
    cellspecR:::.cs_check_measurements(list()),
    class = "cellspec_error"
  )
  missing <- valid[, -6, drop = FALSE]
  expect_error(
    cellspecR:::.cs_check_measurements(missing),
    class = "cellspec_error"
  )
  duplicate <- valid
  names(duplicate)[[2L]] <- names(duplicate)[[1L]]
  expect_error(
    cellspecR:::.cs_check_measurements(duplicate),
    class = "cellspec_error"
  )
  cases <- list(
    source_name = within(valid, source_name <- ""),
    kind = within(valid, kind <- "unknown"),
    marker = within(valid, marker <- " CD3e"),
    compartment = within(valid, compartment <- "unknown"),
    statistic = within(valid, statistic <- "area"),
    unit = within(valid, unit <- "unknown")
  )
  for (case in cases) {
    expect_error(
      cellspecR:::.cs_check_measurements(case),
      class = "cellspec_error"
    )
  }
})

test_that("table readers handle numeric conversion, extras and explicit mappings", {
  expect_identical(cellspecR:::.cs_table_numeric(c(1L, 2L), "x"), c(1, 2))
  expect_identical(cellspecR:::.cs_table_numeric(c(NA, NA), "x"), c(NA_real_, NA_real_))
  expect_identical(cellspecR:::.cs_table_numeric(c("1", NA, ""), "x"),
                   c(1, NA_real_, NA_real_))
  expect_error(
    cellspecR:::.cs_table_numeric(c("1", "bad"), "x"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_table_numeric(list(1), "x"),
    class = "cellspec_error"
  )
  expect_identical(cellspecR:::.cs_table_character(factor("a"), "id"), "a")
  expect_error(
    cellspecR:::.cs_table_character(list("a"), "id"),
    class = "cellspec_error"
  )
  expect_invisible(cellspecR:::.cs_table_require_ids(c("a", "b"), "id"))
  expect_error(
    cellspecR:::.cs_table_require_ids(c("a", ""), "id"),
    class = "cellspec_error"
  )
  expect_identical(cellspecR:::.cs_table_derived_image_id("export.tsv.gz"), "export")
  expect_equal(nrow(cellspecR:::.cs_table_metadata_other(character())), 0L)
  expect_identical(
    cellspecR:::.cs_table_metadata_other("score")$statistic,
    "score"
  )

  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(
    id = c("a", "b"), x = c(1, 2), y = c(3, 4),
    image = c("i1", "i2"), sample = c("s1", "s2"), area = c(2, 3),
    score = c(0.1, 0.2), label = c("A", "B"),
    check.names = FALSE, stringsAsFactors = FALSE
  ), path)
  map <- cellspecR::cs_column_map(
    "id", "x", "y", image_id = "image", sample_id = "sample",
    area = "area"
  )
  x <- cellspecR::cs_read(path, format = "table", column_map = map)
  expect_identical(x$cells$image_id, c("i1", "i2"))
  expect_identical(x$cells$sample_id, c("s1", "s2"))
  expect_identical(x$cells$area, c(2, 3))
  expect_true("label" %in% names(x$cells))
  x <- NULL
  expect_warning(
    x <- cellspecR::cs_read(path, format = "table", column_map = map,
                            keep_other = FALSE),
    class = "cellspec_warning"
  )
  expect_s3_class(x, "cellspec")

  expect_error(
    cellspecR::cs_read(path, format = "unknown", column_map = map),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR::cs_read(path, format = "table"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR::cs_read(path, format = "table",
                       column_map = structure(list(), class = "cs_column_map")),
    class = "cellspec_error"
  )
})

test_that("table reader rejects missing and invalid mapped values", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = "bad", y = 2), path)
  expect_error(
    cellspecR::cs_read(path, format = "table",
                       column_map = cellspecR::cs_column_map("id", "x", "y")),
    class = "cellspec_error"
  )

  missing <- tempfile(fileext = ".csv")
  on.exit(unlink(missing), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1, y = 2), missing)
  map <- cellspecR::cs_column_map("id", "missing", "y")
  expect_error(
    cellspecR::cs_read(missing, format = "table", column_map = map),
    class = "cellspec_error"
  )

  area <- tempfile(fileext = ".csv")
  on.exit(unlink(area), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1, y = 2, area = -1), area)
  expect_error(
    cellspecR::cs_read(
      area, format = "table",
      column_map = cellspecR::cs_column_map("id", "x", "y", area = "area")
    ),
    class = "cellspec_error"
  )

  overflow <- tempfile(fileext = ".csv")
  on.exit(unlink(overflow), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1e308, y = 2, stringsAsFactors = FALSE), overflow)
  expect_error(
    cellspecR::cs_read(
      overflow, format = "table", pixel_size = 1e308,
      column_map = cellspecR::cs_column_map("id", "x", "y", coordinate_unit = "px")
    ),
    class = "cellspec_error_units"
  )
  expect_error(
    cellspecR::cs_read(path, format = "table", pixel_size = 0,
                       column_map = cellspecR::cs_column_map("id", "x", "y")),
    class = "cellspec_error_units"
  )
})

test_that("canonical JSON helpers preserve declared types and reject malformed data", {
  payload <- list(
    columns = list(
      list(name = "id", type = "character"),
      list(name = "n", type = "double"),
      list(name = "i", type = "integer"),
      list(name = "flag", type = "logical")
    ),
    rows = list(
      list(id = "a", n = 1.5, i = 2L, flag = TRUE),
      list(id = NULL, n = NULL, i = NULL, flag = NULL)
    )
  )
  table <- cellspecR:::.cs_json_table(payload, "example")
  expect_identical(names(table), c("id", "n", "i", "flag"))
  expect_identical(table$id, c("a", NA_character_))
  expect_identical(table$n, c(1.5, NA_real_))
  expect_identical(table$i, c(2L, NA_integer_))
  expect_identical(table$flag, c(TRUE, NA))
  expect_identical(cellspecR:::.cs_json_value(NULL, "character"), NA_character_)
  expect_identical(cellspecR:::.cs_json_value(NULL, "double"), NA_real_)
  expect_identical(cellspecR:::.cs_json_value(NULL, "integer"), NA_integer_)
  expect_identical(cellspecR:::.cs_json_value(NULL, "logical"), NA)
  expect_identical(
    cellspecR:::.cs_json_columns(list(columns = list()), "empty"),
    data.frame(name = character(), type = character(), stringsAsFactors = FALSE)
  )
  expect_error(
    cellspecR:::.cs_json_columns(list(), "bad"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_json_columns(list(columns = list(list(name = "", type = "double"))), "bad"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_json_columns(list(columns = list(
      list(name = "x", type = "double"), list(name = "x", type = "double")
    )), "bad"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_json_table(
      list(columns = payload$columns, rows = "bad"), "bad"
    ),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_json_table(
      list(columns = payload$columns, rows = list("bad")), "bad"
    ),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_coerce_io_table(
      data.frame(other = 1), payload, "example"
    ),
    class = "cellspec_error"
  )
  expect_identical(cellspecR:::.cs_version_parts("1.2.3"), c(1L, 2L, 3L))
  expect_null(cellspecR:::.cs_version_parts("1.2"))
  expect_null(cellspecR:::.cs_version_parts(NA_character_))
})

test_that("canonical reader handles empty measurements and sidecar failures", {
  parts <- min_parts()
  parts$measurements <- matrix(numeric(), nrow = nrow(parts$cells), ncol = 0L)
  parts$dictionary <- parts$dictionary[FALSE, , drop = FALSE]
  parts$channels <- parts$channels[FALSE, , drop = FALSE]
  empty <- cs_new(
    parts$cells, parts$measurements, parts$dictionary,
    parts$images, parts$channels
  )
  path <- tempfile("cellspec-empty-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  cs_write(empty, path)
  round_trip <- cs_read_cellspec(path, verify = FALSE)
  expect_identical(round_trip$measurements, empty$measurements)
  expect_error(
    cs_read_cellspec(tempfile("missing-cellspec-")),
    class = "cellspec_error"
  )

  no_sidecar <- tempfile("cellspec-no-sidecar-")
  dir.create(no_sidecar)
  on.exit(unlink(no_sidecar, recursive = TRUE, force = TRUE), add = TRUE)
  expect_error(cs_read_cellspec(no_sidecar), class = "cellspec_error")
  file.create(file.path(no_sidecar, "DONE"))
  expect_error(cs_read_cellspec(no_sidecar), class = "cellspec_error")

  malformed <- tempfile("cellspec-malformed-")
  dir.create(malformed)
  on.exit(unlink(malformed, recursive = TRUE, force = TRUE), add = TRUE)
  file.create(file.path(malformed, "DONE"))
  writeLines("{", file.path(malformed, "cellspec.json"))
  expect_error(cs_read_cellspec(malformed, verify = FALSE),
               class = "cellspec_error")
})

test_that("integrity manifest validation catches unsafe, duplicate and extra entries", {
  path <- tempfile("cellspec-integrity-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(path)
  manifest <- file.path(path, "MANIFEST.sha256")
  file.create(manifest)
  expect_error(cellspecR:::.cs_manifest_entries(path),
               class = "cellspec_error_integrity")
  writeLines("bad", manifest)
  expect_error(cellspecR:::.cs_manifest_entries(path),
               class = "cellspec_error_integrity")
  writeLines(paste0(strrep("a", 64), "  ../unsafe"), manifest)
  expect_error(cellspecR:::.cs_manifest_entries(path),
               class = "cellspec_error_integrity")
  writeLines(c(
    paste0(strrep("a", 64), "  x"),
    paste0(strrep("b", 64), "  x")
  ), manifest)
  expect_error(cellspecR:::.cs_manifest_entries(path),
               class = "cellspec_error_integrity")

  cs_write(min_object(), path, overwrite = TRUE)
  writeLines("extra", file.path(path, "extra.txt"))
  report <- cs_verify(path)
  expect_true(any(report$file == "extra.txt" & !report$ok))
  unlink(file.path(path, "DONE"))
  report <- cs_verify(path)
  expect_false(report$ok[report$file == "DONE"])
  expect_error(cs_verify(tempfile("missing-integrity-")),
               class = "cellspec_error")
})

test_that("generic adapter covers compressed input, detection and mapping failures", {
  path <- tempfile("generic-", fileext = ".tsv.gz")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(
    data.frame(id = c("a", "b"), x = c(1, 2), y = c(3, 4),
               value = c(1.2, 2.4), check.names = FALSE),
    path, sep = "\t", compress = "gzip"
  )
  expect_equal(nrow(cellspecR:::.cs_table_read(path, n_max = 1L)), 1L)
  expect_equal(cellspecR:::.cs_table_derived_image_id(path), basename(sub("\\.tsv\\.gz$", "", path)))
  expect_true(nrow(cellspecR::cs_detect_format(path)) >= 1L)
  expect_s3_class(
    cellspecR::cs_read(
      path, format = "table",
      column_map = cellspecR::cs_column_map("id", "x", "y")
    ),
    "cellspec"
  )

  expect_error(
    cellspecR::cs_column_map("id", "x", "y", coordinate_unit = "bad"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR::cs_column_map(
      "id", "x", "y",
      measurements = data.frame(
        source_name = "id", kind = "intensity", marker = "A",
        compartment = "cell", statistic = "mean", unit = "a.u.",
        stringsAsFactors = FALSE
      )
    ),
    class = "cellspec_error"
  )

  bad_format <- tempfile("bad-table-")
  on.exit(unlink(bad_format), add = TRUE)
  writeLines(character(), bad_format)
  expect_error(cellspecR::cs_detect_format(bad_format),
               class = "cellspec_error")
  empty_dir <- tempfile("empty-table-dir-")
  dir.create(empty_dir)
  on.exit(unlink(empty_dir, recursive = TRUE), add = TRUE)
  expect_error(cellspecR::cs_detect_format(empty_dir),
               class = "cellspec_error")
})

test_that("generic adapter handles image overrides and reserved extra columns", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(
    id = c("a", "b"), x = c(1, 2), y = c(3, 4),
    image = c("i", "i"), sample = c("s1", "s2"),
    stringsAsFactors = FALSE
  ), path)
  map <- cellspecR::cs_column_map("id", "x", "y", image_id = "image", sample_id = "sample")
  expect_error(
    cellspecR::cs_read(path, format = "table", column_map = map),
    class = "cellspec_error"
  )
  expect_identical(
    cellspecR::cs_read(
      path, format = "table", column_map = map,
      image_id = "override", sample_id = "sample-override"
    )$images$image_id,
    "override"
  )

  reserved <- tempfile(fileext = ".csv")
  on.exit(unlink(reserved), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1, y = 2, area = "unknown"), reserved)
  expect_error(
    cellspecR::cs_read(
      reserved, format = "table",
      column_map = cellspecR::cs_column_map("id", "x", "y")
    ),
    class = "cellspec_error"
  )
  expect_s3_class(
    cellspecR::cs_read(
      reserved, format = "table",
      column_map = cellspecR::cs_column_map("id", "x", "y"),
      keep_other = FALSE, quiet = TRUE
    ),
    "cellspec"
  )
})

test_that("other adapters parse source conventions and defensive cases", {
  expect_null(cellspecR:::.cs_other_measurement("centroid_x", "mcquant"))
  expect_identical(
    cellspecR:::.cs_other_measurement("Marker_mean", "mcquant")$marker,
    "Marker"
  )
  morphology <- vapply(
    c("perimeter", "circularity", "eccentricity", "solidity",
      "major axis length", "minor axis length", "extent", "orientation",
      "entropy", "iqr", "q25", "q75"),
    function(name) cellspecR:::.cs_other_measurement(name, "segmantr")$statistic,
    character(1)
  )
  expect_true(all(c("perimeter", "circularity", "solidity", "other",
                    "major_axis_length", "minor_axis_length", "extent",
                    "orientation") %in% morphology))
  expect_null(cellspecR:::.cs_other_measurement("unrelated", "mcquant"))
  expect_null(cellspecR:::.cs_other_apply_marker_map(NULL, NULL, rlang::caller_env()))
  expect_error(
    cellspecR:::.cs_other_apply_marker_map(NULL, data.frame(x = "a"), rlang::caller_env()),
    class = "cellspec_error"
  )
  mapped <- cellspecR:::.cs_other_apply_marker_map(
    data.frame(marker = "A", stringsAsFactors = FALSE),
    cellspecR::cs_marker_map("A", "B"), rlang::caller_env()
  )
  expect_identical(mapped$marker, "B")

  rds <- tempfile(fileext = ".rds")
  on.exit(unlink(rds), add = TRUE)
  saveRDS(list(bad = TRUE), rds)
  expect_error(cellspecR:::.cs_other_data(rds),
               class = "cellspec_error")
  corrupted <- tempfile(fileext = ".rds")
  on.exit(unlink(corrupted), add = TRUE)
  writeLines("not an rds", corrupted)
  expect_error(cellspecR:::.cs_other_data(corrupted),
               class = "cellspec_error")

  data <- stats::setNames(
    data.frame("a", 2, 3, 4, stringsAsFactors = FALSE),
    c("cell_id", "Cell X Position", "Cell Y Position", "DAPI Mean")
  )
  inform <- tempfile(fileext = ".rds")
  on.exit(unlink(inform), add = TRUE)
  saveRDS(data, inform)
  expect_s3_class(
    cellspecR:::.cs_inform_read(
      inform, image_id = "image", sample_id = "sample", keep_paths = TRUE
    ),
    "cellspec"
  )
  bad_data <- data.frame(cell_id = "a", stringsAsFactors = FALSE)
  bad_rds <- tempfile(fileext = ".rds")
  on.exit(unlink(bad_rds), add = TRUE)
  saveRDS(bad_data, bad_rds)
  expect_error(
    cellspecR:::.cs_other_read(
      bad_rds, "mcquant", pixel_size = NULL, image_id = NULL, sample_id = NULL,
      marker_map = NULL, keep_other = TRUE, keep_paths = FALSE, quiet = TRUE
    ),
    class = "cellspec_error"
  )
})

test_that("QuPath helper aliases and detector failure modes are covered", {
  expect_identical(cellspecR:::.cs_qupath_header(c("\ufeffArea \u00b5m^2", "Area \u03bcm")), c("Area um2", "Area um"))
  expect_identical(
    unname(vapply(c("average", "stdev", "median"), cellspecR:::.cs_qupath_statistic, character(1))),
    c("mean", "sd", "median")
  )
  expect_identical(
    unname(vapply(c("cytosol", "wholecell", "bad"), function(value) {
      result <- cellspecR:::.cs_qupath_compartment(value)
      if (is.null(result)) NA_character_ else result
    }, character(1))),
    c("cytoplasm", "cell", NA_character_)
  )
  expect_null(cellspecR:::.cs_qupath_measurement("not a measurement"))
  expect_identical(cellspecR:::.cs_qupath_shape("Perimeter"), "perimeter")
  expect_null(cellspecR:::.cs_qupath_shape("Unrelated"))

  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1, y = 2), path)
  expect_null(cellspecR:::.cs_qupath_detect(path))
  expect_error(
    cellspecR:::.cs_qupath_map(c("Cell ID", "Centroid X um"), pixel_size = NULL),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_qupath_map(
      c("Cell ID", "Centroid X um", "Centroid Y um"),
      marker_map = data.frame(x = "a")
    ),
    class = "cellspec_error"
  )
})

test_that("signal policy internals cover validation and fallback edge cases", {
  expect_identical(
    cellspecR:::.cs_recycle_signal_argument("cell", 2L, "compartment", rlang::caller_env()),
    c("cell", "cell")
  )
  expect_error(
    cellspecR:::.cs_recycle_signal_argument(c("cell", "nucleus", "membrane"), 2L,
                                            "compartment", rlang::caller_env()),
    class = "cellspec_error"
  )
  policy <- cellspecR::cs_signal_policy("A")
  expect_silent(cellspecR:::.cs_validate_signal_policy(policy, require_class = FALSE))
  expect_error(
    cellspecR:::.cs_validate_signal_policy(unclass(policy), require_class = TRUE),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_validate_signal_policy(policy[, 1, drop = FALSE]),
    class = "cellspec_error"
  )
  empty <- policy[FALSE, , drop = FALSE]
  class(empty) <- c("cs_signal_policy", "data.frame")
  expect_error(cellspecR:::.cs_validate_signal_policy(empty),
               class = "cellspec_error")
  invalids <- list(
    type = within(policy, min_value <- "0"),
    marker = within(policy, marker <- " A"),
    compartment = within(policy, compartment <- "bad"),
    statistic = within(policy, statistic <- "bad"),
    fallback = within(policy, fallback_compartment <- ""),
    minimum = within(policy, min_value <- -1)
  )
  for (value in invalids) {
    class(value) <- c("cs_signal_policy", "data.frame")
    expect_error(cellspecR:::.cs_validate_signal_policy(value),
                 class = "cellspec_error")
  }
  raw <- as.data.frame(policy, stringsAsFactors = FALSE)
  raw$fallback_compartment <- NA
  raw$min_value <- 1L
  normalized <- cellspecR:::.cs_signal_policy_data(raw)
  expect_true(inherits(normalized, "cs_signal_policy"))
  expect_type(normalized$min_value, "double")
  expect_error(cellspecR:::.cs_signal_policy_data(list()),
               class = "cellspec_error")
  expect_identical(cellspecR::cs_marker_map(character(), character()),
                   data.frame(from = character(), to = character(),
                              stringsAsFactors = FALSE))

  x <- cs_example()
  no_fallback <- cellspecR::cs_signal_policy(
    "D", compartment = "cell", fallback_compartment = "nucleus"
  )
  selected <- cellspecR::cs_signal_matrix(x, no_fallback)
  expect_true(all(is.na(selected$signal)))
  expect_error(
    cellspecR::cs_signal_matrix(x, unclass(policy)),
    class = "cellspec_error"
  )

  expect_error(
    cellspecR:::.cs_signal_policy_format("x.txt", NULL, rlang::caller_env()),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_signal_policy_format("x.json", "txt", rlang::caller_env()),
    class = "cellspec_error"
  )
  dir <- tempfile("policy-dir-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  expect_error(
    cellspecR:::.cs_check_signal_destination(dir, rlang::caller_env()),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_check_signal_destination(
      file.path(dir, "missing", "policy.json"), rlang::caller_env()
    ),
    class = "cellspec_error"
  )
})

test_that("canonical writer helpers cover declared types and failure reporting", {
  expect_identical(
    vapply(list("x", 1, 1L, TRUE), function(value) {
      cellspecR:::.cs_io_column_type(value, "x", "value")
    }, character(1)),
    c("character", "double", "integer", "logical")
  )
  expect_error(
    cellspecR:::.cs_io_column_type(list(1), "x", "value"),
    class = "cellspec_error"
  )
  duplicate <- data.frame(a = 1, b = 2)
  names(duplicate) <- c("a", "a")
  expect_error(cellspecR:::.cs_io_columns(duplicate, "x"),
               class = "cellspec_error")
  expect_equal(
    cellspecR:::.cs_io_rows(data.frame(a = numeric(), stringsAsFactors = FALSE)),
    list()
  )
  expect_equal(
    length(cellspecR:::.cs_io_rows(data.frame(a = 1, stringsAsFactors = FALSE))),
    1L
  )
  expect_identical(
    cellspecR:::.cs_io_table(data.frame(a = 1), "x", include_rows = FALSE),
    list(columns = list(list(name = "a", type = "double")))
  )
  expect_identical(
    cellspecR:::.cs_format_tsv_double(c(1.25, NA_real_)),
    c("1.25e+00", NA_character_)
  )
  nested <- file.path(tempdir(), "cellspec-edge-parent", "child")
  unlink(dirname(nested), recursive = TRUE, force = TRUE)
  stage <- cellspecR:::.cs_stage_path(nested)
  expect_true(dir.exists(dirname(nested)))
  expect_true(grepl("\\.partial-", stage))
  unlink(dirname(nested), recursive = TRUE, force = TRUE)

  json <- tempfile(fileext = ".json")
  on.exit(unlink(json), add = TRUE)
  expect_invisible(cellspecR:::.cs_write_json(list(ok = TRUE), json))
  expect_error(
    cellspecR:::.cs_write_json(list(environment()), json),
    class = "cellspec_error"
  )
  invalid <- tempfile(fileext = ".parquet")
  on.exit(unlink(invalid), add = TRUE)
  expect_error(
    cellspecR:::.cs_write_table(data.frame(value = as.raw(1)), invalid, "parquet"),
    class = "cellspec_error"
  )

  file <- tempfile("destination-file-")
  on.exit(unlink(file), add = TRUE)
  file.create(file)
  expect_error(cs_write(min_object(), file), class = "cellspec_error")
  nested_target <- file.path(tempdir(), "cellspec-write-parent", "object")
  unlink(dirname(nested_target), recursive = TRUE, force = TRUE)
  on.exit(unlink(dirname(nested_target), recursive = TRUE, force = TRUE), add = TRUE)
  expect_invisible(cs_write(min_object(), nested_target))
  expect_true(dir.exists(nested_target))
})

test_that("canonical reader rejects unsupported sidecar versions and formats", {
  path <- tempfile("cellspec-sidecar-")
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  cs_write(min_object(), path)
  sidecar <- jsonlite::fromJSON(
    file.path(path, "cellspec.json"), simplifyVector = FALSE
  )
  sidecar$spec_version <- "2.0.0"
  jsonlite::write_json(sidecar, file.path(path, "cellspec.json"),
                       auto_unbox = TRUE, null = "null", pretty = TRUE)
  expect_error(cs_read_cellspec(path, verify = FALSE),
               class = "cellspec_error_version")
  sidecar$spec_version <- "1.0.0"
  sidecar$files$cells <- "other.dat"
  jsonlite::write_json(sidecar, file.path(path, "cellspec.json"),
                       auto_unbox = TRUE, null = "null", pretty = TRUE)
  expect_error(cs_read_cellspec(path, verify = FALSE),
               class = "cellspec_error_format")
})

test_that("app validates unnamed launcher arguments", {
  skip_if_not_installed("shiny")
  expect_error(
    do.call(
      cs_app,
      c(
        list(path = NULL, max_upload_mb = 10, allow_local_paths = FALSE,
             max_plot_points = 10L),
        list("unnamed")
      )
    ),
    class = "cellspec_error"
  )
})

test_that("adapter defensive branches cover alternate conventions", {
  expect_identical(
    cellspecR:::.cs_other_measurement("Nucleus: CD3e: Mean", "mcquant")$compartment,
    "nucleus"
  )
  expect_null(cellspecR:::.cs_other_measurement("Bad: CD3e: Mean", "mcquant"))
  expect_null(cellspecR:::.cs_other_measurement("CD3e: Area", "mcquant"))
  expect_null(cellspecR:::.cs_other_measurement("Cell: : Mean", "mcquant"))

  no_suffix <- tempfile(fileext = ".csv")
  on.exit(unlink(no_suffix), add = TRUE)
  data.table::fwrite(
    stats::setNames(data.frame("a", 1, 2), c(
      "cell_id", paste0("centroid_", "row"), paste0("centroid_", "col")
    )),
    no_suffix
  )
  expect_identical(
    cellspecR:::.cs_other_detect(no_suffix)$format,
    "mcquant"
  )
  expect_null(cellspecR:::.cs_other_detect(file.path(tempdir(), "missing.csv")))

  um <- tempfile(fileext = ".csv")
  on.exit(unlink(um), add = TRUE)
  data.table::fwrite(data.frame(id = "a", x = 1, y = 2), um)
  expect_s3_class(
    cellspecR:::.cs_other_read(
      um, "mcquant", image_id = "image", sample_id = "sample",
      keep_other = TRUE, keep_paths = FALSE, quiet = TRUE
    ),
    "cellspec"
  )

  empty <- tempfile(fileext = ".csv")
  on.exit(unlink(empty), add = TRUE)
  file.create(empty)
  expect_error(
    cellspecR:::.cs_other_read(
      empty, "mcquant", image_id = NULL, sample_id = NULL,
      keep_other = TRUE, keep_paths = FALSE, quiet = TRUE
    ),
    class = "cellspec_error"
  )
})

test_that("QuPath and generic readers cover malformed and fallback inputs", {
  expect_null(cellspecR:::.cs_qupath_measurement("CD3e: Area"))
  expect_null(cellspecR:::.cs_qupath_measurement("Bad: CD3e: Mean"))
  expect_null(cellspecR:::.cs_qupath_measurement("Cell: : Mean"))
  expect_identical(cellspecR:::.cs_qupath_shape("Area um2"), "area")
  expect_null(cellspecR:::.cs_qupath_detect(file.path(tempdir(), "missing.tsv")))
  directory <- tempfile("qupath-directory-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  expect_null(cellspecR:::.cs_qupath_detect(directory))
  expect_error(cellspecR:::.cs_qupath_read(directory), class = "cellspec_error")

  table_dir <- tempfile("table-directory-")
  dir.create(table_dir)
  on.exit(unlink(table_dir, recursive = TRUE), add = TRUE)
  expect_error(cellspecR:::.cs_table_read(table_dir), class = "cellspec_error")
  expect_identical(cellspecR:::.cs_table_derived_image_id(".csv"), ".csv")
  expect_error(cellspecR::cs_read(table_dir, format = "", column_map = NULL), class = "cellspec_error")
  expect_error(cellspecR::cs_read(table_dir, format = NA_character_, column_map = NULL), class = "cellspec_error")
  expect_error(
    cellspecR::cs_read(
      table_dir, format = "table",
      marker_map = data.frame(from = "a", stringsAsFactors = FALSE),
      column_map = NULL
    ),
    class = "cellspec_error"
  )
})

test_that("canonical I/O defensive branches report malformed files", {
  scalar <- tempfile(fileext = ".json")
  on.exit(unlink(scalar), add = TRUE)
  writeLines("1", scalar)
  expect_error(cellspecR:::.cs_read_json(scalar), class = "cellspec_error")
  expect_error(
    cellspecR:::.cs_json_columns(
      list(columns = list(list(name = "x", type = "raw"))), "bad"
    ),
    class = "cellspec_error"
  )

  payload <- list(
    columns = list(list(name = "x", type = "double")),
    rows = list()
  )
  missing <- tempfile(fileext = ".parquet")
  expect_error(
    cellspecR:::.cs_read_table(missing, "parquet", payload, "example"),
    class = "cellspec_error_integrity"
  )
  corrupt_parquet <- tempfile(fileext = ".parquet")
  on.exit(unlink(corrupt_parquet), add = TRUE)
  writeLines("not parquet", corrupt_parquet)
  expect_error(
    cellspecR:::.cs_read_table(corrupt_parquet, "parquet", payload, "example"),
    class = "cellspec_error"
  )
  corrupt_tsv <- tempfile(fileext = ".gz")
  on.exit(unlink(corrupt_tsv), add = TRUE)
  writeLines("not gzip", corrupt_tsv)
  suppressWarnings(expect_error(
    cellspecR:::.cs_read_table(corrupt_tsv, "tsv.gz", payload, "example"),
    class = "cellspec_error"
  ))

  no_manifest <- tempfile("no-manifest-")
  dir.create(no_manifest)
  on.exit(unlink(no_manifest, recursive = TRUE), add = TRUE)
  expect_error(cellspecR:::.cs_manifest_entries(no_manifest), class = "cellspec_error_integrity")

  path <- tempfile("missing-data-")
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  cs_write(min_object(), path)
  unlink(file.path(path, "cells.parquet"))
  report <- cs_verify(path)
  expect_false(report$ok[report$file == "cells.parquet"])
  expect_error(cs_read_cellspec(path, verify = FALSE), class = "cellspec_error_integrity")

  sidecar <- jsonlite::fromJSON(
    file.path(path, "cellspec.json"), simplifyVector = FALSE
  )
  sidecar$spec_version <- "1.1.0"
  jsonlite::write_json(
    sidecar, file.path(path, "cellspec.json"),
    auto_unbox = TRUE, null = "null", pretty = TRUE
  )
  expect_error(cs_read_cellspec(path, verify = FALSE), class = "cellspec_error_version")
})

test_that("writer helpers report staging and output failures", {
  parent_file <- tempfile("stage-parent-")
  on.exit(unlink(parent_file, recursive = TRUE, force = TRUE), add = TRUE)
  file.create(parent_file)
  expect_error(
    cellspecR:::.cs_stage_path(file.path(parent_file, "child")),
    class = "cellspec_error"
  )

  output_dir <- tempfile("tsv-output-")
  dir.create(output_dir)
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  expect_error(
    cellspecR:::.cs_write_tsv(data.frame(x = 1), output_dir),
    class = "cellspec_error"
  )

  target <- tempfile("commit-target-")
  dir.create(target)
  on.exit(unlink(target, recursive = TRUE), add = TRUE)
  suppressWarnings(expect_error(
    cellspecR:::.cs_commit_stage(
      tempfile("missing-stage-"), target, overwrite = TRUE
    ),
    class = "cellspec_error"
  ))
  expect_true(dir.exists(target))
})
