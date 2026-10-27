# NumPy array files (.npy) and archives (.npz), read and written in base R.
# Format reference: NEP 1 (numpy.lib.format). Only plain dtypes are supported;
# object arrays need Python's pickle and are refused.

#' Read and write NumPy array files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `cs_read_npy()` reads one `.npy` file and `cs_read_npz()` reads the arrays
#' of an `.npz` archive, both without Python. Cell tables exported from Python
#' pipelines (centroids, labels, per-cell flags) can so be brought into
#' `cs_new()` directly. `cs_write_npy()` and `cs_write_npz()` write the same
#' formats, for example to hand results back or to build test fixtures.
#'
#' Supported data types are booleans, signed and unsigned integers, 32- and
#' 64-bit floats, 128-bit complex numbers, fixed-width Unicode (`U`) and byte
#' (`S`) strings, in either byte order and in C or Fortran order. Object
#' arrays (`O`, stored with Python's pickle) and structured data types are
#' refused. 64-bit and unsigned 32-bit integers are returned as doubles; a
#' value that a double cannot hold exactly is an error.
#'
#' @param path Path to a `.npy` file (`cs_read_npy()`, `cs_write_npy()`) or
#'   a `.npz` archive (`cs_read_npz()`, `cs_write_npz()`).
#' @param arrays Names of the arrays to read from the archive, without the
#'   `.npy` suffix. `NULL` reads all arrays.
#' @param x For `cs_write_npy()`: a logical, integer, double or character
#'   vector, matrix or array. For `cs_write_npz()`: a named list of such
#'   objects.
#'
#' @return `cs_read_npy()` returns a vector for one-dimensional arrays, a
#'   matrix or array with the same shape otherwise, and a length-one vector
#'   for zero-dimensional arrays. `cs_read_npz()` returns a named list of
#'   these, in archive order. The writers return `path` invisibly.
#'
#' @details
#' Arrays keep their logical shape: element `[i, j]` in R is element
#' `[i - 1, j - 1]` in NumPy, whatever the storage order. Trailing NUL
#' characters of fixed-width strings are dropped, as NumPy does.
#'
#' `cs_write_npz()` stores the members uncompressed (as `numpy.savez()`
#' does) and needs no external `zip` program. Character data are written as
#' little-endian `U` strings, doubles as `<f8`, integers as `<i4` and logical
#' values as `|b1`; missing values are not allowed.
#'
#' @family io
#' @export
#' @examples
#' path <- tempfile(fileext = ".npz")
#' cs_write_npz(list(x_um = c(1.5, 2.5), label = c("Tumour", "Treg")), path)
#' cs_read_npz(path)
#' cs_read_npz(path, arrays = "label")$label
cs_read_npy <- function(path) {
  .cs_check_file(path)
  size <- file.size(path)
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  .cs_npy_parse(readBin(con, "raw", n = size), source = path)
}

