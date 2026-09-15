# Combine cellspec objects and remove duplicated halo cells.

#' Combine cellspec objects from different images
#'
#' `cs_bind()` combines cell tables, measurements and metadata from one or
#' more `cellspec` objects. Objects must describe different images and must
#' use the same measurement dictionary.
#'
#' @param ... `cellspec` objects to combine.
#' @return A combined `cellspec` object.
#' @family object
#' @export
#' @examples
#' cs_bind(cs_example())
cs_bind <- function(...) {
  objects <- list(...)
  if (length(objects) == 1L && is.list(objects[[1L]]) &&
      !inherits(objects[[1L]], "cellspec")) {
    objects <- objects[[1L]]
  }
  if (length(objects) == 0L) {
    .cs_abort("Supply at least one {.cls cellspec} object to {.fn cs_bind}.")
  }
  for (i in seq_along(objects)) {
    .cs_check_cellspec(objects[[i]], arg = paste0("..", i))
    cs_assert_valid(objects[[i]], level = "structure")
  }

  image_ids <- unlist(lapply(objects, function(x) x$images$image_id),
                      use.names = FALSE)
  duplicate_images <- unique(image_ids[duplicated(image_ids)])
  if (length(duplicate_images) > 0L) {
    .cs_abort(
      c(
        "Objects supplied to {.fn cs_bind} must contain different images.",
        "x" = "Repeated {.arg image_id}{?s}: {.val {duplicate_images}}."
      ),
      class = "cellspec_error_collision"
    )
  }

  dictionary <- objects[[1L]]$dictionary
  permutations <- lapply(seq_along(objects), function(i) {
    .cs_dictionary_alignment(dictionary, objects[[i]]$dictionary,
                             label = paste0("object ", i))
  })

  cells <- .cs_rbind_components(lapply(objects, `[[`, "cells"))
  measurements <- .cs_rbind_measurements(
    lapply(seq_along(objects), function(i) {
      objects[[i]]$measurements[, permutations[[i]], drop = FALSE]
    }),
    dictionary$feature_id
  )
  images <- .cs_rbind_components(lapply(objects, `[[`, "images"))
  channels <- .cs_rbind_components(lapply(objects, `[[`, "channels"))
  adjacency <- .cs_combine_adjacency(objects)

  provenance <- .cs_combine_provenance(
    objects,
    adapter = "cs_bind",
    n_cells = nrow(cells),
    rows_read = nrow(cells),
    details = list(n_objects = length(objects))
  )
  out <- .cs_build(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    provenance = provenance,
    adjacency = adjacency,
    adapter = "cs_bind"
  )
  cs_assert_valid(out, level = "structure")
  .cs_add_history(
    out,
    step = "combine",
    fun = "cs_bind",
    details = list(n_objects = length(objects), n_cells = nrow(out$cells))
  )
}

