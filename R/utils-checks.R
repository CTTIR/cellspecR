# Internal input-validation helpers. All take `arg` (the argument name as the
# user wrote it) and `call` (the user-facing call environment) so the resulting
# message points at the user's code, not at this helper. Not exported.

.cs_check_string <- function(x,
                             allow_null = FALSE,
                             arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    .cs_abort(
      c("{.arg {arg}} must be a single non-empty string.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_flag <- function(x,
                           arg = rlang::caller_arg(x),
                           call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .cs_abort(
      c("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_number <- function(x,
                             min = -Inf,
                             allow_null = FALSE,
                             arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < min) {
    .cs_abort(
      c("{.arg {arg}} must be a single finite number >= {min}.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_count <- function(x,
                            min = 0L,
                            arg = rlang::caller_arg(x),
                            call = rlang::caller_env()) {
  ok <- is.numeric(x) && length(x) == 1L && is.finite(x) &&
    x == round(x) && x >= min
  if (!ok) {
    .cs_abort(
      c("{.arg {arg}} must be a single whole number >= {min}.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_choice <- function(x,
                             choices,
                             arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  .cs_check_string(x, arg = arg, call = call)
  if (!x %in% choices) {
    .cs_abort(
      c("{.arg {arg}} must be one of {.or {.val {choices}}}.",
        "x" = "Got {.val {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_path <- function(path,
                           arg = rlang::caller_arg(path),
                           call = rlang::caller_env()) {
  .cs_check_string(path, arg = arg, call = call)
  if (!file.exists(path)) {
    .cs_abort(
      c("{.arg {arg}} must be an existing file or directory.",
        "x" = "{.path {path}} does not exist."),
      class = "cellspec_error_format",
      call = call
    )
  }
  invisible(path)
}

.cs_check_data_frame <- function(x,
                                 allow_null = FALSE,
                                 arg = rlang::caller_arg(x),
                                 call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(x))
  }
  if (!is.data.frame(x)) {
    .cs_abort(
      c("{.arg {arg}} must be a data frame.",
        "x" = "Got {.obj_type_friendly {x}}."),
      call = call
    )
  }
  invisible(x)
}

.cs_check_cellspec <- function(x,
                               arg = rlang::caller_arg(x),
                               call = rlang::caller_env()) {
  if (!inherits(x, "cellspec")) {
    .cs_abort(
      c("{.arg {arg}} must be a {.cls cellspec} object.",
        "x" = "Got {.obj_type_friendly {x}}.",
        "i" = "Build one with {.fn cs_new} or {.fn cs_read}."),
      call = call
    )
  }
  invisible(x)
}
