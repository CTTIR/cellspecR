# Deterministic synthetic cellspec objects for examples, tests and benchmarks.

#' A small synthetic cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Builds a small, deterministic `cellspec` object for examples and
#' experiments: two images from two samples, 40 cells each, four markers
#' (`DAPI`, `CD3e`, `Pan-Cytokeratin`, `FOXP3`) measured as mean and median
#' in the cell and nucleus compartments, cell and nucleus areas, and one
#' tool-specific column. The values are simulated, not measured. The random
#' number generator state of the session is left untouched.
#'
#' @return A valid `cellspec` object with 80 cells and 19 features.
#' @family object
#' @export
#' @examples
#' x <- cs_example()
#' x
#' cs_validate(x)
cs_example <- function() {
  .cs_simulate(
    n_cells = 40L,
    n_images = 2L,
    markers = c("DAPI", "CD3e", "Pan-Cytokeratin", "FOXP3"),
    compartments = c("cell", "nucleus"),
    statistics = c("mean", "median"),
    seed = 20260915L
  )
}

# Simulate a valid cellspec object. `n_cells` is per image. Leaves the global
# RNG state as it was.
.cs_simulate <- function(n_cells = 100L,
                         n_images = 1L,
                         markers = c("DAPI", "CD3e", "FOXP3"),
                         compartments = c("cell", "nucleus"),
                         statistics = "mean",
                         pixel_size = 0.5,
                         width_px = 1024L,
                         height_px = 1024L,
                         other = TRUE,
                         adjacency = FALSE,
                         seed = 1L) {
  .cs_with_seed(seed, {
    image_ids <- paste0("img", seq_len(n_images))
    sample_ids <- paste0("s", seq_len(n_images))
    n <- n_cells * n_images
    img <- rep(image_ids, each = n_cells)
    cells <- data.frame(
      cell_id = as.character(rep(seq_len(n_cells), times = n_images)),
      image_id = img,
      sample_id = rep(sample_ids, each = n_cells),
      x = stats::runif(n, 0, width_px * pixel_size),
      y = stats::runif(n, 0, height_px * pixel_size),
      area = round(stats::rlnorm(n, log(60), 0.3), 4),
      stringsAsFactors = FALSE
    )
    cells$x_px <- cells$x / pixel_size
    cells$y_px <- cells$y / pixel_size

    grid <- expand.grid(
      statistic = statistics,
      marker = markers,
      compartment = compartments,
      stringsAsFactors = FALSE
    )
    grid <- grid[, c("compartment", "marker", "statistic")]
    stat_label <- c(mean = "Mean", median = "Median", sd = "Std.Dev.", min = "Min",
                    max = "Max", sum = "Sum", variance = "Variance")
    comp_label <- c(cell = "Cell", nucleus = "Nucleus", cytoplasm = "Cytoplasm",
                    membrane = "Membrane")
    intensity <- data.frame(
      feature_id = paste(grid$compartment, grid$marker, grid$statistic, sep = ":"),
      kind = "intensity",
      marker = grid$marker,
      compartment = grid$compartment,
      statistic = grid$statistic,
      unit = "a.u.",
      source_name = paste0(comp_label[grid$compartment], ": ", grid$marker, ": ", stat_label[grid$statistic]),
      stringsAsFactors = FALSE
    )
    shape <- data.frame(
      feature_id = c("cell:area", "nucleus:area"),
      kind = "shape",
      marker = NA_character_,
      compartment = c("cell", "nucleus"),
      statistic = "area",
      unit = "um2",
      source_name = c("Cell: Area \u00b5m^2", "Nucleus: Area \u00b5m^2"),
      stringsAsFactors = FALSE
    )
    dictionary <- rbind(intensity, shape)
    if (other) {
      dictionary <- rbind(dictionary, data.frame(
        feature_id = "other:detection_probability",
        kind = "other",
        marker = NA_character_,
        compartment = NA_character_,
        statistic = "detection_probability",
        unit = "1",
        source_name = "Detection probability",
        stringsAsFactors = FALSE
      ))
    }

    # Per-cell expression level per marker; compartments and statistics are
    # noisy variations of it, so compartments correlate as in real data.
    level <- vapply(markers, function(mk) {
      positive <- stats::runif(n) < 0.3
      stats::rgamma(n, shape = 2, rate = 0.1) + positive * stats::rgamma(n, shape = 5, rate = 0.05)
    }, numeric(n))
    level <- matrix(level, nrow = n)
    colnames(level) <- markers
    m <- matrix(NA_real_, nrow = n, ncol = nrow(dictionary),
                dimnames = list(NULL, dictionary$feature_id))
    for (k in seq_len(nrow(intensity))) {
      base <- level[, intensity$marker[[k]]]
      factor <- switch(intensity$compartment[[k]], nucleus = 1.1, cytoplasm = 0.9, membrane = 0.8, 1)
      shift <- if (intensity$statistic[[k]] == "median") 0.95 else 1
      m[, k] <- round(base * factor * shift * stats::rlnorm(n, 0, 0.05), 4)
    }
    m[, "cell:area"] <- cells$area
    m[, "nucleus:area"] <- round(cells$area * stats::runif(n, 0.3, 0.5), 4)
    if (other) {
      m[, "other:detection_probability"] <- round(stats::runif(n, 0.5, 1), 4)
    }

    images <- data.frame(
      image_id = image_ids,
      sample_id = sample_ids,
      pixel_size = pixel_size,
      width_px = as.integer(width_px),
      height_px = as.integer(height_px),
      platform = "simulated",
      stringsAsFactors = FALSE
    )
    channels <- data.frame(
      image_id = rep(image_ids, each = length(markers)),
      channel_index = rep(seq_along(markers), times = n_images),
      channel_name = rep(markers, times = n_images),
      marker = rep(markers, times = n_images),
      stringsAsFactors = FALSE
    )

    adj <- NULL
    if (adjacency) {
      adj <- .cs_simulate_adjacency(cells, pixel_size)
    }

    provenance <- list(
      producer = list(tool = "cellspecR simulator", version = .cs_package_version()),
      reader = list(package = "cellspecR", version = .cs_package_version(),
                    adapter = "simulate", adapter_version = "1.0.0"),
      parameters = list(seed = seed, n_cells = n_cells, n_images = n_images)
    )
    x <- .cs_build(cells, m, dictionary, images, channels, provenance, adj, adapter = "simulate")
    x$provenance$created_utc <- "2026-01-01T00:00:00Z"
    x$provenance$history <- list(list(
      step = "create", "function" = ".cs_simulate", time_utc = "2026-01-01T00:00:00Z",
      details = list(seed = seed)
    ))
    x
  })
}

