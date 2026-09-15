# Generate the small, synthetic exports used in examples and tests.
#
# The values are deterministic and deliberately resemble the header grammars
# emitted by QuPath 0.7.0. No image or patient data are included.

set.seed(20260915)

out <- file.path("inst", "extdata")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

n <- 80L
fixture <- data.frame(
  `Cell ID` = sprintf("cell-%03d", seq_len(n)),
  `Centroid X um` = round(runif(n, 0, 512), 6),
  `Centroid Y um` = round(runif(n, 0, 512), 6),
  area_um2 = round(runif(n, 20, 160), 6),
  `DAPI: Mean` = round(rlnorm(n, log(100), 0.3), 6),
  `DAPI: Median` = round(rlnorm(n, log(90), 0.3), 6),
  `CD3e: Mean` = round(rlnorm(n, log(40), 0.4), 6),
  `CD3e: Median` = round(rlnorm(n, log(35), 0.4), 6),
  `Nucleus: CD3e: Mean` = round(rlnorm(n, log(42), 0.4), 6),
  `Cell Type` = rep(c("T cell", "B cell", "Other"), length.out = n),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
names(fixture)[names(fixture) == "area_um2"] <- paste0("Area ", "\u00b5m^2")

data.table::fwrite(
  fixture,
  file.path(out, "qupath-0.7.0-instanseg.tsv"),
  sep = "\t",
  quote = FALSE,
  na = "NA"
)

small <- fixture[seq_len(12L), c(1:4, 7, 9), drop = FALSE]
data.table::fwrite(
  small,
  file.path("tests", "testthat", "fixtures", "qupath-0.7.0-small.tsv"),
  sep = "\t",
  quote = FALSE,
  na = "NA"
)
