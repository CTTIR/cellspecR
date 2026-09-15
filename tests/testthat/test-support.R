test_that("cs_feature_support() returns exact statistics per image and feature", {
  x <- min_object()
  s <- cs_feature_support(x)
  expect_named(s, c("image_id", "feature_id", "marker", "compartment", "statistic",
                    "n", "n_na", "fraction_zero", "sd", "mad", "q01", "q50", "q99",
                    "support"))
  expect_identical(s$feature_id, c("cell:CD3e:mean", "nucleus:FOXP3:mean"))
  expect_identical(s$n, c(3L, 3L))
  expect_identical(s$n_na, c(0L, 0L))
  expect_equal(s$fraction_zero, c(1 / 3, 0))
  expect_equal(s$sd, c(stats::sd(c(10, 0, 5)), 1))
  expect_equal(s$q50, c(5, 2))
  expect_equal(s$q01[1], unname(stats::quantile(c(10, 0, 5), 0.01)))
  expect_identical(s$support, c("ok", "ok"))
})

test_that("support classes follow their documented precedence", {
  x <- cellspecR:::.cs_simulate(n_cells = 200L, n_images = 1L,
                                markers = c("A", "B", "C", "D", "E"),
                                compartments = "cell", other = FALSE)
  m <- x$measurements
  m[, "cell:A:mean"] <- 0
  m[, "cell:B:mean"] <- 7.25
  m[1:150, "cell:C:mean"] <- NA
  m[, "cell:D:mean"] <- c(5, rep(0, 199))
  x$measurements <- m
  s <- cs_feature_support(x)
  support <- stats::setNames(s$support, s$marker)
  expect_identical(unname(support[c("A", "B", "C", "D", "E")]),
                   c("constant", "constant", "mostly_na", "near_constant", "ok"))
  expect_identical(s$fraction_zero[s$marker == "A"], 1)
})

test_that("zero_tol widens what counts as zero", {
  x <- min_object()
  s <- cs_feature_support(x, zero_tol = 5)
  expect_equal(s$fraction_zero[s$marker == "CD3e"], 2 / 3)
})

test_that("cs_feature_support() handles all-missing, single-value and empty inputs", {
  x <- min_object()
  x$measurements[, "cell:CD3e:mean"] <- NA
  x$measurements[2:3, "nucleus:FOXP3:mean"] <- NA
  s <- cs_feature_support(x)
  expect_identical(s$support, c("mostly_na", "mostly_na"))
  expect_true(is.na(s$sd[1]) && is.na(s$q50[1]))
  expect_true(is.na(s$sd[2]))
  empty <- cs_feature_support(x, features = character())
  expect_identical(nrow(empty), 0L)
  expect_named(empty, names(s))
  p <- min_parts()
  y <- cs_new(p$cells[0, ], images = p$images)
  expect_identical(nrow(cs_feature_support(y)), 0L)
})

test_that("cs_feature_support() validates its arguments", {
  x <- min_object()
  expect_snapshot(error = TRUE, {
    cs_feature_support(x, features = "nope")
    cs_feature_support(x, features = 1)
    cs_feature_support(x, zero_tol = -1)
    cs_feature_support(list())
  })
})

test_that("feature support is computed per image", {
  x <- sim_object(adjacency = FALSE)
  x$measurements[x$cells$image_id == "img2", "cell:CD3e:mean"] <- 0
  s <- cs_feature_support(x)
  expect_identical(nrow(s), 2L * length(cs_features(x, kind = "intensity", statistic = "mean")))
  cd3 <- s[s$feature_id == "cell:CD3e:mean", ]
  expect_identical(cd3$image_id, c("img1", "img2"))
  expect_identical(cd3$support, c("ok", "constant"))
})
