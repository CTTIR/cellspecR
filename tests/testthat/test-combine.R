combine_parts <- function(ids, x, y, image_id = "img1", adjacency = NULL) {
  n <- length(ids)
  cells <- data.frame(
    cell_id = as.character(ids),
    image_id = rep(image_id, n),
    sample_id = rep(paste0("sample-", image_id), n),
    x = as.double(x),
    y = as.double(y),
    area = rep(20, n),
    stringsAsFactors = FALSE
  )
  measurements <- cbind(
    "cell:CD3e:mean" = as.double(seq_len(n)),
    "cell:area" = rep(20, n)
  )
  dictionary <- data.frame(
    feature_id = colnames(measurements),
    kind = c("intensity", "shape"),
    marker = c("CD3e", NA),
    compartment = c("cell", "cell"),
    statistic = c("mean", "area"),
    unit = c("a.u.", "um2"),
    source_name = c("Cell: CD3e: Mean", "Cell: Area um^2"),
    stringsAsFactors = FALSE
  )
  images <- data.frame(
    image_id = image_id,
    sample_id = paste0("sample-", image_id),
    pixel_size = 1,
    width_px = 20L,
    height_px = 20L,
    stringsAsFactors = FALSE
  )
  channels <- data.frame(
    image_id = image_id,
    channel_index = 1L,
    channel_name = "CD3e",
    marker = "CD3e",
    stringsAsFactors = FALSE
  )
  cs_new(cells, measurements, dictionary, images, channels,
         adjacency = adjacency)
}

tile_bounds_for_test <- function() {
  data.frame(
    tile_id = c("left", "right"),
    xmin = c(0, 10),
    xmax = c(10, 20),
    ymin = c(0, 0),
    ymax = c(20, 20),
    stringsAsFactors = FALSE
  )
}

test_that("cs_merge_tiles keeps empty tiles and records tile counts", {
  left <- combine_parts(c("a"), 5, 5)
  right <- left[integer(), ]
  merged <- cellspecR:::cs_merge_tiles(
    list(left = left, right = right),
    tile_bounds_for_test()
  )

  expect_identical(nrow(merged$cells), 1L)
  expect_identical(merged$cells$cell_id, "a")
  expect_identical(merged$provenance$counts$tile_counts$n_kept, c(1L, 0L))
  expect_identical(merged$provenance$counts$tile_counts$n_dropped, c(0L, 0L))
  expect_identical(tail(merged$provenance$history, 1L)[[1L]][["function"]],
                   "cs_merge_tiles")
})

test_that("cs_merge_tiles drops halo cells outside their source box", {
  left <- combine_parts(c("owned", "halo"), c(5, 15), c(5, 5))
  right <- combine_parts(character(), numeric(), numeric())
  merged <- cellspecR:::cs_merge_tiles(
    list(left, right),
    tile_bounds_for_test()
  )

  expect_identical(merged$cells$cell_id, "owned")
  expect_identical(merged$provenance$counts$tile_counts$n_input, c(2L, 0L))
  expect_identical(merged$provenance$counts$tile_counts$n_kept, c(1L, 0L))
  expect_identical(merged$provenance$counts$tile_counts$n_dropped, c(1L, 0L))
})

test_that("cs_merge_tiles applies half-open ownership at an adjacent boundary", {
  left <- combine_parts(c("left"), 5, 5)
  right <- combine_parts(c("right"), 10, 5)
  merged <- cellspecR:::cs_merge_tiles(
    list(left, right),
    tile_bounds_for_test()
  )

  expect_identical(merged$cells$cell_id, c("left", "right"))
  expect_identical(merged$provenance$counts$tile_counts$n_dropped, c(0L, 0L))
})

test_that("cs_merge_tiles aborts when a centroid has duplicate ownership", {
  left <- combine_parts(c("c1"), 7, 5)
  right <- combine_parts(character(), numeric(), numeric())
  overlapping <- data.frame(
    tile_id = c("left", "right"),
    xmin = c(0, 5), xmax = c(10, 15),
    ymin = c(0, 0), ymax = c(20, 20),
    stringsAsFactors = FALSE
  )

  expect_error(
    cellspecR:::cs_merge_tiles(list(left, right), overlapping),
    class = "cellspec_error_collision"
  )
})

test_that("cs_bind rejects key collisions and incompatible dictionaries", {
  first <- combine_parts(c("c1"), 1, 1, image_id = "img1")
  duplicate <- combine_parts(c("c1"), 2, 2, image_id = "img1")
  expect_error(
    cellspecR:::cs_bind(first, duplicate),
    class = "cellspec_error_collision"
  )

  second <- combine_parts(c("c2"), 2, 2, image_id = "img2")
  second$dictionary$unit[1] <- "1"
  expect_error(
    cellspecR:::cs_bind(first, second),
    class = "cellspec_error_invalid"
  )
})

test_that("cs_bind preserves optional columns, measurements and adjacency", {
  adjacency <- data.frame(
    image_id = "img1",
    cell_id_a = "c1",
    cell_id_b = "c2",
    shared_boundary = 2,
    method = "mask_touching",
    stringsAsFactors = FALSE
  )
  first <- combine_parts(c("c1", "c2"), c(1, 2), c(1, 2),
                         image_id = "img1", adjacency = adjacency)
  first$cells$classification <- c("A", "B")
  second <- combine_parts(c("c3"), 3, 3, image_id = "img2")
  second$cells$classification <- "C"
  second$cells$tile_id <- "tile-2"

  combined <- cellspecR:::cs_bind(first, second)
  expect_identical(combined$cells$cell_id, c("c1", "c2", "c3"))
  expect_identical(combined$measurements[, "cell:CD3e:mean"], c(1, 2, 1))
  expect_identical(combined$cells$classification, c("A", "B", "C"))
  expect_true("tile_id" %in% names(combined$cells))
  expect_true(is.na(combined$cells$tile_id[1]))
  expect_identical(nrow(combined$adjacency), 1L)
  expect_identical(combined$adjacency$cell_id_a, "c1")
  expect_identical(tail(combined$provenance$history, 1L)[[1L]][["function"]],
                   "cs_bind")
  expect_true(all(cs_validate(combined)$status == "pass"))
})

