# Validation of cellspec objects against the specification.
#
# Every check has one row in `.cs_checks()`. The report starts with every
# check marked "skip" and each check that can run overwrites its row, so a
# check whose prerequisite failed is reported as not run rather than passed,
# and one defect produces one "fail".

.cs_checks <- function() {
  rows <- list(
    c("object_class", "structure", "The object is a list of class `cellspec`."),
    c("object_components", "structure", "All components exist and have the right container type."),
    c("spec_version", "structure", "`spec_version` is a version string with a supported major version."),
    c("cells_required_columns", "structure", "`cells` has every MUST column and no duplicated names."),
    c("cells_column_types", "structure", "Specified `cells` columns have their specified types."),
    c("cells_reserved_names", "structure", "No `cs__` columns; region layer names are valid."),
    c("cells_subject_id", "structure", "`cells` carries no `subject_id` (it belongs in `images`)."),
    c("cells_ids_present", "structure", "`cell_id`, `image_id` and `sample_id` are non-missing and non-empty."),
    c("cells_key_unique", "structure", "`(image_id, cell_id)` is unique."),
    c("cells_coordinates_finite", "structure", "`x` and `y` are finite."),
    c("cells_area_positive", "structure", "`area` is positive or `NA`."),
    c("cells_images_known", "structure", "Every `cells$image_id` exists in `images`."),
    c("cells_sample_consistent", "structure", "`cells$sample_id` equals the `sample_id` of its image."),
    c("measurements_type", "structure", "`measurements` is a double matrix."),
    c("measurements_rows", "structure", "`measurements` has one row per cell."),
    c("measurements_names", "structure", "Measurement column names equal `dictionary$feature_id`, in order."),
    c("measurements_finite", "structure", "`measurements` holds no `NaN` or infinite values."),
    c("dictionary_required_columns", "structure", "`dictionary` has every MUST column."),
    c("dictionary_column_types", "structure", "`dictionary` columns are character."),
    c("dictionary_feature_id_unique", "structure", "`feature_id` is non-missing and unique."),
    c("dictionary_kind", "structure", "`kind` is `intensity`, `shape` or `other`."),
    c("dictionary_intensity", "structure", "Intensity features have a marker, a compartment and an intensity statistic."),
    c("dictionary_shape", "structure", "Shape features have a compartment, a shape statistic and no marker."),
    c("dictionary_other", "structure", "Other features have a statistic and no marker."),
    c("dictionary_unit", "structure", "`unit` is from the unit vocabulary."),
    c("dictionary_marker_names", "structure", "Marker names are trimmed, non-empty and contain no `:`."),
    c("dictionary_feature_id_format", "structure", "`feature_id` follows the naming rule of its kind (so no two features share kind, marker, compartment and statistic)."),
    c("dictionary_source_name", "structure", "`source_name` is non-missing and non-empty."),
    c("images_required_columns", "structure", "`images` has every MUST column."),
    c("images_column_types", "structure", "Specified `images` columns have their specified types."),
    c("images_id_unique", "structure", "`image_id` is non-missing, non-empty and unique."),
    c("images_sample_present", "structure", "`images$sample_id` is non-missing and non-empty."),
    c("images_pixel_size", "structure", "`pixel_size` (and `pixel_size_y`) is finite and positive."),
    c("images_dimensions", "structure", "`width_px` and `height_px` are positive or `NA`."),
    c("channels_required_columns", "structure", "`channels` has every MUST column."),
    c("channels_column_types", "structure", "`channels` columns have their specified types."),
    c("channels_images_known", "structure", "Every `channels$image_id` exists in `images`."),
    c("channels_index_contiguous", "structure", "`channel_index` is 1, 2, ..., n within each image."),
    c("channels_names", "structure", "Channel names and markers are non-empty; markers are unique per image."),
    c("markers_in_channels", "structure", "Every intensity marker is a channel marker of every image."),
    c("provenance_fields", "structure", "`provenance` has every required field."),
    c("adjacency_columns", "structure", "`adjacency` has every MUST column with its type."),
    c("adjacency_endpoints", "structure", "Both cells of every contact exist in `cells`."),
    c("adjacency_pairs", "structure", "Pairs are ordered (`cell_id_a < cell_id_b`) and listed once."),
    c("adjacency_values", "structure", "`shared_boundary` is finite and non-negative; `method` is known."),
    c("centroids_within_image", "semantic", "Centroids lie inside the image extent (1 pixel tolerance)."),
    c("area_range", "semantic", "`area` lies inside `area_range`."),
    c("negative_intensity", "semantic", "Intensity features hold no negative values."),
    c("feature_na_fraction", "semantic", "No feature has more than `na_max` missing values."),
    c("feature_support", "semantic", "Mean intensity features have usable variation in every image."),
    c("duplicate_centroids", "semantic", "No two cells of one image share a centroid.")
  )
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(out) <- c("check", "level", "description")
  out
}

