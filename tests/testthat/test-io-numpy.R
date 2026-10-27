# Hand-built .npy members follow NEP 1 byte for byte, so the reader is tested
# against the format itself rather than only against cs_write_npy().
npy_raw <- function(descr, shape, payload, fortran = FALSE, version = 1L) {
  shape_text <- if (length(shape) == 0L) {
    "()"
  } else if (length(shape) == 1L) {
    paste0("(", shape, ",)")
  } else {
    paste0("(", paste(shape, collapse = ", "), ")")
  }
  header <- paste0(
    "{'descr': '", descr, "', 'fortran_order': ", if (fortran) "True" else "False",
    ", 'shape': ", shape_text, ", }"
  )
  prefix <- if (version == 1L) 10L else 12L
  pad <- (64L - (prefix + nchar(header) + 1L) %% 64L) %% 64L
  header <- paste0(header, strrep(" ", pad), "\n")
  n <- nchar(header)
  len <- if (version == 1L) {
    as.raw(c(n %% 256L, n %/% 256L))
  } else {
    as.raw(c(n %% 256L, n %/% 256L, 0L, 0L))
  }
  c(
    as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59)), as.raw(c(version, 0L)), len,
    charToRaw(header), payload
  )
}

write_raw <- function(bytes) {
  path <- withr::local_tempfile(fileext = ".npy", .local_envir = parent.frame())
  writeBin(bytes, path)
  path
}

le <- function(x, size, what = "integer") writeBin(x, raw(), size = size, endian = "little")

test_that("plain numeric, boolean and string dtypes are decoded", {
  expect_identical(
    cs_read_npy(write_raw(npy_raw("<f4", 3, le(c(1.5, -2, 0.25), 4L)))),
    c(1.5, -2, 0.25)
  )
  expect_identical(cs_read_npy(write_raw(npy_raw("<f8", 2, le(c(pi, 1e-300), 8L)))), c(pi, 1e-300))
  expect_identical(cs_read_npy(write_raw(npy_raw(">f8", 1, writeBin(2.5, raw(), endian = "big")))), 2.5)
  expect_identical(cs_read_npy(write_raw(npy_raw("|b1", 3, as.raw(c(1, 0, 1))))), c(TRUE, FALSE, TRUE))
  expect_identical(cs_read_npy(write_raw(npy_raw("|i1", 2, as.raw(c(0xff, 0x05))))), c(-1L, 5L))
  expect_identical(cs_read_npy(write_raw(npy_raw("<i2", 2, le(c(-300L, 7L), 2L)))), c(-300L, 7L))
  expect_identical(cs_read_npy(write_raw(npy_raw("<u2", 1, as.raw(c(0xff, 0xff))))), 65535L)
  expect_identical(cs_read_npy(write_raw(npy_raw("<i4", 2, le(c(-5L, 2147483647L), 4L)))), c(-5L, 2147483647L))
  expect_identical(cs_read_npy(write_raw(npy_raw("<u4", 1, as.raw(c(0xff, 0xff, 0xff, 0xff))))), 4294967295)
  i8 <- c(as.raw(c(0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff)), as.raw(c(0, 0, 0, 0, 1, 0, 0, 0)))
  expect_identical(cs_read_npy(write_raw(npy_raw("<i8", 2, i8))), c(-2, 2^32))
  u <- c(utf8ToInt("Treg"), 0L, 0L, utf8ToInt("CD8 T"), 0L, utf8ToInt("µm"), 0L, 0L, 0L, 0L)
  out <- cs_read_npy(write_raw(npy_raw("<U6", 3, le(u, 4L))))
  expect_identical(out, enc2utf8(c("Treg", "CD8 T", "µm")))
  expect_identical(cs_read_npy(write_raw(npy_raw("|S3", 2, c(charToRaw("ab"), as.raw(0), charToRaw("xyz"))))), c("ab", "xyz"))
  expect_identical(cs_read_npy(write_raw(npy_raw("<c16", 1, le(c(1, -2), 8L)))), complex(real = 1, imaginary = -2))
})