test_that("combine helpers validate bounds, names and dictionary alignment", {
  first <- combine_parts(c("c1"), 1, 1, image_id = "img1")
  second <- combine_parts(c("c2"), 2, 2, image_id = "img2")
  expect_s3_class(cs_bind(list(first, second)), "cellspec")
  expect_error(cs_bind(), class = "cellspec_error")
  expect_error(
    cellspecR:::.cs_dictionary_alignment(
      first$dictionary, first$dictionary[, -1, drop = FALSE], "bad"
    ),
    class = "cellspec_error"
  )
  fewer <- first$dictionary[-1, , drop = FALSE]
  expect_error(
    cellspecR:::.cs_dictionary_alignment(first$dictionary, fewer, "bad"),
    class = "cellspec_error"
  )
  missing <- first$dictionary
  missing$feature_id[[1L]] <- "cell:missing:mean"
  expect_error(
    cellspecR:::.cs_dictionary_alignment(first$dictionary, missing, "bad"),
    class = "cellspec_error"
  )
  different <- first$dictionary
  different$unit[[1L]] <- "1"
  expect_error(
    cellspecR:::.cs_dictionary_alignment(first$dictionary, different, "bad"),
    class = "cellspec_error"
  )
  expect_equal(
    cellspecR:::.cs_rbind_measurements(list(), first$dictionary$feature_id),
    matrix(numeric(), nrow = 0L, ncol = 2L,
           dimnames = list(NULL, first$dictionary$feature_id))
  )
  expect_null(cellspecR:::.cs_combine_adjacency(list(first, second)))
  expect_equal(
    cellspecR:::.cs_provenance_count_sum(list(first), "does_not_exist"),
    0L
  )
})

test_that("tile bounds and ownership helpers reject invalid geometry", {
  expect_error(
    cellspecR:::.cs_prepare_tile_bounds(data.frame(tile_id = "a")),
    class = "cellspec_error"
  )
  base <- data.frame(
    tile_id = "a", xmin = 0, xmax = 1, ymin = 0, ymax = 1,
    stringsAsFactors = FALSE
  )
  bad_id <- base; bad_id$tile_id <- ""
  expect_error(cellspecR:::.cs_prepare_tile_bounds(bad_id),
               class = "cellspec_error")
  bad_value <- base; bad_value$xmin <- "0"
  expect_error(cellspecR:::.cs_prepare_tile_bounds(bad_value),
               class = "cellspec_error")
  bad_extent <- base; bad_extent$xmax <- 0
  expect_error(cellspecR:::.cs_prepare_tile_bounds(bad_extent),
               class = "cellspec_error")

  first <- combine_parts(c("c1"), 0.5, 0.5, image_id = "img1")
  expect_identical(
    cellspecR:::.cs_tile_ids(list(first), "a"),
    "a"
  )
  named <- list(a = first)
  expect_identical(cellspecR:::.cs_tile_ids(named, "a"), "a")
  expect_error(
    cellspecR:::.cs_tile_ids(list(a = first, first), c("a", "b")),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tile_ids(list(a = first), "b"),
    class = "cellspec_error"
  )
  expect_error(
    cellspecR:::.cs_tile_ids(list(first), c("a", "b")),
    class = "cellspec_error"
  )
  expect_identical(
    cellspecR:::.cs_tile_owners(first$cells[FALSE, ], base, 1e-9),
    integer()
  )
  expect_true(cellspecR:::.cs_tile_inside(c(0, 1), 0, 1, 1e-9)[[1L]])
  expect_false(cellspecR:::.cs_tile_inside(c(0, 1), 0, 1, 1e-9)[[2L]])
  expect_error(
    cellspecR:::.cs_tile_owners(
      rbind(first$cells, first$cells),
      rbind(base, transform(base, xmin = 0.25, xmax = 1.25)),
      1e-9
    ),
    class = "cellspec_error_collision"
  )
})

test_that("tile metadata components deduplicate only identical rows", {
  first <- combine_parts(c("c1"), 1, 1, image_id = "img1")
  second <- combine_parts(c("c2"), 2, 2, image_id = "img2")
  empty <- first[integer(), ]
  expect_equal(
    nrow(cellspecR:::.cs_unique_component(
      list(first$images[FALSE, , drop = FALSE]), "image_id", "images"
    )),
    0L
  )
  altered <- first$images
  altered$sample_id <- "different"
  expect_error(
    cellspecR:::.cs_unique_component(
      list(first$images, altered), "image_id", "images"
    ),
    class = "cellspec_error"
  )
  adjacency <- data.frame(
    image_id = "img1", cell_id_a = "c1", cell_id_b = "c2",
    shared_boundary = 1, method = "mask_touching",
    stringsAsFactors = FALSE
  )
  with_adjacency <- combine_parts(c("c1", "c2"), c(1, 2), c(1, 2), image_id = "img1",
                                  adjacency = adjacency)
  filtered <- cellspecR:::.cs_combine_adjacency(
    list(with_adjacency), cells = with_adjacency$cells[FALSE, ]
  )
  expect_equal(nrow(filtered), 0L)
})
