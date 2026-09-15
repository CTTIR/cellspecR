# Minimal valid objects built in code.

min_parts <- function() {
  list(
    cells = data.frame(
      cell_id = c("c1", "c2", "c3"),
      image_id = "img1",
      sample_id = "s1",
      x = c(1, 2, 3),
      y = c(4, 5, 6),
      area = c(40, 50, 60),
      stringsAsFactors = FALSE
    ),
    measurements = cbind(
      "cell:CD3e:mean" = c(10, 0, 5),
      "nucleus:FOXP3:mean" = c(1, 2, 3),
      "cell:area" = c(40, 50, 60)
    ),
    dictionary = data.frame(
      feature_id = c("cell:CD3e:mean", "nucleus:FOXP3:mean", "cell:area"),
      kind = c("intensity", "intensity", "shape"),
      marker = c("CD3e", "FOXP3", NA),
      compartment = c("cell", "nucleus", "cell"),
      statistic = c("mean", "mean", "area"),
      unit = c("a.u.", "a.u.", "um2"),
      source_name = c("Cell: CD3e: Mean", "Nucleus: FOXP3: Mean", "Cell: Area µm^2"),
      stringsAsFactors = FALSE
    ),
    images = data.frame(image_id = "img1", sample_id = "s1", pixel_size = 0.5,
                        width_px = 100L, height_px = 100L, stringsAsFactors = FALSE),
    channels = data.frame(
      image_id = "img1",
      channel_index = 1:3,
      channel_name = c("DAPI", "CD3e", "FOXP3"),
      marker = c("DAPI", "CD3e", "FOXP3"),
      stringsAsFactors = FALSE
    )
  )
}

min_object <- function() {
  p <- min_parts()
  cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
}

# Two images, twelve cells each, with adjacency.
sim_object <- function(adjacency = TRUE, ...) {
  cellspecR:::.cs_simulate(n_cells = 12L, n_images = 2L, adjacency = adjacency, ...)
}

failing_checks <- function(x, level = "structure") {
  r <- cs_validate(x, level = level)
  r$check[r$status == "fail"]
}

# A hash per row of cells + measurements, to prove alignment after subsetting.
row_hashes <- function(x) {
  df <- as.data.frame(x)
  do.call(paste, c(unname(lapply(df, as.character)), sep = "|"))
}