#' Merge tiled cellspec objects using centroid ownership
#'
#' Every centroid is assigned to the half open outer box containing it. A
#' centroid found in more than one box is an error. Cells in a tile whose
#' centroid is owned by another tile, or by no tile, are treated as halo cells
#' and dropped.
#'
#' @param tiles A named or positional list of `cellspec` tile objects. Names,
#'   when supplied, must equal `tile_bounds$tile_id`.
#' @param tile_bounds A data frame with `tile_id`, `xmin`, `xmax`, `ymin` and
#'   `ymax` in micrometres.
#' @param ownership Ownership method. The only supported value is
#'   `"centroid"`.
#' @param tolerance Non-negative tolerance used to snap coordinates close to a
#'   box boundary before applying its half open comparisons.
#' @return A merged `cellspec` object.
#' @family object
#' @export
#' @examples
#' tile_bounds <- data.frame(
#'   tile_id = "tile-1", xmin = 0, xmax = 10000, ymin = 0, ymax = 10000
#' )
#' cs_merge_tiles(list(cs_example()), tile_bounds)
cs_merge_tiles <- function(tiles, tile_bounds,
                           ownership = "centroid", tolerance = 1e-9) {
  if (!is.list(tiles) || inherits(tiles, "cellspec")) {
    .cs_abort(
      c(
        "{.arg tiles} must be a list of {.cls cellspec} objects.",
        "x" = "Got {.obj_type_friendly {tiles}}."
      )
    )
  }
  .cs_check_count(length(tiles), min = 1L, arg = "tiles")
  .cs_check_choice(ownership, choices = "centroid", arg = "ownership")
  .cs_check_number(tolerance, min = 0, arg = "tolerance")
  for (i in seq_along(tiles)) {
    .cs_check_cellspec(tiles[[i]], arg = paste0("tiles[[", i, "]]"))
    cs_assert_valid(tiles[[i]], level = "structure")
  }

  bounds <- .cs_prepare_tile_bounds(tile_bounds)
  tile_ids <- .cs_tile_ids(tiles, bounds$tile_id)
  bounds <- bounds[match(tile_ids, bounds$tile_id), , drop = FALSE]
  attr(bounds, "row.names") <- .set_row_names(nrow(bounds))

  dictionary <- tiles[[1L]]$dictionary
  permutations <- lapply(seq_along(tiles), function(i) {
    .cs_dictionary_alignment(dictionary, tiles[[i]]$dictionary,
                             label = paste0("tile ", tile_ids[[i]]))
  })

  kept_rows <- vector("list", length(tiles))
  kept_measurements <- vector("list", length(tiles))
  n_input <- integer(length(tiles))
  n_kept <- integer(length(tiles))
  for (i in seq_along(tiles)) {
    cells_i <- tiles[[i]]$cells
    n_input[[i]] <- nrow(cells_i)
    owner <- .cs_tile_owners(cells_i, bounds, tolerance)
    keep <- !is.na(owner) & owner == i
    kept_rows[[i]] <- which(keep)
    n_kept[[i]] <- length(kept_rows[[i]])
    kept_measurements[[i]] <- tiles[[i]]$measurements[
      kept_rows[[i]], permutations[[i]], drop = FALSE
    ]
  }
  n_dropped <- n_input - n_kept
  tile_counts <- data.frame(
    tile_id = as.character(tile_ids),
    n_input = as.integer(n_input),
    n_kept = as.integer(n_kept),
    n_dropped = as.integer(n_dropped),
    stringsAsFactors = FALSE
  )

  cells <- .cs_rbind_components(lapply(seq_along(tiles), function(i) {
    tiles[[i]]$cells[kept_rows[[i]], , drop = FALSE]
  }))
  duplicate_keys <- .cs_key(cells$image_id, cells$cell_id)
  duplicate_keys <- unique(duplicate_keys[duplicated(duplicate_keys)])
  if (length(duplicate_keys) > 0L) {
    .cs_abort(
      c(
        "Tile merge would create duplicate cell keys.",
        "x" = "Repeated key{?s}: {.val {.cs_key_labels(cells, duplicate_keys)}}."
      ),
      class = "cellspec_error_collision"
    )
  }

  measurements <- .cs_rbind_measurements(kept_measurements,
                                          dictionary$feature_id)
  images <- .cs_unique_component(
    lapply(tiles, `[[`, "images"),
    key = "image_id",
    component = "images"
  )
  channels <- .cs_unique_component(
    lapply(tiles, `[[`, "channels"),
    key = c("image_id", "channel_index"),
    component = "channels"
  )
  adjacency <- .cs_combine_adjacency(tiles, cells = cells)

  provenance <- .cs_combine_provenance(
    tiles,
    adapter = "cs_merge_tiles",
    n_cells = nrow(cells),
    rows_read = sum(n_input),
    details = list(
      ownership = ownership,
      tolerance = tolerance,
      n_tiles = length(tiles),
      tile_counts = tile_counts
    ),
    tile_counts = tile_counts,
    rows_dropped = sum(n_dropped)
  )
  out <- .cs_build(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    provenance = provenance,
    adjacency = adjacency,
    adapter = "cs_merge_tiles"
  )
  cs_assert_valid(out, level = "structure")
  .cs_add_history(out, step = "combine", fun = "cs_merge_tiles", details = list(
    ownership = ownership,
    tolerance = tolerance,
    tile_counts = tile_counts
  ))
}

.cs_dictionary_alignment <- function(reference, candidate, label) {
  if (!setequal(names(reference), names(candidate))) {
    .cs_abort(
      c(
        "Measurement dictionaries are incompatible.",
        "x" = "{label} has different dictionary columns."
      ),
      class = "cellspec_error_invalid"
    )
  }
  if (nrow(reference) != nrow(candidate)) {
    .cs_abort(
      c(
        "Measurement dictionaries are incompatible.",
        "x" = "{label} describes {nrow(candidate)} features; the first object describes {nrow(reference)}."
      ),
      class = "cellspec_error_invalid"
    )
  }
  permutation <- match(reference$feature_id, candidate$feature_id)
  if (anyNA(permutation)) {
    .cs_abort(
      c(
        "Measurement dictionaries are incompatible.",
        "x" = "{label} is missing feature{?s}: {.val {reference$feature_id[is.na(permutation)]}}."
      ),
      class = "cellspec_error_invalid"
    )
  }
  same <- vapply(names(reference), function(nm) {
    identical(reference[[nm]], candidate[[nm]][permutation])
  }, logical(1))
  if (!all(same)) {
    .cs_abort(
      c(
        "Measurement dictionaries are incompatible.",
        "x" = "{label} differs in {.val {names(reference)[!same]}}."
      ),
      class = "cellspec_error_invalid"
    )
  }
  permutation
}

