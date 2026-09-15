test_that("valid objects pass every structure and semantic check", {
  for (x in list(min_object(), cs_example(), sim_object())) {
    r <- cs_validate(x, level = "semantic")
    expect_s3_class(r, "cellspec_validation")
    expect_named(r, c("check", "level", "status", "n", "message"))
    expect_identical(r$status, rep("pass", nrow(r)))
    expect_type(r$n, "integer")
  }
})

test_that("structure level omits semantic checks", {
  r <- cs_validate(cs_example())
  expect_true(all(r$level == "structure"))
  catalogue <- cellspecR:::.cs_checks()
  expect_identical(r$check, catalogue$check[catalogue$level == "structure"])
})

test_that("each invalid fixture fails exactly its own check", {
  cases <- invalid_objects()
  structure_checks <- with(cellspecR:::.cs_checks(), check[level == "structure"])
  expect_gte(length(cases), 20L)
  # every structure rule has at least one fixture
  expect_setequal(unique(vapply(cases, `[[`, "", "check")), structure_checks)
  for (case in cases) {
    fails <- failing_checks(case$object)
    expect_identical(fails, case$check, label = paste("fixture for", case$check))
  }
})

test_that("failure messages are informative", {
  cases <- invalid_objects()
  seen <- character()
  msgs <- character()
  for (case in cases) {
    if (case$check %in% seen) next
    seen <- c(seen, case$check)
    r <- cs_validate(case$object)
    msgs <- c(msgs, paste0(case$check, ": ", r$message[r$status == "fail"]))
  }
  expect_snapshot(writeLines(msgs))
})

test_that("checks with failed prerequisites are skipped, not passed", {
  x <- sim_object()
  x$cells$y <- NULL
  r <- cs_validate(x)
  expect_identical(r$status[r$check == "cells_coordinates_finite"], "skip")
  expect_identical(r$status[r$check == "adjacency_endpoints"], "skip")
  y <- unclass(sim_object())
  r2 <- cs_validate(y)
  expect_identical(sum(r2$status == "skip"), nrow(r2) - 1L)
})

test_that("semantic checks are skipped when structure fails", {
  x <- sim_object()
  x$cells$x[1] <- NA
  r <- cs_validate(x, level = "semantic")
  sem <- r[r$level == "semantic", ]
  expect_true(all(sem$status == "skip"))
  expect_true(all(sem$message == "Not run: structure checks failed."))
})

test_that("semantic checks warn about implausible content", {
  x <- sim_object(adjacency = FALSE)
  x$cells$x[1] <- 1e5
  x$cells$area[2] <- 0.5
  x$cells$area[3] <- 6000
  x$measurements[4, "cell:CD3e:mean"] <- -3
  x$measurements[1:3, "nucleus:DAPI:mean"] <- NA
  x$measurements[x$cells$image_id == "img2", "cell:FOXP3:mean"] <- 0
  x$cells$x[6] <- x$cells$x[5]
  x$cells$y[6] <- x$cells$y[5]
  r <- cs_validate(x, level = "semantic")
  expect_identical(failing_checks(x), character())
  warned <- r$check[r$status == "warn"]
  expect_setequal(warned, c("centroids_within_image", "area_range", "negative_intensity",
                            "feature_na_fraction", "feature_support", "duplicate_centroids"))
  expect_identical(r$n[r$check == "area_range"], 2L)
  expect_identical(r$n[r$check == "negative_intensity"], 1L)
  expect_identical(r$n[r$check == "duplicate_centroids"], 1L)
  expect_snapshot(print(r))
})

test_that("semantic thresholds are arguments", {
  x <- sim_object(adjacency = FALSE)
  x$cells$area[1] <- 400
  r <- cs_validate(x, level = "semantic", area_range = c(1, 300))
  expect_identical(r$status[r$check == "area_range"], "warn")
  x$measurements[1, 1] <- NA
  r2 <- cs_validate(x, level = "semantic", na_max = 0.5)
  expect_identical(r2$status[r2$check == "feature_na_fraction"], "pass")
  expect_error(cs_validate(x, area_range = 1), class = "cellspec_error")
  expect_error(cs_validate(x, area_range = c(5, 1)), class = "cellspec_error")
  expect_error(cs_validate(x, na_max = -1), class = "cellspec_error")
  expect_error(cs_validate(x, level = "deep"))
})

test_that("semantic checks handle objects without dimensions, area or intensities", {
  p <- min_parts()
  p$images$width_px <- NULL
  p$images$height_px <- NULL
  p$cells$area <- NULL
  x <- cs_new(p$cells, images = p$images)
  r <- cs_validate(x, level = "semantic")
  expect_true(all(r$status == "pass"))
  expect_match(r$message[r$check == "centroids_within_image"], "unknown")
  expect_match(r$message[r$check == "area_range"], "no `area`")
  y <- min_object()
  y$images$width_px <- NA_integer_
  y$images$height_px <- NA_integer_
  r2 <- cs_validate(y, level = "semantic")
  expect_match(r2$message[r2$check == "centroids_within_image"], "unknown")
})

test_that("centroid extent honours non-square pixels", {
  x <- min_object()
  x$images$pixel_size_y <- 2
  x$cells$y <- c(150, 160, 170)
  r <- cs_validate(x, level = "semantic")
  expect_identical(r$status[r$check == "centroids_within_image"], "pass")
})

test_that("print() lists fails first and summarises passes", {
  x <- sim_object()
  x$cells$cell_id[2] <- x$cells$cell_id[1]
  x$images$pixel_size <- -1
  expect_snapshot(print(cs_validate(x)))
  capture.output(vis <- withVisible(print(cs_validate(cs_example()))))
  expect_false(vis$visible)
})

test_that("cs_assert_valid() returns the object or aborts with the report", {
  x <- cs_example()
  expect_invisible(cs_assert_valid(x))
  expect_identical(cs_assert_valid(x), x)
  bad <- x
  bad$cells$x[1:12] <- NA
  bad$images$pixel_size <- 0
  expect_error(cs_assert_valid(bad), class = "cellspec_error_invalid")
  expect_snapshot(error = TRUE, cs_assert_valid(bad))
})

test_that("cs_assert_valid() abbreviates reports with many failures", {
  cases <- invalid_objects()
  x <- sim_object()
  x$cells$x[1] <- NA
  x$cells$area[2] <- -1
  x$cells$subject_id <- "p"
  x$cells$cs__a <- 1
  x$measurements[1, 1] <- Inf
  x$dictionary$unit[1] <- "bad"
  x$dictionary$source_name[2] <- ""
  x$images$pixel_size <- 0
  x$images$width_px <- -1L
  x$channels$channel_name[1] <- ""
  x$provenance$inputs <- NULL
  x$adjacency$shared_boundary[1] <- -1
  cnd <- rlang::catch_cnd(cs_assert_valid(x), classes = "cellspec_error_invalid")
  expect_gt(sum(cnd$report$status == "fail"), 10L)
  expect_snapshot(error = TRUE, cs_assert_valid(x))
})

test_that("messages with braces do not break the error formatter", {
  x <- sim_object(adjacency = FALSE)
  x$dictionary$marker[1] <- "{CD3e}:x"
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
})

test_that("byte-wise ordering ignores the locale", {
  less <- cellspecR:::.cs_byte_less
  expect_identical(less(c("B", "a", "10", "x", NA), c("a", "B", "9", "x", "y")),
                   c(TRUE, FALSE, TRUE, FALSE, FALSE))
})