#' Validate a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `cs_validate()` checks an object against the `cellspec` specification and
#' returns a report with one row per check. `cs_assert_valid()` runs the same
#' checks and aborts when any check fails.
#'
#' `level = "structure"` runs the MUST rules of the specification: required
#' columns and types, unique keys, finite centroids, dictionary vocabulary,
#' alignment of measurements, channels and optional adjacency. A failing
#' structure check means other packages cannot rely on the object.
#'
#' `level = "semantic"` adds plausibility checks that produce warnings, not
#' failures: centroids outside the image, implausible cell areas, negative
#' intensities, features with many missing values, markers without usable
#' signal ([cs_feature_support()]) and duplicated centroids, which usually
#' indicate cells counted twice when tiles were merged.
#'
#' @param x A `cellspec` object.
#' @param level `"structure"` or `"semantic"` (structure plus semantic
#'   checks).
#' @param area_range Numeric vector of length 2: plausible whole-cell area in
#'   square micrometres for the `area_range` check.
#' @param na_max Largest acceptable fraction of missing values per feature
#'   for the `feature_na_fraction` check.
#' @return `cs_validate()` returns a data frame of class
#'   `cellspec_validation` with one row per check and the columns `check`
#'   (character), `level` (`"structure"` or `"semantic"`), `status` (`"pass"`,
#'   `"warn"`, `"fail"`, or `"skip"` when a prerequisite check failed), `n`
#'   (integer number of offending rows, features or values) and `message`
#'   (character, naming columns or features and up to five examples).
#'   Rows are in catalogue order; `print()` shows failures first.
#'
#'   `cs_assert_valid()` returns `x` invisibly, or aborts with an error of
#'   class `cellspec_error_invalid` whose `report` field holds the report.
#' @family validation
#' @seealso `vignette("specification", package = "cellspecR")`
#' @export
#' @examples
#' x <- cs_example()
#' cs_validate(x)
#' report <- cs_validate(x, level = "semantic")
#' report[report$status != "pass", ]
#'
#' # A broken object fails with a classed error
#' bad <- x
#' bad$cells$x[1] <- NA
#' try(cs_assert_valid(bad))
cs_validate <- function(x, level = c("structure", "semantic"),
                        area_range = c(1, 5000), na_max = 0.01) {
  level <- rlang::arg_match(level)
  if (!is.numeric(area_range) || length(area_range) != 2L ||
    anyNA(area_range) || area_range[[1L]] > area_range[[2L]]) {
    .cs_abort(c(
      "{.arg area_range} must be two increasing numbers.",
      "x" = "Got {.obj_type_friendly {area_range}}."
    ))
  }
  .cs_check_number(na_max, min = 0)

  catalogue <- .cs_checks()
  report <- data.frame(
    check = catalogue$check,
    level = catalogue$level,
    status = "skip",
    n = 0L,
    message = "Not run: a prerequisite check failed.",
    stringsAsFactors = FALSE
  )
  rec <- .cs_recorder(report)
  .cs_validate_structure(x, rec)
  if (level == "semantic") {
    if (any(rec$report()$status == "fail")) {
      rec$note_semantic("Not run: structure checks failed.")
    } else {
      .cs_validate_semantic(x, rec, area_range = area_range, na_max = na_max)
    }
  } else {
    rec$drop_semantic()
  }
  out <- rec$report()
  attr(out, "row.names") <- .set_row_names(nrow(out))
  class(out) <- c("cellspec_validation", "data.frame")
  out
}

#' @rdname cs_validate
#' @param call The execution environment used in error messages; internal
#'   callers pass their own.
#' @export
cs_assert_valid <- function(x, level = "structure", call = rlang::caller_env()) {
  report <- cs_validate(x, level = level)
  fails <- report[report$status == "fail", , drop = FALSE]
  if (nrow(fails) > 0L) {
    shown <- utils::head(fails, 10L)
    bullets <- stats::setNames(
      paste0("{.field ", shown$check, "}: ", .cs_cli_escape(shown$message)),
      rep("x", nrow(shown))
    )
    if (nrow(fails) > nrow(shown)) {
      bullets <- c(bullets, "i" = "{nrow(fails) - nrow(shown)} more failing check{?s}; run {.fn cs_validate} for the full report.")
    }
    .cs_abort(
      c("{.arg x} is not a valid {.cls cellspec} object ({nrow(fails)} failing check{?s}).",
        bullets),
      class = "cellspec_error_invalid",
      report = report,
      call = call
    )
  }
  invisible(x)
}

.cs_cli_escape <- function(x) {
  x <- gsub("{", "{{", x, fixed = TRUE)
  gsub("}", "}}", x, fixed = TRUE)
}

# Mutable report shared by the check functions.
.cs_recorder <- function(report) {
  env <- new.env(parent = emptyenv())
  env$report <- report
  set <- function(check, status, n, message) {
    i <- match(check, env$report$check)
    env$report$status[[i]] <- status
    env$report$n[[i]] <- as.integer(n)
    env$report$message[[i]] <- message
    invisible(status)
  }
  list(
    pass = function(check, message, n = 0L) set(check, "pass", n, message),
    fail = function(check, n, message) set(check, "fail", n, message),
    warn = function(check, n, message) set(check, "warn", n, message),
    # Record a check that fails when `n > 0` and passes otherwise.
    test = function(check, n, fail_message, pass_message, status = "fail") {
      if (n > 0L) set(check, status, n, fail_message) else set(check, "pass", 0L, pass_message)
    },
    status = function(check) env$report$status[[match(check, env$report$check)]],
    ok = function(...) all(vapply(c(...), function(ch) env$report$status[[match(ch, env$report$check)]] == "pass", logical(1))),
    report = function() env$report,
    note_semantic = function(message) {
      sem <- env$report$level == "semantic"
      env$report$message[sem] <- message
    },
    drop_semantic = function() {
      env$report <- env$report[env$report$level == "structure", , drop = FALSE]
    }
  )
}

.cs_is_blank <- function(v) {
  is.na(v) | !nzchar(v)
}

.cs_key <- function(image_id, cell_id) {
  paste(image_id, cell_id, sep = "\r")
}

.cs_key_label <- function(image_id, cell_id) {
  if (length(image_id) == 0L) {
    return(character())
  }
  paste0(image_id, "/", cell_id)
}

.cs_type_ok <- function(col, type) {
  switch(type,
    character = is.character(col),
    double = is.double(col),
    integer = is.integer(col),
    FALSE
  )
}