#' @rdname cs_read_npy
#' @export
cs_read_npz <- function(path, arrays = NULL) {
  .cs_check_file(path)
  listing <- tryCatch(
    utils::unzip(path, list = TRUE),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (is.null(listing) || !nrow(listing)) {
    .cs_abort(
      "{.file {path}} is not a readable .npz (zip) archive.",
      class = "cellspec_error_format"
    )
  }
  members <- listing$Name[grepl("\\.npy$", listing$Name)]
  available <- sub("\\.npy$", "", members)
  if (!is.null(arrays)) {
    if (!is.character(arrays) || anyNA(arrays) || anyDuplicated(arrays)) {
      .cs_abort("{.arg arrays} must be distinct array names.", class = "cellspec_error_argument")
    }
    missing <- setdiff(arrays, available)
    if (length(missing)) {
      .cs_abort(
        c(
          "{.file {path}} has no array{?s} {.val {missing}}.",
          "i" = "Available: {.val {available}}."
        ),
        class = "cellspec_error_format"
      )
    }
    keep <- match(arrays, available)
    members <- members[keep]
    available <- available[keep]
  }
  sizes <- listing$Length[match(members, listing$Name)]
  out <- vector("list", length(members))
  for (i in seq_along(members)) {
    con <- unz(path, members[[i]], open = "rb")
    bytes <- tryCatch(readBin(con, "raw", n = sizes[[i]]), finally = close(con))
    if (length(bytes) != sizes[[i]]) {
      .cs_abort(
        "Member {.val {members[[i]]}} of {.file {path}} is truncated.",
        class = "cellspec_error_format"
      )
    }
    out[[i]] <- .cs_npy_parse(bytes, source = paste0(path, ":", members[[i]]))
  }
  stats::setNames(out, available)
}

#' @rdname cs_read_npy
#' @export
cs_write_npy <- function(x, path) {
  .cs_check_path_arg(path)
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(.cs_npy_bytes(x), con)
  invisible(path)
}

#' @rdname cs_read_npy
#' @export
cs_write_npz <- function(x, path) {
  .cs_check_path_arg(path)
  if (!is.list(x) || is.data.frame(x) || !length(x) || is.null(names(x)) ||
    anyNA(names(x)) || !all(nzchar(names(x))) || anyDuplicated(names(x))) {
    .cs_abort(
      "{.arg x} must be a non-empty list with distinct names.",
      class = "cellspec_error_argument"
    )
  }
  if (any(grepl("[/\\\\]", names(x)))) {
    .cs_abort("Array names must not contain path separators.", class = "cellspec_error_argument")
  }
  members <- lapply(x, .cs_npy_bytes)
  .cs_zip_stored(stats::setNames(members, paste0(names(x), ".npy")), path)
  invisible(path)
}

# ---- reading ----------------------------------------------------------------

.cs_check_file <- function(path, call = rlang::caller_env()) {
  .cs_check_path_arg(path, call = call)
  if (!file.exists(path) || dir.exists(path)) {
    .cs_abort("File {.file {path}} does not exist.", class = "cellspec_error_io", call = call)
  }
}

.cs_check_path_arg <- function(path, call = rlang::caller_env()) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    .cs_abort("{.arg path} must be a single file path.", class = "cellspec_error_argument", call = call)
  }
}

.cs_npy_magic <- as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59))

.cs_npy_parse <- function(bytes, source, call = rlang::caller_env()) {
  bad <- function(why) {
    .cs_abort(
      c("{.file {source}} is not a supported .npy array.", "x" = why),
      class = "cellspec_error_format",
      call = call
    )
  }
  if (length(bytes) < 10L || !identical(bytes[1:6], .cs_npy_magic)) bad("Missing NumPy magic string.")
  major <- as.integer(bytes[[7L]])
  if (major == 1L) {
    header_len <- sum(as.integer(bytes[9:10]) * c(1, 256))
    start <- 11L
  } else if (major %in% c(2L, 3L)) {
    if (length(bytes) < 12L) bad("Truncated header.")
    header_len <- sum(as.integer(bytes[9:12]) * c(1, 256, 65536, 16777216))
    start <- 13L
  } else {
    bad(paste0("Unknown format version ", major, "."))
  }
  end <- start + header_len - 1
  if (end > length(bytes)) bad("Truncated header.")
  header <- rawToChar(bytes[start:end])
  if (major == 3L) Encoding(header) <- "UTF-8"
  spec <- .cs_npy_header(header, bad)
  type <- .cs_npy_dtype(spec$descr, bad)
  count <- if (length(spec$shape)) prod(spec$shape) else 1
  data <- if (end < length(bytes)) bytes[(end + 1L):length(bytes)] else raw()
  needed <- count * type$size
  if (length(data) < needed) bad("Array data are shorter than the header declares.")
  if (length(data) > needed) data <- data[seq_len(needed)]
  values <- .cs_npy_decode(data, type, count, bad)
  .cs_npy_shape(values, spec$shape, spec$fortran_order)
}

