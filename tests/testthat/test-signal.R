signal_fixture <- function() {
  cells <- data.frame(
    cell_id = paste0("c", 1:4),
    image_id = c("img1", "img1", "img2", "img2"),
    sample_id = c("s1", "s1", "s2", "s2"),
    x = 1:4,
    y = 4:1,
    area = rep(50, 4),
    stringsAsFactors = FALSE
  )
  measurements <- cbind(
    "nucleus:A:mean" = c(10, NA, -1, 0),
    "cell:A:mean" = c(1, 2, -1, 99),
    "cell:B:mean" = c(NA, 2, 0, -1)
  )
  dictionary <- data.frame(
    feature_id = colnames(measurements),
    kind = "intensity",
    marker = c("A", "A", "B"),
    compartment = c("nucleus", "cell", "cell"),
    statistic = "mean",
    unit = "a.u.",
    source_name = c("Nucleus: A: Mean", "Cell: A: Mean", "Cell: B: Mean"),
    stringsAsFactors = FALSE
  )
  images <- data.frame(
    image_id = c("img1", "img2"),
    sample_id = c("s1", "s2"),
    pixel_size = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )
  channels <- data.frame(
    image_id = rep(c("img1", "img2"), each = 2),
    channel_index = rep(1:2, 2),
    channel_name = rep(c("A", "B"), 2),
    marker = rep(c("A", "B"), 2),
    stringsAsFactors = FALSE
  )
  cellspecR::cs_new(cells, measurements, dictionary, images, channels)
}

testthat::test_that("cs_signal_policy validates policy rows and recycles scalars", {
  policy <- cellspecR::cs_signal_policy(
    marker = c("A", "B"),
    compartment = "cell",
    statistic = c("mean", "median"),
    fallback_compartment = NA_character_,
    min_value = c(0, 0.25)
  )

  testthat::expect_s3_class(policy, "cs_signal_policy")
  testthat::expect_identical(
    names(policy),
    c("marker", "compartment", "statistic", "fallback_compartment", "min_value")
  )
  testthat::expect_identical(policy$compartment, c("cell", "cell"))
  testthat::expect_identical(policy$fallback_compartment, c(NA_character_, NA_character_))
  testthat::expect_identical(policy$min_value, c(0, 0.25))

  testthat::expect_error(
    cellspecR::cs_signal_policy(c("A", "A")),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_signal_policy("A", compartment = "vesicle"),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_signal_policy("A", statistic = "area"),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_signal_policy("A", fallback_compartment = "vesicle"),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_signal_policy("A", min_value = -1),
    class = "cellspec_error"
  )
})

testthat::test_that("cs_signal_matrix selects preferred, fallback, and unavailable values", {
  x <- signal_fixture()
  policy <- cellspecR::cs_signal_policy(
    marker = c("A", "B", "C"),
    compartment = c("nucleus", "cell", "membrane"),
    fallback_compartment = c("cell", NA_character_, NA_character_),
    min_value = 0
  )

  result <- cellspecR::cs_signal_matrix(x, policy)
  expected_signal <- rbind(
    c(10, NA, NA),
    c(2, 2, NA),
    c(NA, 0, NA),
    c(0, NA, NA)
  )
  dimnames(expected_signal) <- list(paste0("c", 1:4), c("A", "B", "C"))
  expected_source <- rbind(
    c("nucleus:mean", "unavailable", "unavailable"),
    c("fallback:cell:mean", "cell:mean", "unavailable"),
    c("unavailable", "cell:mean", "unavailable"),
    c("nucleus:mean", "unavailable", "unavailable")
  )
  dimnames(expected_source) <- list(paste0("c", 1:4), c("A", "B", "C"))

  testthat::expect_identical(
    result$signal,
    expected_signal
  )
  testthat::expect_identical(
    result$source,
    expected_source
  )
  testthat::expect_identical(result$policy, policy)
  testthat::expect_identical(rownames(result$signal), paste0("c", 1:4))
  testthat::expect_identical(colnames(result$signal), c("A", "B", "C"))

  img2 <- cellspecR::cs_signal_matrix(x, policy, image_id = "img2")
  testthat::expect_identical(rownames(img2$signal), c("c3", "c4"))
  testthat::expect_identical(
    img2$signal[, "A"],
    stats::setNames(c(NA_real_, 0), c("c3", "c4"))
  )
  testthat::expect_error(
    cellspecR::cs_signal_matrix(x, policy, image_id = "missing"),
    class = "cellspec_error"
  )
})

testthat::test_that("cs_marker_map is a validated two-column mapping", {
  map <- cellspecR::cs_marker_map(
    c("PanCK", "CD68"),
    c("Pan-Cytokeratin", "CD68")
  )
  testthat::expect_identical(names(map), c("from", "to"))
  testthat::expect_identical(map$from, c("PanCK", "CD68"))
  testthat::expect_identical(map$to, c("Pan-Cytokeratin", "CD68"))
  testthat::expect_error(
    cellspecR::cs_marker_map(c("A", "A"), c("B", "C")),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_marker_map("A", c("B", "C")),
    class = "cellspec_error"
  )
  testthat::expect_error(
    cellspecR::cs_marker_map("A", "A:B"),
    class = "cellspec_error"
  )
})

