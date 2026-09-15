# Reproducible performance measurements for the development machine.
# Run with: Rscript data-raw/benchmarks/performance.R

if (!requireNamespace("bench", quietly = TRUE)) {
  message("Install the Suggests package bench to run this script.")
  quit(status = 0L)
}

devtools::load_all(quiet = TRUE)
n_cells <- as.integer(Sys.getenv("CELLSPECR_BENCH_CELLS", "10000"))
if (is.na(n_cells) || n_cells < 1L) {
  cli::cli_abort("CELLSPECR_BENCH_CELLS must be a positive integer.")
}

x <- cellspecR:::.cs_simulate(
  n_cells = n_cells, n_images = 2L,
  markers = c("DAPI", "CD3e", "FOXP3", "Pan-Cytokeratin", "CD68",
              "CD8", "CD4", "PD-L1", "Ki67", "SOX10", "CD45", "EPCAM",
              "Vimentin", "SMA", "CD31", "CD11c", "GranzymeB"),
  adjacency = FALSE, seed = 20260915L
)
policy <- cellspecR::cs_signal_policy(
  cellspecR::cs_markers(x), compartment = "cell", statistic = "mean"
)

destination <- tempfile("cellspec-benchmark-")
on.exit(unlink(destination, recursive = TRUE, force = TRUE), add = TRUE)

tile_dir <- tempfile("cellspec-tiled-benchmark-")
dir.create(tile_dir)
on.exit(unlink(tile_dir, recursive = TRUE, force = TRUE), add = TRUE)
tile_n <- max(1L, floor(n_cells / 2L))
make_tile <- function(path, tile_id, x_offset) {
  ids <- paste0(tile_id, seq_len(tile_n))
  x_um <- x_offset + stats::runif(tile_n, 1, 499)
  table <- data.frame(
    sample = "benchmark-sample", cell_id = ids,
    centroid_x_px = x_um * 2, centroid_y_px = stats::runif(tile_n, 1, 1000),
    centroid_x_um = x_um, centroid_y_um = stats::runif(tile_n, 1, 1000),
    `DAPI: Mean` = stats::runif(tile_n),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  data.table::fwrite(table, path, sep = "\t", quote = FALSE)
}
make_tile(file.path(tile_dir, "left.tsv"), "left-", 0)
make_tile(file.path(tile_dir, "right.tsv"), "right-", 500)
bounds <- data.frame(
  tile_id = c("left", "right"), xmin = c(0, 500), xmax = c(500, 1000),
  ymin = c(0, 0), ymax = c(1000, 1000), stringsAsFactors = FALSE
)

benchmarks <- list(
  canonical_write_read = bench::mark(
    {
      cs_write(x, destination, overwrite = TRUE)
      cs_read_cellspec(destination)
    }, iterations = 1L, check = FALSE, memory = TRUE, filter_gc = FALSE
  ),
  semantic_validation = bench::mark(
    cs_validate(x, level = "semantic"),
    iterations = 1L, check = FALSE, memory = TRUE, filter_gc = FALSE
  ),
  signal_matrix = bench::mark(
    cs_signal_matrix(x, policy),
    iterations = 1L, check = FALSE, memory = TRUE, filter_gc = FALSE
  ),
  tiled_read = bench::mark(
    cs_read(tile_dir, format = "qupath_tiled", tile_bounds = bounds),
    iterations = 1L, check = FALSE, memory = TRUE, filter_gc = FALSE
  )
)
if (requireNamespace("SpatialExperiment", quietly = TRUE)) {
  benchmarks$spatial_experiment <- bench::mark(
    cs_as_spe(x, policy),
    iterations = 1L, check = FALSE, memory = TRUE, filter_gc = FALSE
  )
}

lines <- c(
  "# cellspecR performance measurements",
  "",
  paste0("Generated with `CELLSPECR_BENCH_CELLS=", n_cells,
         "` (", nrow(x$cells), " cells; 17 markers) on ",
         Sys.info()[["sysname"]], " ", Sys.info()[["release"]], "."),
  "", "Results are one-iteration smoke measurements; rerun on a CI runner",
  "before release to record the second hardware profile.", ""
)
for (name in names(benchmarks)) {
  lines <- c(lines, paste0("## ", name), "", capture.output(print(benchmarks[[name]])), "")
}
writeLines(lines, file.path("data-raw", "benchmarks", "performance.md"))
message("Wrote data-raw/benchmarks/performance.md")