.cs_npy_header <- function(header, bad) {
  text <- trimws(header)
  descr <- regmatches(text, regexec("'descr'\\s*:\\s*'([^']*)'", text))[[1L]]
  if (length(descr) != 2L) {
    if (grepl("'descr'\\s*:\\s*\\[", text)) bad("Structured data types are not supported.")
    bad("The header has no data type.")
  }
  order <- regmatches(text, regexec("'fortran_order'\\s*:\\s*(True|False)", text))[[1L]]
  if (length(order) != 2L) bad("The header has no storage order.")
  shape <- regmatches(text, regexec("'shape'\\s*:\\s*\\(([^)]*)\\)", text))[[1L]]
  if (length(shape) != 2L) bad("The header has no shape.")
  dims <- trimws(strsplit(shape[[2L]], ",", fixed = TRUE)[[1L]])
  dims <- dims[nzchar(dims)]
  if (!all(grepl("^[0-9]+L?$", dims))) bad("The shape is not a tuple of integers.")
  list(
    descr = descr[[2L]],
    fortran_order = identical(order[[2L]], "True"),
    shape = as.numeric(sub("L$", "", dims))
  )
}

.cs_npy_dtype <- function(descr, bad) {
  m <- regmatches(descr, regexec("^([<>|=]?)([a-zA-Z])([0-9]*)$", descr))[[1L]]
  if (length(m) != 4L) bad(paste0("Unknown data type '", descr, "'."))
  order <- m[[2L]]
  kind <- m[[3L]]
  width <- if (nzchar(m[[4L]])) as.integer(m[[4L]]) else NA_integer_
  if (kind == "O") bad("Object arrays need Python's pickle and are not supported.")
  endian <- if (order == ">") "big" else if (order == "=") .Platform$endian else "little"
  size <- switch(kind,
    b = 1L,
    i = ,
    u = ,
    f = ,
    c = width,
    U = 4L * width,
    S = ,
    a = width,
    bad(paste0("Data type '", descr, "' is not supported."))
  )
  if (kind == "b" && !identical(width, 1L)) bad("Booleans must be one byte wide.")
  if (kind %in% c("i", "u") && !width %in% c(1L, 2L, 4L, 8L)) bad(paste0("Integer width ", width, " is not supported."))
  if (kind == "f" && !width %in% c(4L, 8L)) bad(paste0("Float width ", width, " is not supported."))
  if (kind == "c" && !identical(width, 16L)) bad("Only 128-bit complex numbers are supported.")
  if (kind %in% c("U", "S", "a") && (is.na(width) || width < 0L)) bad("String width is missing.")
  list(kind = kind, width = width, size = size, endian = endian)
}

.cs_npy_decode <- function(data, type, count, bad) {
  n <- as.integer(count)
  if (n == 0L) {
    return(switch(type$kind,
      b = logical(),
      i = ,
      u = if (type$width <= 2L || (type$kind == "i" && type$width == 4L)) integer() else double(),
      f = double(),
      c = complex(),
      character()
    ))
  }
  switch(type$kind,
    b = {
      if (any(data > as.raw(1L))) bad("Boolean values must be 0 or 1.")
      as.logical(as.integer(data))
    },
    i = .cs_npy_int(data, type, n, signed = TRUE, bad),
    u = .cs_npy_int(data, type, n, signed = FALSE, bad),
    f = readBin(data, "double", n = n, size = type$width, endian = type$endian),
    c = readBin(data, "complex", n = n, size = 16L, endian = type$endian),
    U = .cs_npy_unicode(data, type, n),
    S = ,
    a = .cs_npy_bytes_strings(data, type$width, n)
  )
}

