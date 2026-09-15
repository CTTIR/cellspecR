# cellspecR: Read, Validate and Store Multiplexed Imaging Cell Tables

**\[experimental\]**

cellspecR defines `cellspec`, one table format for segmented cells from
multiplexed tissue images, reads the exports of common image-analysis
tools into it, checks the result, and writes it to disk with a checksum
manifest so that later analysis steps can prove what they read.

The format is described in
[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md).

## Main functions

- Specification:
  [`cs_spec_version()`](https://cttir.github.io/cellspecR/reference/cs_spec_version.md),
  [`cs_vocabulary()`](https://cttir.github.io/cellspecR/reference/cs_vocabulary.md).

- Object:
  [`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md),
  [`cs_cells()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_measurements()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_dictionary()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_images()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_channels()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_provenance()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_adjacency()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md),
  [`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
  [`cs_markers()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
  [`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md).

- Methods:
  [`print.cellspec()`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md),
  [`summary.cellspec()`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md),
  [`dim.cellspec()`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md),
  `[.cellspec`,
  [`as.data.frame.cellspec()`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md).

## See also

Useful links:

- <https://github.com/CTTIR/cellspecR>

- <https://cttir.github.io/cellspecR/>

- Report bugs at <https://github.com/CTTIR/cellspecR/issues>

## Author

**Maintainer**: R. Heller <raban.heller@uni-ulm.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

Authors:

- R. Heller <raban.heller@uni-ulm.de>
  ([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]
