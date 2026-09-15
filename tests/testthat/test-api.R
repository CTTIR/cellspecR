test_that("exported API signatures match the report-only snapshot", {
  exports <- sort(getNamespaceExports("cellspecR"))
  actual <- vapply(exports, function(name) {
    object <- getExportedValue("cellspecR", name)
    if (!is.function(object)) return(paste0(name, " [non-function]"))
    args <- vapply(formals(object), function(value) {
      paste(deparse(value, width.cutoff = 100L), collapse = "")
    }, character(1))
    paste0(name, "(", paste(names(args), args, sep = " = ", collapse = ", "), ")")
  }, character(1))
  expected <- readLines(testthat::test_path("fixtures", "api-signatures.txt"), warn = FALSE)
  expect_identical(unname(actual), expected)
})