.cs_npy_int <- function(data, type, n, signed, bad) {
  w <- type$width
  if (w <= 2L || (w == 4L && signed)) {
    return(readBin(data, "integer", n = n, size = w, signed = signed || w == 4L, endian = type$endian))
  }
  if (w == 4L) {
    v <- readBin(data, "integer", n = n, size = 4L, endian = type$endian)
    v <- as.double(v)
    v[v < 0] <- v[v < 0] + 2^32
    return(v)
  }
  # 8-byte integers: combine two 32-bit halves in double precision.
  halves <- readBin(data, "integer", n = 2L * n, size = 4L, endian = type$endian)
  halves <- as.double(halves)
  halves[halves < 0] <- halves[halves < 0] + 2^32
  pair <- matrix(halves, nrow = 2L)
  if (identical(type$endian, "little")) {
    low <- pair[1L, ]
    high <- pair[2L, ]
  } else {
    low <- pair[2L, ]
    high <- pair[1L, ]
  }
  if (signed) high[high >= 2^31] <- high[high >= 2^31] - 2^32
  if (any(abs(high) >= 2^21)) bad("64-bit integers beyond 2^53 cannot be represented exactly.")
  high * 2^32 + low
}

.cs_npy_unicode <- function(data, type, n) {
  w <- type$width
  if (w == 0L) {
    return(rep("", n))
  }
  b <- matrix(as.integer(data), nrow = 4L)
  if (identical(type$endian, "little")) {
    cp <- b[1L, ] + 256L * b[2L, ] + 65536L * b[3L, ] + 16777216 * b[4L, ]
  } else {
    cp <- b[4L, ] + 256L * b[3L, ] + 65536L * b[2L, ] + 16777216 * b[1L, ]
  }
  cp <- matrix(cp, nrow = w)
  lengths <- .cs_trimmed_lengths(cp != 0)
  if (all(cp < 128)) {
    bytes <- matrix(as.raw(cp), nrow = w)
    out <- vapply(seq_len(n), function(i) rawToChar(bytes[seq_len(lengths[[i]]), i]), character(1))
  } else {
    out <- vapply(seq_len(n), function(i) intToUtf8(cp[seq_len(lengths[[i]]), i]), character(1))
  }
  Encoding(out) <- "UTF-8"
  out
}

.cs_npy_bytes_strings <- function(data, width, n) {
  if (width == 0L) {
    return(rep("", n))
  }
  bytes <- matrix(data, nrow = width)
  lengths <- .cs_trimmed_lengths(bytes != as.raw(0L))
  vapply(seq_len(n), function(i) rawToChar(bytes[seq_len(lengths[[i]]), i]), character(1))
}

# Position of the last non-NUL element in each column (0 if none).
.cs_trimmed_lengths <- function(nonzero) {
  w <- nrow(nonzero)
  any_set <- colSums(nonzero) > 0
  last <- w - max.col(t(nonzero[w:1, , drop = FALSE]), ties.method = "first") + 1L
  as.integer(ifelse(any_set, last, 0L))
}

.cs_npy_shape <- function(values, shape, fortran_order) {
  k <- length(shape)
  if (k <= 1L) {
    return(values)
  }
  if (fortran_order) {
    dim(values) <- shape
    return(values)
  }
  dim(values) <- rev(shape)
  aperm(values, rev(seq_len(k)))
}

# ---- writing ----------------------------------------------------------------

