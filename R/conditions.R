# Condition helpers. Every error carries `cellspec_error` plus one specific
# class from the list in the specification, every warning `cellspec_warning`,
# so callers can catch a failure by kind. Not exported.

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
