# One invalid object per structure (MUST) rule. Each entry names the check
# that must be the only failing check for that object.

rename_marker <- function(x, from, to) {
  d <- x$dictionary
  hit <- d$kind == "intensity" & d$marker %in% from
  d$marker[hit] <- to
  d$feature_id[hit] <- paste(d$compartment[hit], to, d$statistic[hit], sep = ":")
  x$dictionary <- d
  colnames(x$measurements) <- d$feature_id
  x$channels$marker[x$channels$marker == from] <- to
  x
}

invalid_objects <- function() {
  base <- sim_object(adjacency = FALSE)
  with_adj <- sim_object(adjacency = TRUE)
  other <- which(base$dictionary$kind == "other")[[1L]]
  shape <- which(base$dictionary$kind == "shape")[[1L]]
  intensity <- which(base$dictionary$kind == "intensity")[[1L]]

  cases <- list()
  add <- function(check, obj) {
    cases[[length(cases) + 1L]] <<- list(check = check, object = obj)
  }

  add("object_class", unclass(base))
  x <- base; x$images <- NULL; add("object_components", x)
  x <- base; x$spec_version <- "2.0.0"; add("spec_version", x)

  x <- base; x$cells$y <- NULL; add("cells_required_columns", x)
  x <- base; x$cells$x <- as.character(x$cells$x); add("cells_column_types", x)
  x <- base; x$cells$cs__tmp <- 1; add("cells_reserved_names", x)
  x <- base; x$cells$`region__bad layer` <- "tumour"; add("cells_reserved_names", x)
  x <- base; x$cells$subject_id <- "p1"; add("cells_subject_id", x)
  x <- base; x$cells$cell_id[1] <- NA; add("cells_ids_present", x)
  x <- base; x$cells$cell_id[2] <- x$cells$cell_id[1]; add("cells_key_unique", x)
  x <- base; x$cells$x[1] <- Inf; add("cells_coordinates_finite", x)
  x <- base; x$cells$area[1] <- -5; add("cells_area_positive", x)
  x <- base; x$cells$image_id[1] <- "img9"; add("cells_images_known", x)
  x <- base; x$cells$sample_id[1] <- "s9"; add("cells_sample_consistent", x)

  x <- base; storage.mode(x$measurements) <- "integer"; add("measurements_type", x)
  x <- base; x$measurements <- x$measurements[-1, , drop = FALSE]; add("measurements_rows", x)
  x <- base; colnames(x$measurements)[1] <- "cell:Other:mean"; add("measurements_names", x)
  x <- base; x$measurements[1, 1] <- NaN; add("measurements_finite", x)

  x <- base; x$dictionary$unit <- NULL; add("dictionary_required_columns", x)
  x <- base; x$dictionary$marker_source <- 1; add("dictionary_column_types", x)
  x <- base
  x$dictionary <- rbind(x$dictionary, x$dictionary[other, ])
  x$measurements <- cbind(x$measurements, x$measurements[, other, drop = FALSE])
  add("dictionary_feature_id_unique", x)
  x <- base; x$dictionary$kind[other] <- "texture"; add("dictionary_kind", x)
  x <- base
  x$dictionary$statistic[intensity] <- "p95"
  x$dictionary$feature_id[intensity] <- paste(x$dictionary$compartment[intensity], x$dictionary$marker[intensity], "p95", sep = ":")
  colnames(x$measurements) <- x$dictionary$feature_id
  add("dictionary_intensity", x)
  x <- base; x$dictionary$marker[shape] <- "DAPI"; add("dictionary_shape", x)
  x <- base; x$dictionary$marker[other] <- "DAPI"; add("dictionary_other", x)
  x <- base; x$dictionary$unit[shape] <- "µm^2"; add("dictionary_unit", x)
  add("dictionary_marker_names", rename_marker(base, "CD3e", " CD3e"))
  add("dictionary_marker_names", rename_marker(base, "CD3e", "CD3:e"))
  x <- base
  x$dictionary$feature_id[intensity] <- "DAPI_mean"
  colnames(x$measurements) <- x$dictionary$feature_id
  add("dictionary_feature_id_format", x)
  x <- base; x$dictionary$source_name[1] <- NA; add("dictionary_source_name", x)

  x <- base; x$images$pixel_size <- NULL; add("images_required_columns", x)
  x <- base; x$images$width_px <- as.character(x$images$width_px); add("images_column_types", x)
  x <- base; x$images <- rbind(x$images, x$images[1, ]); add("images_id_unique", x)
  x <- base; x$images$sample_id[1] <- NA; add("images_sample_present", x)
  x <- base; x$images$pixel_size[1] <- 0; add("images_pixel_size", x)
  x <- base; x$images$width_px[1] <- 0L; add("images_dimensions", x)

  x <- base; x$channels$marker <- NULL; add("channels_required_columns", x)
  x <- base; x$channels$channel_index <- as.character(x$channels$channel_index); add("channels_column_types", x)
  x <- base
  x$channels <- rbind(x$channels, data.frame(image_id = "img9", channel_index = 1L,
                                             channel_name = "DAPI", marker = "DAPI"))
  add("channels_images_known", x)
  x <- base
  first <- x$channels$image_id == "img1"
  x$channels$channel_index[first] <- x$channels$channel_index[first] + 1L
  add("channels_index_contiguous", x)
  x <- base; x$channels$channel_name[1] <- ""; add("channels_names", x)
  x <- base
  last <- max(which(x$channels$image_id == "img2"))
  x$channels <- x$channels[-last, ]
  add("markers_in_channels", x)

  x <- base; x$provenance$history <- NULL; add("provenance_fields", x)

  x <- with_adj; x$adjacency$method <- NULL; add("adjacency_columns", x)
  x <- with_adj; x$adjacency$cell_id_b[1] <- "999"; add("adjacency_endpoints", x)
  x <- with_adj
  a <- x$adjacency$cell_id_a[1]
  x$adjacency$cell_id_a[1] <- x$adjacency$cell_id_b[1]
  x$adjacency$cell_id_b[1] <- a
  add("adjacency_pairs", x)
  x <- with_adj; x$adjacency$shared_boundary[1] <- -1; add("adjacency_values", x)
  x <- with_adj; x$adjacency$method[1] <- "voronoi"; add("adjacency_values", x)

  cases
}