testthat::test_that("signal policies preserve values through JSON and CSV", {
  policy <- cellspecR::cs_signal_policy(
    marker = c("β-tubulin", "A"),
    compartment = c("cell", "nucleus"),
    statistic = c("mean", "median"),
    fallback_compartment = c(NA_character_, "cell"),
    min_value = c(0, 0.12345678901234567)
  )

  for (extension in c(".json", ".csv")) {
    path <- tempfile("signal-policy-", fileext = extension)
    testthat::expect_invisible(cellspecR::cs_write_signal_policy(policy, path))
    round_trip <- cellspecR::cs_read_signal_policy(path)
    testthat::expect_s3_class(round_trip, "cs_signal_policy")
    testthat::expect_identical(round_trip$marker, policy$marker)
    testthat::expect_identical(round_trip$compartment, policy$compartment)
    testthat::expect_identical(round_trip$statistic, policy$statistic)
    testthat::expect_identical(round_trip$fallback_compartment, policy$fallback_compartment)
    testthat::expect_identical(round_trip$min_value, policy$min_value)
  }
})

testthat::test_that("signal policy I/O rejects unsupported formats and schemas", {
  policy <- cellspecR::cs_signal_policy("A")
  path <- tempfile("signal-policy-", fileext = ".txt")
  testthat::expect_error(
    cellspecR::cs_write_signal_policy(policy, path),
    class = "cellspec_error"
  )
  bad <- tempfile("signal-policy-", fileext = ".csv")
  data.table::fwrite(data.frame(marker = "A"), bad)
  testthat::expect_error(
    cellspecR::cs_read_signal_policy(bad),
    class = "cellspec_error"
  )
})

testthat::test_that("branch domains retain negative finite values only when declared", {
  x <- signal_fixture()
  before <- serialize(x, NULL)
  policy <- cellspecR::cs_signal_policy(
    c("A", "B"), compartment = c("nucleus", "cell"),
    fallback_compartment = c("cell", NA_character_),
    preferred_domain = c("minimum", "finite"), fallback_domain = "finite"
  )
  result <- cellspecR::cs_signal_matrix(x, policy)
  testthat::expect_identical(unname(result$signal[, "A"]), c(10, 2, -1, 0))
  testthat::expect_identical(unname(result$signal[, "B"]), c(NA_real_, 2, 0, -1))
  testthat::expect_identical(
    unname(result$source[, "A"]),
    c("nucleus:mean", "fallback:cell:mean", "fallback:cell:mean", "nucleus:mean")
  )
  testthat::expect_identical(serialize(x, NULL), before)
  testthat::expect_identical(result$policy, policy)
  testthat::expect_identical(
    cellspecR::cs_signal_matrix(x, policy, image_id = "img2")$signal,
    result$signal[3:4, , drop = FALSE]
  )
})

testthat::test_that("default domain declarations preserve the five-column policy", {
  old <- cellspecR::cs_signal_policy(c("A", "B"), min_value = c(0, 1))
  explicit <- cellspecR::cs_signal_policy(
    c("A", "B"), min_value = c(0, 1),
    preferred_domain = "minimum", fallback_domain = c("minimum", "minimum")
  )
  testthat::expect_identical(old, explicit)
  testthat::expect_length(names(old), 5L)
  for (format in c("json", "csv")) {
    first <- tempfile(fileext = paste0(".", format))
    second <- tempfile(fileext = paste0(".", format))
    on.exit(unlink(c(first, second)), add = TRUE)
    cellspecR::cs_write_signal_policy(old, first)
    cellspecR::cs_write_signal_policy(explicit, second)
    testthat::expect_identical(readBin(first, "raw", file.info(first)$size),
                              readBin(second, "raw", file.info(second)$size))
  }
})

testthat::test_that("extended policy roundtrips preserve both domains", {
  policy <- cellspecR::cs_signal_policy(
    c("A", "B"), preferred_domain = c("finite", "minimum"),
    fallback_domain = c("minimum", "finite")
  )
  for (format in c("json", "csv")) {
    path <- tempfile(fileext = paste0(".", format))
    on.exit(unlink(path), add = TRUE)
    cellspecR::cs_write_signal_policy(policy, path)
    testthat::expect_identical(cellspecR::cs_read_signal_policy(path), policy)
    all_minimum <- policy
    all_minimum$preferred_domain[] <- "minimum"
    all_minimum$fallback_domain[] <- "minimum"
    cellspecR::cs_write_signal_policy(all_minimum, path)
    testthat::expect_identical(cellspecR::cs_read_signal_policy(path), all_minimum)
  }
})