# Returns the names of specified columns present with the wrong type.
.cs_wrong_types <- function(df, component) {
  types <- .cs_column_types(component)
  present <- intersect(names(types), names(df))
  bad <- present[!vapply(present, function(nm) .cs_type_ok(df[[nm]], types[[nm]]), logical(1))]
  if (component == "cells") {
    reg <- grep("^region__", names(df), value = TRUE)
    bd <- grep("^boundary_distance__", names(df), value = TRUE)
    bad <- c(
      bad,
      reg[!vapply(reg, function(nm) is.character(df[[nm]]), logical(1))],
      bd[!vapply(bd, function(nm) is.double(df[[nm]]), logical(1))]
    )
  }
  bad
}

.cs_type_message <- function(df, bad, component) {
  types <- .cs_column_types(component)
  expected <- vapply(bad, function(nm) {
    if (nm %in% names(types)) types[[nm]] else if (grepl("^region__", nm)) "character" else "double"
  }, character(1))
  observed <- vapply(bad, function(nm) class(df[[nm]])[[1L]], character(1))
  paste0(
    length(bad), " column", if (length(bad) == 1L) "" else "s",
    " of `", component, "` ", if (length(bad) == 1L) "has" else "have",
    " the wrong type: ",
    paste0("`", bad, "` (", observed, ", expected ", expected, ")", collapse = ", "),
    "."
  )
}

.cs_validate_structure <- function(x, rec) {
  # Object ----------------------------------------------------------------
  if (!is.list(x) || !inherits(x, "cellspec")) {
    rec$fail("object_class", 1L, paste0(
      "Object is of class `", class(x)[[1L]], "`, not `cellspec`."
    ))
    return(invisible())
  }
  rec$pass("object_class", "Object is a list of class `cellspec`.")

  expected <- list(
    spec_version = is.character,
    cells = is.data.frame,
    measurements = is.matrix,
    dictionary = is.data.frame,
    images = is.data.frame,
    channels = is.data.frame,
    provenance = is.list
  )
  missing <- setdiff(names(expected), names(x))
  wrong <- setdiff(names(expected), missing)
  wrong <- wrong[!vapply(wrong, function(nm) expected[[nm]](x[[nm]]), logical(1))]
  if (!is.null(x$adjacency) && !is.data.frame(x$adjacency)) {
    wrong <- c(wrong, "adjacency")
  }
  if (length(missing) + length(wrong) > 0L) {
    msg <- character()
    if (length(missing) > 0L) {
      msg <- c(msg, paste0("missing: ", paste0("`", missing, "`", collapse = ", ")))
    }
    if (length(wrong) > 0L) {
      msg <- c(msg, paste0("wrong container type: ", paste0("`", wrong, "`", collapse = ", ")))
    }
    rec$fail("object_components", length(missing) + length(wrong), paste0(
      "Components ", paste(msg, collapse = "; "), "."
    ))
    return(invisible())
  }
  rec$pass("object_components", "All components are present.")

  sv <- x$spec_version
  if (length(sv) != 1L || is.na(sv) || !grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", sv)) {
    rec$fail("spec_version", 1L, "`spec_version` must be a single version string such as \"1.0.0\".")
  } else if (strsplit(sv, ".", fixed = TRUE)[[1L]][[1L]] != "1") {
    rec$fail("spec_version", 1L, paste0(
      "`spec_version` \"", sv, "\" has an unsupported major version; this build supports 1.x."
    ))
  } else {
    rec$pass("spec_version", paste0("Specification version ", sv, "."))
  }

  cells <- x$cells
  images <- x$images
  dict <- x$dictionary
  channels <- x$channels
  m <- x$measurements

  .cs_validate_images(images, rec)
  .cs_validate_cells(cells, images, rec)
  .cs_validate_dictionary(dict, rec)
  .cs_validate_measurements(m, cells, dict, rec)
  .cs_validate_channels(channels, images, dict, rec)
  .cs_validate_provenance(x$provenance, rec)
  .cs_validate_adjacency(x$adjacency, cells, rec)
  invisible()
}

.cs_validate_images <- function(images, rec) {
  req <- .cs_required_columns("images")
  miss <- setdiff(req, names(images))
  if (length(miss) > 0L) {
    rec$fail("images_required_columns", length(miss), paste0(
      "`images` lacks required column", if (length(miss) > 1L) "s", ": ",
      paste0("`", miss, "`", collapse = ", "), "."
    ))
    return(invisible())
  }
  rec$pass("images_required_columns", "`images` has all required columns.")

  bad <- .cs_wrong_types(images, "images")
  if (length(bad) > 0L) {
    rec$fail("images_column_types", length(bad), .cs_type_message(images, bad, "images"))
    return(invisible())
  }
  rec$pass("images_column_types", "`images` columns have their specified types.")

  ids <- images$image_id
  blank <- .cs_is_blank(ids)
  dup <- duplicated(ids) & !blank
  n_bad <- sum(blank) + sum(dup)
  rec$test("images_id_unique", n_bad,
    fail_message = paste0(
      n_bad, " `images` row", if (n_bad != 1L) "s", " with a missing or duplicated `image_id`",
      if (any(dup)) paste0(", e.g. ", .cs_examples(ids[dup])), "."
    ),
    pass_message = paste0("All ", length(ids), " `image_id` values are unique.")
  )

  blank_s <- .cs_is_blank(images$sample_id)
  rec$test("images_sample_present", sum(blank_s),
    fail_message = paste0(
      sum(blank_s), " image", if (sum(blank_s) != 1L) "s", " without `sample_id`, e.g. ",
      .cs_examples(ids[blank_s]), "."
    ),
    pass_message = "Every image has a `sample_id`."
  )

  ps_bad <- !(is.finite(images$pixel_size) & images$pixel_size > 0)
  if ("pixel_size_y" %in% names(images)) {
    psy <- images$pixel_size_y
    ps_bad <- ps_bad | (!is.na(psy) & !(is.finite(psy) & psy > 0))
  }
  rec$test("images_pixel_size", sum(ps_bad),
    fail_message = paste0(
      sum(ps_bad), " image", if (sum(ps_bad) != 1L) "s", " with a missing or non-positive `pixel_size`, e.g. ",
      .cs_examples(ids[ps_bad]), "."
    ),
    pass_message = "Every image has a positive `pixel_size`."
  )

  dim_bad <- rep(FALSE, nrow(images))
  for (nm in intersect(c("width_px", "height_px"), names(images))) {
    v <- images[[nm]]
    dim_bad <- dim_bad | (!is.na(v) & v <= 0L)
  }
  rec$test("images_dimensions", sum(dim_bad),
    fail_message = paste0(
      sum(dim_bad), " image", if (sum(dim_bad) != 1L) "s", " with non-positive `width_px` or `height_px`, e.g. ",
      .cs_examples(ids[dim_bad]), "."
    ),
    pass_message = "Image dimensions are positive or missing."
  )
  invisible()
}