.cs_rbind_components <- function(components) {
  out <- data.table::rbindlist(
    lapply(components, as.data.frame),
    use.names = TRUE,
    fill = TRUE
  )
  as.data.frame(out, stringsAsFactors = FALSE)
}

.cs_rbind_measurements <- function(matrices, feature_ids) {
  if (length(matrices) == 0L) {
    return(matrix(numeric(0), nrow = 0L, ncol = length(feature_ids),
                  dimnames = list(NULL, feature_ids)))
  }
  out <- do.call(rbind, matrices)
  out <- matrix(as.double(out), nrow = nrow(out), ncol = ncol(out),
                dimnames = list(NULL, feature_ids))
  out
}

.cs_combine_adjacency <- function(objects, cells = NULL) {
  present <- !vapply(objects, function(x) is.null(x$adjacency), logical(1))
  if (!any(present)) {
    return(NULL)
  }
  adjacency <- .cs_rbind_components(lapply(objects[present], `[[`, "adjacency"))
  if (!is.null(cells)) {
    keys <- .cs_key(cells$image_id, cells$cell_id)
    keep <- .cs_key(adjacency$image_id, adjacency$cell_id_a) %in% keys &
      .cs_key(adjacency$image_id, adjacency$cell_id_b) %in% keys
    adjacency <- adjacency[keep, , drop = FALSE]
  }
  key <- paste(adjacency$image_id, adjacency$cell_id_a,
               adjacency$cell_id_b, sep = "\r")
  adjacency <- adjacency[!duplicated(key), , drop = FALSE]
  attr(adjacency, "row.names") <- .set_row_names(nrow(adjacency))
  adjacency
}

.cs_unique_component <- function(components, key, component) {
  out <- .cs_rbind_components(components)
  if (nrow(out) == 0L) {
    return(.cs_normalise_df(out, component))
  }
  values <- lapply(key, function(nm) out[[nm]])
  key_value <- do.call(paste, c(values, sep = "\r"))
  duplicate <- duplicated(key_value)
  if (any(duplicate)) {
    for (i in which(duplicate)) {
      first <- match(key_value[[i]], key_value)
      same <- vapply(names(out), function(nm) {
        identical(out[[nm]][[i]], out[[nm]][[first]])
      }, logical(1))
      if (!all(same)) {
        .cs_abort(
          c(
            "Repeated metadata rows are incompatible.",
            "x" = "The {component} entry {.val {key_value[[i]]}} differs between tiles."
          ),
          class = "cellspec_error_invalid"
        )
      }
    }
    out <- out[!duplicate, , drop = FALSE]
  }
  attr(out, "row.names") <- .set_row_names(nrow(out))
  out
}

.cs_combine_provenance <- function(objects, adapter, n_cells, rows_read,
                                   details, tile_counts = NULL,
                                   rows_dropped = NULL) {
  provenance <- objects[[1L]]$provenance
  histories <- lapply(objects, function(x) x$provenance$history)
  histories <- histories[!vapply(histories, is.null, logical(1))]
  if (length(histories) == 0L) {
    provenance$history <- list()
  } else {
    provenance$history <- do.call(c, histories)
  }
  provenance$reader$adapter <- adapter
  provenance$reader$adapter_version <- "1.0.0"
  provenance$counts$rows_read <- as.integer(rows_read)
  provenance$counts$rows_kept <- as.integer(n_cells)
  provenance$counts$na_converted <- .cs_provenance_count_sum(objects, "na_converted")
  provenance$counts$nonfinite_converted <- .cs_provenance_count_sum(
    objects, "nonfinite_converted"
  )
  if (!is.null(rows_dropped)) {
    provenance$counts$rows_dropped <- as.integer(rows_dropped)
  }
  if (!is.null(tile_counts)) {
    provenance$counts$tile_counts <- tile_counts
  }
  if (is.null(provenance$parameters) || !is.list(provenance$parameters)) {
    provenance$parameters <- list()
  }
  provenance$parameters$combine <- details
  provenance
}

.cs_provenance_count_sum <- function(objects, field) {
  value <- vapply(objects, function(x) {
    n <- x$provenance$counts[[field]]
    if (is.numeric(n) && length(n) == 1L && is.finite(n)) n else 0
  }, numeric(1))
  as.integer(sum(value))
}