.cs_npy_bytes <- function(x, call = rlang::caller_env()) {
  shape <- if (is.null(dim(x))) length(x) else dim(x)
  if (is.factor(x)) x <- as.character(x)
  if (!(is.logical(x) || is.integer(x) || is.double(x) || is.character(x)) || is.object(x)) {
    .cs_abort(
      "Only logical, integer, double or character vectors and arrays can be written.",
      class = "cellspec_error_argument",
      call = call
    )
  }
  if (anyNA(x)) {
    .cs_abort("Arrays with missing values cannot be written.", class = "cellspec_error_argument", call = call)
  }
  # Store in Fortran order: R's own column-major layout, no reordering.
  values <- as.vector(x)
  if (is.logical(x)) {
    descr <- "|b1"
    payload <- as.raw(as.integer(values))
  } else if (is.integer(x)) {
    descr <- "<i4"
    payload <- writeBin(values, raw(), size = 4L, endian = "little")
  } else if (is.double(x)) {
    descr <- "<f8"
    payload <- writeBin(values, raw(), size = 8L, endian = "little")
  } else {
    values <- enc2utf8(values)
    cps <- lapply(values, utf8ToInt)
    width <- max(1L, lengths(cps))
    descr <- paste0("<U", width)
    cp <- vapply(cps, function(v) c(v, integer(width - length(v))), integer(width))
    cp <- as.double(cp)
    payload <- as.raw(rbind(
      cp %% 256, (cp %/% 256) %% 256, (cp %/% 65536) %% 256, cp %/% 16777216
    ))
  }
  shape_text <- if (length(shape) == 1L) {
    paste0("(", shape, ",)")
  } else {
    paste0("(", paste(shape, collapse = ", "), ")")
  }
  header <- paste0(
    "{'descr': '", descr, "', 'fortran_order': ", if (length(shape) > 1L) "True" else "False",
    ", 'shape': ", shape_text, ", }"
  )
  # Pad with spaces so that magic + version + length + header is a multiple of 64.
  total <- 10L + nchar(header, type = "bytes") + 1L
  header <- paste0(header, strrep(" ", (64L - total %% 64L) %% 64L), "\n")
  len <- nchar(header, type = "bytes")
  c(
    .cs_npy_magic, as.raw(c(1L, 0L)), as.raw(c(len %% 256L, len %/% 256L)),
    charToRaw(header), payload
  )
}

# Minimal zip writer with stored (uncompressed) members; enough for .npz.
.cs_zip_stored <- function(members, path, call = rlang::caller_env()) {
  u16 <- function(v) writeBin(as.integer(v), raw(), size = 2L, endian = "little")
  u32 <- function(v) {
    v <- as.double(v)
    as.raw(c(v %% 256, (v %/% 256) %% 256, (v %/% 65536) %% 256, (v %/% 16777216) %% 256))
  }
  if (sum(lengths(members)) + 1e5 >= 2^32) {
    .cs_abort("Archives of 4 GB or more are not supported.", class = "cellspec_error_argument", call = call)
  }
  local <- list()
  central <- list()
  offset <- 0
  for (name in names(members)) {
    data <- members[[name]]
    fname <- charToRaw(enc2utf8(name))
    crc <- digest::digest(data, algo = "crc32", serialize = FALSE)
    crc <- paste0(strrep("0", 8L - nchar(crc)), crc)
    crc <- rev(as.raw(strtoi(substring(crc, seq(1, 7, 2), seq(2, 8, 2)), 16L)))
    common <- c(
      u16(20L), u16(0x0800), u16(0L), u16(0L), u16(0x21), crc,
      u32(length(data)), u32(length(data)), u16(length(fname)), u16(0L)
    )
    header <- c(as.raw(c(0x50, 0x4b, 0x03, 0x04)), common, fname)
    local[[name]] <- c(header, data)
    central[[name]] <- c(
      as.raw(c(0x50, 0x4b, 0x01, 0x02)), u16(20L), common,
      u16(0L), u16(0L), u16(0L), u32(0L), u32(offset), fname
    )
    offset <- offset + length(header) + length(data)
  }
  directory <- unlist(central, use.names = FALSE)
  end <- c(
    as.raw(c(0x50, 0x4b, 0x05, 0x06)), u16(0L), u16(0L),
    u16(length(members)), u16(length(members)), u32(length(directory)), u32(offset), u16(0L)
  )
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(c(unlist(local, use.names = FALSE), directory, end), con)
}