.cs_validate_cells <- function(cells, images, rec) {
  req <- .cs_required_columns("cells")
  miss <- setdiff(req, names(cells))
  dup_names <- unique(names(cells)[duplicated(names(cells))])
  if (length(miss) + length(dup_names) > 0L) {
    msg <- character()
    if (length(miss) > 0L) {
      msg <- c(msg, paste0("lacks required column", if (length(miss) > 1L) "s", ": ", paste0("`", miss, "`", collapse = ", ")))
    }
    if (length(dup_names) > 0L) {
      msg <- c(msg, paste0("has duplicated column names: ", paste0("`", dup_names, "`", collapse = ", ")))
    }
    rec$fail("cells_required_columns", length(miss) + length(dup_names), paste0(
      "`cells` ", paste(msg, collapse = " and "), "."
    ))
    return(invisible())
  }
  rec$pass("cells_required_columns", "`cells` has all required columns.")

  bad <- .cs_wrong_types(cells, "cells")
  types_ok <- length(bad) == 0L
  if (!types_ok) {
    rec$fail("cells_column_types", length(bad), .cs_type_message(cells, bad, "cells"))
  } else {
    rec$pass("cells_column_types", "`cells` columns have their specified types.")
  }

  nms <- names(cells)
  internal <- grep("^cs__", nms, value = TRUE)
  layered <- grep("^(region|boundary_distance)__", nms, value = TRUE)
  layers <- sub("^(region|boundary_distance)__", "", layered)
  bad_layers <- layered[!grepl(.cs_layer_pattern, layers)]
  n_res <- length(internal) + length(bad_layers)
  rec$test("cells_reserved_names", n_res,
    fail_message = paste0(
      n_res, " `cells` column name", if (n_res != 1L) "s", " violate", if (n_res == 1L) "s",
      " the reserved-name rules: ", paste0("`", c(internal, bad_layers), "`", collapse = ", "),
      ". `cs__` is internal; layer names must match ", .cs_layer_pattern, "."
    ),
    pass_message = "No reserved column names are misused."
  )

  rec$test("cells_subject_id", as.integer("subject_id" %in% nms),
    fail_message = "`cells` has a `subject_id` column; subject identifiers belong in `images`.",
    pass_message = "`cells` carries no subject identifiers."
  )

  if (!types_ok && any(c("cell_id", "image_id", "sample_id", "x", "y", "area") %in% bad)) {
    # Value checks below assume the specified types.
    return(invisible())
  }

  blank <- .cs_is_blank(cells$cell_id) | .cs_is_blank(cells$image_id) | .cs_is_blank(cells$sample_id)
  rec$test("cells_ids_present", sum(blank),
    fail_message = paste0(
      sum(blank), " row", if (sum(blank) != 1L) "s", " of `cells` with a missing or empty `cell_id`, `image_id` or `sample_id` (rows ",
      .cs_examples(which(blank), quote = FALSE), ")."
    ),
    pass_message = "All identifiers are present."
  )

  keys <- .cs_key(cells$image_id, cells$cell_id)
  dup <- duplicated(keys) & !blank
  n_dup <- sum(keys %in% keys[dup] & !blank)
  rec$test("cells_key_unique", n_dup,
    fail_message = paste0(
      n_dup, " rows of `cells` share an `(image_id, cell_id)` key with another row, e.g. ",
      .cs_examples(.cs_key_label(cells$image_id[dup], cells$cell_id[dup])), "."
    ),
    pass_message = paste0("All ", nrow(cells), " `(image_id, cell_id)` keys are unique.")
  )

  nonfinite <- !is.finite(cells$x) | !is.finite(cells$y)
  rec$test("cells_coordinates_finite", sum(nonfinite),
    fail_message = paste0(
      sum(nonfinite), " cell", if (sum(nonfinite) != 1L) "s", " with a missing or non-finite `x` or `y`, e.g. ",
      .cs_examples(.cs_key_label(cells$image_id[nonfinite], cells$cell_id[nonfinite])), "."
    ),
    pass_message = "All centroids are finite."
  )

  if ("area" %in% nms) {
    a <- cells$area
    bad_area <- !is.na(a) & !(is.finite(a) & a > 0)
    rec$test("cells_area_positive", sum(bad_area),
      fail_message = paste0(
        sum(bad_area), " cell", if (sum(bad_area) != 1L) "s", " with a non-positive or infinite `area`, e.g. ",
        .cs_examples(.cs_key_label(cells$image_id[bad_area], cells$cell_id[bad_area])), "."
      ),
      pass_message = "All areas are positive or missing."
    )
  } else {
    rec$pass("cells_area_positive", "`cells` has no `area` column.")
  }

  if (rec$ok("images_required_columns", "images_column_types")) {
    unknown <- !cells$image_id %in% images$image_id & !.cs_is_blank(cells$image_id)
    rec$test("cells_images_known", sum(unknown),
      fail_message = paste0(
        sum(unknown), " cell", if (sum(unknown) != 1L) "s refer" else " refers", " to `image_id` values missing from `images`: ",
        .cs_examples(cells$image_id[unknown]), "."
      ),
      pass_message = "Every cell refers to a known image."
    )
    idx <- match(cells$image_id, images$image_id)
    known <- !is.na(idx) & !.cs_is_blank(cells$sample_id) &
      !.cs_is_blank(images$sample_id[idx])
    mismatch <- known & !(cells$sample_id == images$sample_id[idx]) %in% TRUE
    rec$test("cells_sample_consistent", sum(mismatch),
      fail_message = paste0(
        sum(mismatch), " cell", if (sum(mismatch) != 1L) "s", " whose `sample_id` differs from the `sample_id` of their image, e.g. ",
        .cs_examples(.cs_key_label(cells$image_id[mismatch], cells$cell_id[mismatch])), "."
      ),
      pass_message = "Cell and image sample identifiers agree."
    )
  }
  invisible()
}

