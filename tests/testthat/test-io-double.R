test_that("canonical decimal parsing preserves exact binary doubles", {
  text <- c("9.7951599999999999e+01", "9.2749999999999999e-01",
            "9.9399999999999999e-01", "4.9406564584124654e-324",
            "2.2250738585072014e-308", "1.7976931348623157e+308",
            "1.0000000000000002", "-0", "0", "9007199254740991")
  expected <- c(0x1.87ce703afb7e9p+6, 0x1.dae147ae147aep-1,
                0x1.fced916872b02p-1, 0x0.0000000000001p-1022,
                0x1p-1022, 0x1.fffffffffffffp+1023,
                0x1.0000000000001p+0, -0.0, 0.0, 0x1.fffffffffffffp+52)
  actual <- cellspecR:::.cs_parse_io_double(text)
  expect_identical(writeBin(actual, raw()), writeBin(expected, raw()))
  expect_identical(cellspecR:::.cs_parse_io_double(expected), expected)
  # Cross a parsing block boundary with exact values, without a tolerance.
  expect_identical(cellspecR:::.cs_parse_io_double(rep(text, 1001L)),
                   rep(expected, 1001L))
})

test_that("canonical decimal parsing handles missing values and rejects injection", {
  parse <- cellspecR:::.cs_parse_io_double
  expect_identical(parse(character()), double())
  expect_identical(parse(c(NA_character_, "NA")), c(NA_real_, NA_real_))
  expect_identical(parse(c("NaN", "Inf", "-Inf")), c(NaN, Inf, -Inf))
  for (bad in c("1,2", "[1]", "null", "", "1x", "0x1p0")) {
    expect_error(parse(bad), class = "cellspec_error_format")
  }
})

test_that("TSV cells and measurements retain the hosted roundtrip regressions", {
  x <- cs_example()
  values <- rep(c(0x1.87ce703afb7e9p+6, 0x1.dae147ae147aep-1,
                  0x1.fced916872b02p-1, NA_real_), length.out = nrow(x$cells))
  x$cells$decimal_probe <- values
  x$measurements[, 1L] <- values
  path <- tempfile("exact-decimal-")
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  cs_write(x, path, format = "tsv.gz")
  restored <- cs_read_cellspec(path)
  expect_identical(restored$cells, x$cells)
  expect_identical(restored$measurements, x$measurements)
})