testthat::test_that("malformed domains and partial schemas fail closed", {
  for (bad in list(NA_character_, "Finite", "", character(), 1, TRUE,
                  matrix("finite"), structure("finite", class = "custom"))) {
    testthat::expect_error(cellspecR::cs_signal_policy("A", preferred_domain = bad),
                          class = "cellspec_error")
    testthat::expect_error(cellspecR::cs_signal_policy("A", fallback_domain = bad),
                          class = "cellspec_error")
  }
  testthat::expect_error(
    cellspecR::cs_signal_policy(c("A", "B"), preferred_domain = rep("finite", 3)),
    class = "cellspec_error"
  )
  x <- signal_fixture()
  policy <- cellspecR::cs_signal_policy("A", preferred_domain = "finite")
  partial <- policy
  partial$fallback_domain <- NULL
  testthat::expect_error(cellspecR::cs_signal_matrix(x, partial), class = "cellspec_error")
  reversed <- policy[, rev(names(policy)), drop = FALSE]
  testthat::expect_error(cellspecR::cs_signal_matrix(x, reversed), class = "cellspec_error")
  policy$preferred_domain <- matrix("finite")
  testthat::expect_error(cellspecR::cs_signal_matrix(x, policy), class = "cellspec_error")
})

testthat::test_that("finite domains exclude nonfinite values and preserve extreme finite values", {
  x <- signal_fixture()
  x$measurements[, "cell:B:mean"] <- c(Inf, -Inf, NaN, NA_real_)
  policy <- cellspecR::cs_signal_policy("B", preferred_domain = "finite")
  selected <- cellspecR::cs_signal_matrix(x, policy)
  testthat::expect_true(all(is.na(selected$signal)))
  testthat::expect_true(all(selected$source == "unavailable"))
  tiny <- .Machine$double.xmin * .Machine$double.eps
  values <- c(-.Machine$double.xmax, -tiny, tiny, -0)
  x$measurements[, "cell:B:mean"] <- values
  testthat::expect_identical(unname(cellspecR::cs_signal_matrix(x, policy)$signal[, 1]), values)
  testthat::expect_identical(
    unname(cellspecR::cs_signal_matrix(x, policy)$source[, 1]), rep("cell:mean", 4)
  )
})

testthat::test_that("explicit formats preserve extended policies without filename inference", {
  policy <- cellspecR::cs_signal_policy("A", fallback_domain = "finite")
  for (format in c("json", "csv")) {
    path <- tempfile(fileext = ".policy")
    on.exit(unlink(path), add = TRUE)
    cellspecR::cs_write_signal_policy(policy, path, format = format)
    testthat::expect_identical(
      cellspecR::cs_read_signal_policy(path, format = format), policy
    )
  }
})

testthat::test_that("constructor type refusals also apply with finite domains", {
  for (marker in list(character(), 1)) {
    testthat::expect_error(
      cellspecR::cs_signal_policy(marker, preferred_domain = "finite"),
      class = "cellspec_error"
    )
  }
  for (minimum in list(numeric(), "0")) {
    testthat::expect_error(
      cellspecR::cs_signal_policy("A", min_value = minimum, preferred_domain = "finite"),
      class = "cellspec_error"
    )
  }
  for (compartment in list(character(), 1)) {
    testthat::expect_error(
      cellspecR::cs_signal_policy("A", compartment = compartment, preferred_domain = "finite"),
      class = "cellspec_error"
    )
  }
})

testthat::test_that("malformed JSON returns a structured read error without modifying input", {
  path <- tempfile(fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  bytes <- charToRaw("{not valid JSON")
  writeBin(bytes, path)
  error <- tryCatch(cellspecR::cs_read_signal_policy(path), error = identity)
  testthat::expect_s3_class(error, "cellspec_error_format")
  testthat::expect_match(conditionMessage(error), "{not valid JSON", fixed = TRUE)
  testthat::expect_identical(readBin(path, "raw", length(bytes)), bytes)
})

testthat::test_that("a destination lost after validation yields structured write failures", {
  original_check <- getFromNamespace(".cs_check_signal_destination", "cellspecR")
  for (format in c("json", "csv")) {
    parent <- paste0(tempfile(), "{missing}")
    dir.create(parent)
    path <- file.path(parent, paste0("policy.", format))
    policy <- cellspecR::cs_signal_policy("A", fallback_domain = "finite")
    before <- policy
    testthat::with_mocked_bindings({
      warnings <- character()
      error <- withCallingHandlers(
        tryCatch(cellspecR::cs_write_signal_policy(policy, path), error = identity),
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      )
      testthat::expect_s3_class(error, "cellspec_error_format")
      testthat::expect_match(conditionMessage(error), "{missing}", fixed = TRUE)
      if (format == "json") {
        testthat::expect_true(any(grepl("{missing}", warnings, fixed = TRUE)))
      }
    }, .cs_check_signal_destination = function(path, call) {
      original_check(path, call)
      unlink(dirname(path), recursive = TRUE)
    }, .package = "cellspecR")
    testthat::expect_false(file.exists(path))
    testthat::expect_false(dir.exists(parent))
    testthat::expect_identical(policy, before)
  }
})
