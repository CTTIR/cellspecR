# Condition helpers. Every error carries `cellspec_error`, every warning
# `cellspec_warning`; most add one specific class from the list below, so
# callers can catch a failure by kind. Not exported.
#
# cellspec_error_ambiguous_format  cs_read(format = "auto") cannot choose.
# cellspec_error_argument          an argument has the wrong type or value.
# cellspec_error_collision         identifiers, keys or tiles clash.
# cellspec_error_format            input that cannot be read as expected,
#                                  including truncated or corrupt gzip data.
# cellspec_error_integrity         a cellspec directory fails its manifest
#                                  or DONE checks.
# cellspec_error_invalid           an object fails validation.
# cellspec_error_io                a file is missing.
# cellspec_error_units             unusable coordinates or units.
# cellspec_error_version           an unsupported specification version.
# cellspec_warning_integrity       data were read but not fully verified.

.cs_abort <- function(message,
                      class = NULL,
                      ...,
                      call = rlang::caller_env(),
                      .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(class, "cellspec_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

.cs_warn <- function(message,
                     class = NULL,
                     ...,
                     .envir = parent.frame()) {
  cli::cli_warn(
    message,
    class = c(class, "cellspec_warning"),
    ...,
    .envir = .envir
  )
}

.cs_inform <- function(message, quiet = FALSE, .envir = parent.frame()) {
  if (!isTRUE(quiet)) {
    cli::cli_inform(message, .envir = .envir)
  }
  invisible(NULL)
}

# Format up to `n` example values for a message, e.g. `"c1", "c2" and 3 more`.
.cs_examples <- function(x, n = 5L, quote = TRUE) {
  x <- unique(as.character(x))
  shown <- utils::head(x, n)
  q <- if (quote) "\"" else ""
  out <- paste0(q, shown, q, collapse = ", ")
  if (length(x) > n) {
    out <- paste0(out, " and ", length(x) - n, " more")
  }
  out
}