.cs_validate_dictionary <- function(dict, rec) {
  req <- .cs_required_columns("dictionary")
  miss <- setdiff(req, names(dict))
  if (length(miss) > 0L) {
    rec$fail("dictionary_required_columns", length(miss), paste0(
      "`dictionary` lacks required column", if (length(miss) > 1L) "s", ": ",
      paste0("`", miss, "`", collapse = ", "), "."
    ))
    return(invisible())
  }
  rec$pass("dictionary_required_columns", "`dictionary` has all required columns.")

  bad <- .cs_wrong_types(dict, "dictionary")
  if (length(bad) > 0L) {
    rec$fail("dictionary_column_types", length(bad), .cs_type_message(dict, bad, "dictionary"))
    return(invisible())
  }
  rec$pass("dictionary_column_types", "`dictionary` columns are character.")

  fid <- dict$feature_id
  blank <- .cs_is_blank(fid)
  dup <- duplicated(fid) & !blank
  n_bad <- sum(blank) + sum(dup)
  rec$test("dictionary_feature_id_unique", n_bad,
    fail_message = paste0(
      n_bad, " dictionary row", if (n_bad != 1L) "s", " with a missing or duplicated `feature_id`",
      if (any(dup)) paste0(", e.g. ", .cs_examples(fid[dup])), "."
    ),
    pass_message = paste0("All ", length(fid), " feature identifiers are unique.")
  )

  kinds <- .cs_vocab_values("kind")
  bad_kind <- !dict$kind %in% kinds
  rec$test("dictionary_kind", sum(bad_kind),
    fail_message = paste0(
      sum(bad_kind), " feature", if (sum(bad_kind) != 1L) "s", " with an unknown `kind`, e.g. ",
      .cs_examples(fid[bad_kind]), " (kinds: ", .cs_examples(dict$kind[bad_kind]), ")."
    ),
    pass_message = "All feature kinds are known."
  )

  comps <- .cs_vocab_values("compartment")
  is_int <- dict$kind %in% "intensity"
  is_shape <- dict$kind %in% "shape"
  is_other <- dict$kind %in% "other"

  int_bad <- is_int & (.cs_is_blank(dict$marker) | !dict$compartment %in% comps |
    !dict$statistic %in% .cs_vocab_values("intensity_statistic"))
  rec$test("dictionary_intensity", sum(int_bad),
    fail_message = paste0(
      sum(int_bad), " intensity feature", if (sum(int_bad) != 1L) "s", " without a marker, or with a compartment or statistic outside the vocabulary: ",
      .cs_examples(fid[int_bad]), "."
    ),
    pass_message = "Intensity features are fully described."
  )

  shape_bad <- is_shape & (!is.na(dict$marker) | !dict$compartment %in% comps |
    !dict$statistic %in% .cs_vocab_values("shape_statistic"))
  rec$test("dictionary_shape", sum(shape_bad),
    fail_message = paste0(
      sum(shape_bad), " shape feature", if (sum(shape_bad) != 1L) "s", " with a marker, or with a compartment or statistic outside the vocabulary: ",
      .cs_examples(fid[shape_bad]), "."
    ),
    pass_message = "Shape features are fully described."
  )

  other_bad <- is_other & (!is.na(dict$marker) | .cs_is_blank(dict$statistic) |
    !(is.na(dict$compartment) | dict$compartment %in% comps))
  rec$test("dictionary_other", sum(other_bad),
    fail_message = paste0(
      sum(other_bad), " other feature", if (sum(other_bad) != 1L) "s", " with a marker, an unknown compartment or no statistic: ",
      .cs_examples(fid[other_bad]), "."
    ),
    pass_message = "Other features are fully described."
  )

  unit_bad <- !dict$unit %in% .cs_vocab_values("unit")
  rec$test("dictionary_unit", sum(unit_bad),
    fail_message = paste0(
      sum(unit_bad), " feature", if (sum(unit_bad) != 1L) "s", " with a unit outside the vocabulary, e.g. ",
      .cs_examples(fid[unit_bad]), " (units: ", .cs_examples(dict$unit[unit_bad]), ")."
    ),
    pass_message = "All units are from the vocabulary."
  )

  mk <- dict$marker
  mk_bad <- !is.na(mk) & (!nzchar(trimws(mk)) | mk != trimws(mk) | grepl(":", mk, fixed = TRUE))
  rec$test("dictionary_marker_names", sum(mk_bad),
    fail_message = paste0(
      sum(mk_bad), " feature", if (sum(mk_bad) != 1L) "s", " with an empty, untrimmed or colon-containing marker name: ",
      .cs_examples(mk[mk_bad]), "."
    ),
    pass_message = "Marker names are well formed."
  )

  expected_id <- rep(NA_character_, nrow(dict))
  expected_id[is_int] <- paste(dict$compartment[is_int], dict$marker[is_int], dict$statistic[is_int], sep = ":")
  expected_id[is_shape] <- paste(dict$compartment[is_shape], dict$statistic[is_shape], sep = ":")
  fid_chr <- fid
  fid_chr[is.na(fid_chr)] <- ""
  fmt_bad <- ((is_int | is_shape) & !(fid == expected_id) %in% TRUE) |
    (is_other & !startsWith(fid_chr, "other:"))
  rec$test("dictionary_feature_id_format", sum(fmt_bad),
    fail_message = paste0(
      sum(fmt_bad), " feature identifier", if (sum(fmt_bad) != 1L) "s", " not following `<compartment>:<marker>:<statistic>`, `<compartment>:<statistic>` or `other:<name>`: ",
      .cs_examples(fid[fmt_bad]), "."
    ),
    pass_message = "Feature identifiers follow the naming rule."
  )

  src_bad <- .cs_is_blank(dict$source_name)
  rec$test("dictionary_source_name", sum(src_bad),
    fail_message = paste0(
      sum(src_bad), " feature", if (sum(src_bad) != 1L) "s", " without `source_name`: ",
      .cs_examples(fid[src_bad]), "."
    ),
    pass_message = "Every feature records its original header."
  )
  invisible()
}