# Nearest neighbour of each cell within its image, as ordered unique pairs.
.cs_simulate_adjacency <- function(cells, pixel_size) {
  out <- list()
  for (img in unique(cells$image_id)) {
    r <- which(cells$image_id == img)
    if (length(r) < 2L) next
    d <- as.matrix(stats::dist(cbind(cells$x[r], cells$y[r])))
    diag(d) <- Inf
    nn <- apply(d, 1L, which.min)
    a <- cells$cell_id[r]
    b <- cells$cell_id[r][nn]
    lo <- ifelse(.cs_byte_less(a, b), a, b)
    hi <- ifelse(.cs_byte_less(a, b), b, a)
    pairs <- unique(data.frame(cell_id_a = lo, cell_id_b = hi, stringsAsFactors = FALSE))
    out[[img]] <- data.frame(
      image_id = img,
      cell_id_a = pairs$cell_id_a,
      cell_id_b = pairs$cell_id_b,
      shared_boundary = round(stats::runif(nrow(pairs), 1, 10) * pixel_size, 4),
      method = "mask_touching",
      stringsAsFactors = FALSE
    )
  }
  res <- do.call(rbind, out)
  attr(res, "row.names") <- .set_row_names(nrow(res))
  res
}

# Evaluate `expr` with a fixed seed and restore the caller's RNG state.
.cs_with_seed <- function(seed, expr) {
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  if (had_seed) {
    old <- get(".Random.seed", envir = env, inherits = FALSE)
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old, envir = env) # nolint: object_name_linter.
    } else if (exists(".Random.seed", envir = env, inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
  }, add = TRUE)
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  expr
}