test_that("shapes and storage orders give NumPy's logical layout", {
  # NumPy [[1, 2, 3], [4, 5, 6]] in C order is stored 1..6 row by row.
  m <- cs_read_npy(write_raw(npy_raw("<i4", c(2, 3), le(1:6, 4L))))
  expect_identical(m, matrix(1:6, nrow = 2, byrow = TRUE))
  f <- cs_read_npy(write_raw(npy_raw("<i4", c(2, 3), le(c(1L, 4L, 2L, 5L, 3L, 6L), 4L), fortran = TRUE)))
  expect_identical(f, m)
  a <- cs_read_npy(write_raw(npy_raw("<i4", c(2, 3, 4), le(0:23, 4L))))
  expect_identical(dim(a), c(2L, 3L, 4L))
  expect_identical(a[2, 3, 4], 23L)
  expect_identical(a[1, 2, 3], 6L)
  expect_identical(cs_read_npy(write_raw(npy_raw("<f8", numeric(), le(42, 8L)))), 42)
  expect_identical(cs_read_npy(write_raw(npy_raw("<f4", 0, raw()))), double())
  expect_identical(cs_read_npy(write_raw(npy_raw("<U3", 0, raw()))), character())
  v2 <- cs_read_npy(write_raw(npy_raw("<f8", 2, le(c(1, 2), 8L), version = 2L)))
  expect_identical(v2, c(1, 2))
})

test_that("unsupported or damaged files fail with a format error", {
  expect_error(cs_read_npy(write_raw(charToRaw("not numpy at all"))), class = "cellspec_error_format")
  expect_error(
    cs_read_npy(write_raw(npy_raw("|O", 1, raw(8)))),
    "pickle",
    class = "cellspec_error_format"
  )
  expect_error(cs_read_npy(write_raw(npy_raw("<f2", 1, raw(2)))), class = "cellspec_error_format")
  expect_error(cs_read_npy(write_raw(npy_raw("<f8", 3, le(1, 8L)))), "shorter", class = "cellspec_error_format")
  expect_error(cs_read_npy(write_raw(npy_raw("|b1", 1, as.raw(2)))), class = "cellspec_error_format")
  big <- as.raw(c(0, 0, 0, 0, 0, 0, 0x40, 0))
  expect_error(cs_read_npy(write_raw(npy_raw("<i8", 1, big))), "2\\^53", class = "cellspec_error_format")
  header <- "{'descr': [('a', '<f8')], 'fortran_order': False, 'shape': (1,), }\n"
  structured <- c(
    as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59, 1, 0)), as.raw(c(nchar(header), 0)),
    charToRaw(header), le(1, 8L)
  )
  expect_error(cs_read_npy(write_raw(structured)), "Structured", class = "cellspec_error_format")
  expect_error(cs_read_npy(tempfile()), class = "cellspec_error_io")
  expect_error(cs_read_npy(NA_character_), class = "cellspec_error_argument")
})

test_that("written arrays round-trip and npz archives are read selectively", {
  path <- withr::local_tempfile(fileext = ".npz")
  x <- list(
    x_um = c(1.25, 2.5, -3),
    count = matrix(1:6, nrow = 2),
    counted = c(TRUE, FALSE, TRUE),
    label = c("Tumour", "Treg", "CD8 T µ"),
    cube = array(as.double(1:24), dim = c(2, 3, 4))
  )
  expect_identical(cs_write_npz(x, path), path)
  back <- cs_read_npz(path)
  expect_identical(names(back), names(x))
  expect_identical(back$x_um, x$x_um)
  expect_identical(back$count, x$count)
  expect_identical(back$counted, x$counted)
  expect_identical(back$label, enc2utf8(x$label))
  expect_identical(back$cube, x$cube)
  expect_identical(cs_read_npz(path, arrays = c("label", "x_um")), back[c("label", "x_um")])
  expect_error(cs_read_npz(path, arrays = "absent"), "absent", class = "cellspec_error_format")
  expect_error(cs_read_npz(path, arrays = c("x_um", "x_um")), class = "cellspec_error_argument")
  listing <- utils::unzip(path, list = TRUE)
  expect_identical(listing$Name, paste0(names(x), ".npy"))

  one <- withr::local_tempfile(fileext = ".npy")
  cs_write_npy(c(a = 1L, b = 2L), one)
  expect_identical(cs_read_npy(one), c(1L, 2L))
  bytes <- readBin(one, "raw", 200L)
  header_end <- 10L + as.integer(bytes[9]) + 256L * as.integer(bytes[10])
  expect_identical(header_end %% 64L, 0L)
})

test_that("writers refuse what NumPy files cannot hold", {
  path <- withr::local_tempfile(fileext = ".npz")
  expect_error(cs_write_npz(list(1, 2), path), class = "cellspec_error_argument")
  expect_error(cs_write_npz(list(a = 1, a = 2), path), class = "cellspec_error_argument")
  expect_error(cs_write_npz(list(`a/b` = 1), path), class = "cellspec_error_argument")
  expect_error(cs_write_npz(list(a = c(1, NA)), path), class = "cellspec_error_argument")
  expect_error(cs_write_npz(list(a = list(1)), path), class = "cellspec_error_argument")
  expect_error(cs_write_npy(Sys.Date(), path), class = "cellspec_error_argument")
  expect_error(cs_read_npz(withr::local_tempfile(lines = "plain text")), class = "cellspec_error_format")
})