.cs_validate_measurements <- function(m, cells, dict, rec) {
  if (!is.double(m)) {
    rec$fail("measurements_type", 1L, paste0(
      "`measurements` has storage type ", typeof(m), "; it must be double."
    ))
    return(invisible())
  }
  rec$pass("measurements_type", "`measurements` is a double matrix.")

  if (nrow(m) != nrow(cells)) {
    rec$fail("measurements_rows", abs(nrow(m) - nrow(cells)), paste0(
      "`measurements` has ", nrow(m), " rows but `cells` has ", nrow(cells), "."
    ))
  } else {
    rec$pass("measurements_rows", paste0("`measurements` has one row for each of the ", nrow(cells), " cells."))
  }

  if (rec$ok("dictionary_required_columns", "dictionary_column_types")) {
    cn <- colnames(m)
    if (is.null(cn)) cn <- character()
    fid <- dict$feature_id
    if (!identical(cn, fid)) {
      extra <- setdiff(cn, fid)
      absent <- setdiff(fid, cn)
      n_bad <- max(length(extra) + length(absent), 1L)
      detail <- character()
      if (length(extra) > 0L) detail <- c(detail, paste0("not in dictionary: ", .cs_examples(extra)))
      if (length(absent) > 0L) detail <- c(detail, paste0("missing from measurements: ", .cs_examples(absent)))
      if (length(detail) == 0L) detail <- "same features in a different order"
      rec$fail("measurements_names", n_bad, paste0(
        "Measurement column names do not equal `dictionary$feature_id` (", paste(detail, collapse = "; "), ")."
      ))
    } else {
      rec$pass("measurements_names", paste0("All ", length(fid), " measurement columns are described in order."))
    }
  }

  bad <- is.nan(m) | (!is.na(m) & !is.finite(m))
  n_bad <- sum(bad)
  if (n_bad > 0L) {
    cols <- colnames(m)[colSums(bad) > 0L]
    rec$fail("measurements_finite", n_bad, paste0(
      n_bad, " `NaN` or infinite value", if (n_bad != 1L) "s", " in `measurements`, in feature",
      if (length(cols) != 1L) "s", " ", .cs_examples(cols), "; convert them to `NA`."
    ))
  } else {
    rec$pass("measurements_finite", "`measurements` holds no `NaN` or infinite values.")
  }
  invisible()
}

.cs_validate_channels <- function(channels, images, dict, rec) {
  req <- .cs_required_columns("channels")
  miss <- setdiff(req, names(channels))
  if (length(miss) > 0L) {
    rec$fail("channels_required_columns", length(miss), paste0(
      "`channels` lacks required column", if (length(miss) > 1L) "s", ": ",
      paste0("`", miss, "`", collapse = ", "), "."
    ))
    return(invisible())
  }
  rec$pass("channels_required_columns", "`channels` has all required columns.")

  bad <- .cs_wrong_types(channels, "channels")
  if (length(bad) > 0L) {
    rec$fail("channels_column_types", length(bad), .cs_type_message(channels, bad, "channels"))
    return(invisible())
  }
  rec$pass("channels_column_types", "`channels` columns have their specified types.")

  if (rec$ok("images_required_columns", "images_column_types")) {
    unknown <- !channels$image_id %in% images$image_id
    rec$test("channels_images_known", sum(unknown),
      fail_message = paste0(
        sum(unknown), " channel row", if (sum(unknown) != 1L) "s refer" else " refers", " to `image_id` values missing from `images`: ",
        .cs_examples(channels$image_id[unknown]), "."
      ),
      pass_message = "Every channel belongs to a known image."
    )
  }

  groups <- split(channels$channel_index, channels$image_id)
  noncontig <- names(groups)[!vapply(groups, function(idx) {
    !anyNA(idx) && identical(sort(idx, method = "radix"), seq_along(idx))
  }, logical(1))]
  rec$test("channels_index_contiguous", length(noncontig),
    fail_message = paste0(
      length(noncontig), " image", if (length(noncontig) != 1L) "s", " whose `channel_index` is not 1..n: ",
      .cs_examples(noncontig), "."
    ),
    pass_message = "Channel indices are contiguous within each image."
  )

  blank <- .cs_is_blank(channels$channel_name) | .cs_is_blank(channels$marker)
  dup <- duplicated(paste(channels$image_id, channels$marker, sep = "\r")) & !blank
  n_bad <- sum(blank) + sum(dup)
  rec$test("channels_names", n_bad,
    fail_message = paste0(
      n_bad, " channel row", if (n_bad != 1L) "s", " with an empty name or marker, or a marker used twice in one image",
      if (any(dup)) paste0(", e.g. ", .cs_examples(channels$marker[dup])), "."
    ),
    pass_message = "Channel names and markers are well formed."
  )

  if (rec$ok("dictionary_required_columns", "dictionary_column_types", "images_required_columns", "images_column_types")) {
    markers <- unique(dict$marker[dict$kind %in% "intensity" & !is.na(dict$marker)])
    missing_pairs <- character()
    for (img in images$image_id) {
      have <- channels$marker[channels$image_id %in% img]
      absent <- setdiff(markers, have)
      if (length(absent) > 0L) {
        missing_pairs <- c(missing_pairs, paste0(img, "/", absent))
      }
    }
    rec$test("markers_in_channels", length(missing_pairs),
      fail_message = paste0(
        length(missing_pairs), " image/marker combination", if (length(missing_pairs) != 1L) "s",
        " without a channel, e.g. ", .cs_examples(missing_pairs), "."
      ),
      pass_message = paste0("All ", length(markers), " intensity markers have a channel in every image.")
    )
  }
  invisible()
}