.cs_prepare_tile_bounds <- function(tile_bounds) {
  .cs_check_data_frame(tile_bounds, arg = "tile_bounds")
  required <- c("tile_id", "xmin", "xmax", "ymin", "ymax")
  missing <- setdiff(required, names(tile_bounds))
  if (length(missing) > 0L) {
    .cs_abort(
      c(
        "{.arg tile_bounds} lacks required columns.",
        "x" = "Missing: {.val {missing}}."
      )
    )
  }
  bounds <- as.data.frame(tile_bounds, stringsAsFactors = FALSE)
  bounds$tile_id <- as.character(bounds$tile_id)
  blank <- is.na(bounds$tile_id) | !nzchar(bounds$tile_id)
  if (any(blank) || anyDuplicated(bounds$tile_id)) {
    .cs_abort(
      c(
        "{.arg tile_bounds$tile_id} must contain unique non-empty values.",
        "x" = "Got missing or repeated tile identifiers."
      ),
      class = "cellspec_error_collision"
    )
  }
  for (nm in required[-1L]) {
    if (!is.numeric(bounds[[nm]]) || anyNA(bounds[[nm]]) ||
        any(!is.finite(bounds[[nm]]))) {
      .cs_abort(
        c(
          "{.arg tile_bounds} coordinates must be finite numeric values.",
          "x" = "Column {.field {nm}} is invalid."
        )
      )
    }
  }
  invalid_extent <- bounds$xmin >= bounds$xmax | bounds$ymin >= bounds$ymax
  if (any(invalid_extent)) {
    .cs_abort(
      c(
        "Each tile must have positive width and height.",
        "x" = "Invalid extent{?s} for {.val {bounds$tile_id[invalid_extent]}}."
      )
    )
  }
  bounds
}

.cs_tile_ids <- function(tiles, bound_ids) {
  tile_names <- names(tiles)
  has_names <- !is.null(tile_names) &&
    any(!is.na(tile_names) & nzchar(tile_names))
  all_named <- !is.null(tile_names) && length(tile_names) == length(tiles) &&
    all(!is.na(tile_names) & nzchar(tile_names))
  if (has_names && !all_named) {
    .cs_abort("{.arg tiles} must be either completely named or positional.")
  }
  if (all_named) {
    if (anyDuplicated(tile_names) || !setequal(tile_names, bound_ids)) {
      .cs_abort(
        c(
          "Named {.arg tiles} must match {.arg tile_bounds$tile_id}.",
          "x" = "Tile names and bounds identifiers differ."
        ),
        class = "cellspec_error_collision"
      )
    }
    return(tile_names)
  }
  if (length(tiles) != length(bound_ids)) {
    .cs_abort(
      c(
        "Positional {.arg tiles} must have one entry per row of {.arg tile_bounds}.",
        "x" = "Got {length(tiles)} tile{?s} and {length(bound_ids)} bounds."
      )
    )
  }
  as.character(bound_ids)
}

.cs_tile_owners <- function(cells, bounds, tolerance) {
  n <- nrow(cells)
  if (n == 0L) {
    return(rep(NA_integer_, 0L))
  }
  candidates <- integer(n)
  owner <- rep(NA_integer_, n)
  for (i in seq_len(nrow(bounds))) {
    inside_x <- .cs_tile_inside(cells$x, bounds$xmin[[i]],
                                bounds$xmax[[i]], tolerance)
    inside_y <- .cs_tile_inside(cells$y, bounds$ymin[[i]],
                                bounds$ymax[[i]], tolerance)
    inside <- inside_x & inside_y
    first <- inside & candidates == 0L
    owner[first] <- i
    candidates[inside] <- candidates[inside] + 1L
  }
  duplicate <- candidates > 1L
  if (any(duplicate)) {
    example <- which(duplicate)[[1L]]
    .cs_abort(
      c(
        "Centroid ownership is ambiguous.",
        "x" = "{sum(duplicate)} centroid{?s} fall in more than one outer tile, including {.val {paste(cells$image_id[[example]], cells$cell_id[[example]], sep = '/')}}."
      ),
      class = "cellspec_error_collision"
    )
  }
  owner
}

.cs_tile_inside <- function(value, lower, upper, tolerance) {
  at_lower <- abs(value - lower) <= tolerance
  at_upper <- abs(value - upper) <= tolerance
  lower_value <- ifelse(at_lower, lower, value)
  upper_value <- ifelse(at_upper, upper, value)
  lower_value >= lower & upper_value < upper
}

.cs_key_labels <- function(cells, keys) {
  all_keys <- .cs_key(cells$image_id, cells$cell_id)
  labels <- paste0(cells$image_id, "/", cells$cell_id)
  labels[match(keys, all_keys)]
}