.cs_validate_provenance <- function(prov, rec) {
  required <- c("producer", "reader", "created_utc", "inputs", "counts", "parameters", "history")
  miss <- setdiff(required, names(prov))
  rec$test("provenance_fields", length(miss),
    fail_message = paste0(
      "`provenance` lacks field", if (length(miss) > 1L) "s", ": ",
      paste0("`", miss, "`", collapse = ", "), "."
    ),
    pass_message = "`provenance` has all required fields."
  )
  invisible()
}

.cs_validate_adjacency <- function(adj, cells, rec) {
  if (is.null(adj)) {
    for (ch in c("adjacency_columns", "adjacency_endpoints", "adjacency_pairs", "adjacency_values")) {
      rec$pass(ch, "No adjacency component.")
    }
    return(invisible())
  }
  req <- .cs_required_columns("adjacency")
  miss <- setdiff(req, names(adj))
  bad <- .cs_wrong_types(adj, "adjacency")
  if (length(miss) + length(bad) > 0L) {
    msg <- character()
    if (length(miss) > 0L) msg <- c(msg, paste0("lacks ", paste0("`", miss, "`", collapse = ", ")))
    if (length(bad) > 0L) msg <- c(msg, .cs_type_message(adj, bad, "adjacency"))
    rec$fail("adjacency_columns", length(miss) + length(bad), paste0("`adjacency` ", paste(msg, collapse = "; "), if (length(bad) == 0L) "."))
    return(invisible())
  }
  rec$pass("adjacency_columns", "`adjacency` has all required columns.")

  if (rec$ok("cells_required_columns") && is.character(cells$cell_id) && is.character(cells$image_id)) {
    keys <- .cs_key(cells$image_id, cells$cell_id)
    miss_a <- !.cs_key(adj$image_id, adj$cell_id_a) %in% keys
    miss_b <- !.cs_key(adj$image_id, adj$cell_id_b) %in% keys
    lost <- miss_a | miss_b
    rec$test("adjacency_endpoints", sum(lost),
      fail_message = paste0(
        sum(lost), " contact", if (sum(lost) != 1L) "s", " with an endpoint missing from `cells`, e.g. ",
        .cs_examples(c(
          .cs_key_label(adj$image_id[miss_a], adj$cell_id_a[miss_a]),
          .cs_key_label(adj$image_id[miss_b], adj$cell_id_b[miss_b])
        )), "."
      ),
      pass_message = "All contact endpoints exist."
    )
  }

  unordered <- is.na(adj$cell_id_a) | is.na(adj$cell_id_b) |
    !.cs_byte_less(adj$cell_id_a, adj$cell_id_b)
  pair <- paste(adj$image_id, adj$cell_id_a, adj$cell_id_b, sep = "\r")
  dup <- duplicated(pair)
  n_bad <- sum(unordered | dup)
  rec$test("adjacency_pairs", n_bad,
    fail_message = paste0(
      n_bad, " contact", if (n_bad != 1L) "s", " not ordered as `cell_id_a < cell_id_b` or listed twice, e.g. ",
      .cs_examples(paste0(adj$image_id, "/", adj$cell_id_a, "-", adj$cell_id_b)[unordered | dup]), "."
    ),
    pass_message = "Contacts are ordered and unique."
  )

  val_bad <- !(is.finite(adj$shared_boundary) & adj$shared_boundary >= 0) |
    !adj$method %in% .cs_vocab_values("adjacency_method")
  rec$test("adjacency_values", sum(val_bad),
    fail_message = paste0(
      sum(val_bad), " contact", if (sum(val_bad) != 1L) "s", " with a negative or missing `shared_boundary` or an unknown `method` (rows ",
      .cs_examples(which(val_bad), quote = FALSE), ")."
    ),
    pass_message = "Contact values are valid."
  )
  invisible()
}

# Byte-wise (C locale) comparison, independent of the session locale.
.cs_byte_less <- function(a, b) {
  out <- rep(FALSE, length(a))
  ok <- !is.na(a) & !is.na(b) & a != b
  if (any(ok)) {
    both <- c(a[ok], b[ok])
    rank <- match(both, sort(unique(both), method = "radix"))
    n <- sum(ok)
    out[ok] <- rank[seq_len(n)] < rank[n + seq_len(n)]
  }
  out
}

.cs_validate_semantic <- function(x, rec, area_range, na_max) {
  cells <- x$cells
  images <- x$images
  m <- x$measurements
  dict <- x$dictionary

  # Centroids inside the image extent
  idx <- match(cells$image_id, images$image_id)
  if (all(c("width_px", "height_px") %in% names(images))) {
    ps <- images$pixel_size[idx]
    psy <- if ("pixel_size_y" %in% names(images)) images$pixel_size_y[idx] else rep(NA_real_, length(idx))
    psy[is.na(psy)] <- ps[is.na(psy)]
    w <- images$width_px[idx] * ps
    h <- images$height_px[idx] * psy
    known <- !is.na(w) & !is.na(h)
    outside <- known & (cells$x < -ps | cells$x > w + ps | cells$y < -psy | cells$y > h + psy)
    if (!any(known)) {
      rec$pass("centroids_within_image", "Not checked: image dimensions are unknown.")
    } else {
      rec$test("centroids_within_image", sum(outside),
        fail_message = paste0(
          sum(outside), " cell", if (sum(outside) != 1L) "s", " with a centroid more than one pixel outside the image, e.g. ",
          .cs_examples(.cs_key_label(cells$image_id[outside], cells$cell_id[outside])), "."
        ),
        pass_message = "All centroids lie inside their image.",
        status = "warn"
      )
    }
  } else {
    rec$pass("centroids_within_image", "Not checked: image dimensions are unknown.")
  }

  if ("area" %in% names(cells)) {
    a <- cells$area
    out_range <- !is.na(a) & (a < area_range[[1L]] | a > area_range[[2L]])
    rec$test("area_range", sum(out_range),
      fail_message = paste0(
        sum(out_range), " cell", if (sum(out_range) != 1L) "s", " with `area` outside ",
        area_range[[1L]], "-", area_range[[2L]], " square micrometres, e.g. ",
        .cs_examples(.cs_key_label(cells$image_id[out_range], cells$cell_id[out_range])), "."
      ),
      pass_message = paste0("All areas lie within ", area_range[[1L]], "-", area_range[[2L]], " square micrometres."),
      status = "warn"
    )
  } else {
    rec$pass("area_range", "Not checked: `cells` has no `area` column.")
  }

  int_ids <- dict$feature_id[dict$kind == "intensity"]
  if (length(int_ids) > 0L && nrow(m) > 0L) {
    neg <- colSums(m[, int_ids, drop = FALSE] < 0, na.rm = TRUE)
    neg <- neg[neg > 0]
    rec$test("negative_intensity", sum(neg),
      fail_message = paste0(
        sum(neg), " negative intensity value", if (sum(neg) != 1L) "s", " in ", length(neg),
        " feature", if (length(neg) != 1L) "s", ": ",
        paste0(utils::head(names(neg), 5L), " (", utils::head(neg, 5L), ")", collapse = ", "),
        if (length(neg) > 5L) paste0(" and ", length(neg) - 5L, " more") else "", "."
      ),
      pass_message = "No negative intensity values.",
      status = "warn"
    )
  } else {
    rec$pass("negative_intensity", "No intensity values to check.")
  }

  if (ncol(m) > 0L && nrow(m) > 0L) {
    na_frac <- colSums(is.na(m)) / nrow(m)
    high <- na_frac[na_frac > na_max]
    rec$test("feature_na_fraction", length(high),
      fail_message = paste0(
        length(high), " feature", if (length(high) != 1L) "s", " with more than ", format(100 * na_max), "% missing values: ",
        paste0(utils::head(names(high), 5L), " (", format(round(100 * utils::head(high, 5L), 1)), "%)", collapse = ", "),
        if (length(high) > 5L) paste0(" and ", length(high) - 5L, " more") else "", "."
      ),
      pass_message = paste0("No feature has more than ", format(100 * na_max), "% missing values."),
      status = "warn"
    )
  } else {
    rec$pass("feature_na_fraction", "No measurements to check.")
  }

  support <- cs_feature_support(x)
  weak <- support[support$support != "ok", , drop = FALSE]
  rec$test("feature_support", nrow(weak),
    fail_message = paste0(
      nrow(weak), " image/feature combination", if (nrow(weak) != 1L) "s", " without usable signal: ",
      .cs_examples(paste0(weak$image_id, "/", weak$feature_id, " (", weak$support, ")")), "."
    ),
    pass_message = "Every mean intensity feature varies in every image.",
    status = "warn"
  )

  dup <- duplicated(data.frame(cells$image_id, cells$x, cells$y))
  rec$test("duplicate_centroids", sum(dup),
    fail_message = paste0(
      sum(dup), " cell", if (sum(dup) != 1L) "s", " sharing a centroid with an earlier cell of the same image (possible tile-merge duplicates), e.g. ",
      .cs_examples(.cs_key_label(cells$image_id[dup], cells$cell_id[dup])), "."
    ),
    pass_message = "No duplicated centroids.",
    status = "warn"
  )
  invisible()
}

#' @export
print.cellspec_validation <- function(x, ...) {
  status_order <- c(fail = 1L, warn = 2L, skip = 3L, pass = 4L)
  counts <- table(factor(x$status, levels = names(status_order)))
  cat(
    "<cellspec validation> ", nrow(x), " checks: ",
    counts[["fail"]], " fail, ", counts[["warn"]], " warn, ",
    counts[["skip"]], " skip, ", counts[["pass"]], " pass\n",
    sep = ""
  )
  ord <- order(status_order[x$status], seq_len(nrow(x)))
  shown <- x[ord, , drop = FALSE]
  shown <- shown[shown$status != "pass", , drop = FALSE]
  labels <- c(fail = "FAIL", warn = "WARN", skip = "SKIP")
  for (i in seq_len(nrow(shown))) {
    cat(
      labels[[shown$status[[i]]]], " ", shown$check[[i]], ": ",
      shown$message[[i]], "\n",
      sep = ""
    )
  }
  if (counts[["pass"]] > 0L) {
    cat("pass ", counts[["pass"]], " other check", if (counts[["pass"]] != 1L) "s", "\n", sep = "")
  }
  invisible(x)
}
