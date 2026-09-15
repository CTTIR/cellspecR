# Package index

## Specification

- [`cs_spec_version()`](https://cttir.github.io/cellspecR/reference/cs_spec_version.md)
  **\[experimental\]** : Version of the cellspec specification
- [`cs_vocabulary()`](https://cttir.github.io/cellspecR/reference/cs_vocabulary.md)
  **\[experimental\]** : Columns and controlled vocabularies of the
  cellspec format

## Object

- [`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md)
  **\[experimental\]** : Create a cellspec object
- [`cs_cells()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_measurements()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_dictionary()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_images()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_channels()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_provenance()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  [`cs_adjacency()`](https://cttir.github.io/cellspecR/reference/cs_accessors.md)
  **\[experimental\]** : Access the components of a cellspec object
- [`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md)
  [`cs_markers()`](https://cttir.github.io/cellspecR/reference/cs_features.md)
  **\[experimental\]** : Select features and markers by their dictionary
  entries
- [`is_cellspec()`](https://cttir.github.io/cellspecR/reference/is_cellspec.md)
  **\[experimental\]** : Test for a cellspec object

## Validation

- [`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)
  [`cs_assert_valid()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)
  **\[experimental\]** : Validate a cellspec object
- [`cs_feature_support()`](https://cttir.github.io/cellspecR/reference/cs_feature_support.md)
  **\[experimental\]** : Summarise the signal support of features per
  image

## Readers and storage

- [`cs_formats()`](https://cttir.github.io/cellspecR/reference/cs_formats.md)
  **\[experimental\]** : List the available cellspec readers
- [`cs_detect_format()`](https://cttir.github.io/cellspecR/reference/cs_detect_format.md)
  **\[experimental\]** : Detect the generic table format
- [`cs_column_map()`](https://cttir.github.io/cellspecR/reference/cs_column_map.md)
  **\[experimental\]** : Validate a table column map
- [`cs_read()`](https://cttir.github.io/cellspecR/reference/cs_read.md)
  **\[experimental\]** : Read a delimited table into a cellspec object
- [`cs_read_cellspec()`](https://cttir.github.io/cellspecR/reference/cs_read_cellspec.md)
  **\[experimental\]** : Read a canonical cellspec directory
- [`cs_verify()`](https://cttir.github.io/cellspecR/reference/cs_verify.md)
  **\[experimental\]** : Verify a canonical cellspec directory
- [`cs_write()`](https://cttir.github.io/cellspecR/reference/cs_write.md)
  **\[experimental\]** : Write a cellspec directory
- [`cs_bind()`](https://cttir.github.io/cellspecR/reference/cs_bind.md)
  : Combine cellspec objects from different images
- [`cs_merge_tiles()`](https://cttir.github.io/cellspecR/reference/cs_merge_tiles.md)
  : Merge tiled cellspec objects using centroid ownership

## Signals

- [`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md)
  **\[experimental\]** : Create a signal selection policy
- [`cs_signal_matrix()`](https://cttir.github.io/cellspecR/reference/cs_signal_matrix.md)
  **\[experimental\]** : Select one signal per cell and marker
- [`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md)
  **\[experimental\]** : Create a marker-name mapping
- [`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md)
  **\[experimental\]** : Read a signal policy from JSON or CSV
- [`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)
  **\[experimental\]** : Write a signal policy as JSON or CSV

## Interoperability and app

- [`cs_as_spe()`](https://cttir.github.io/cellspecR/reference/cs_as_spe.md)
  **\[experimental\]** : Convert a cellspec object to SpatialExperiment
- [`cs_from_spe()`](https://cttir.github.io/cellspecR/reference/cs_from_spe.md)
  **\[experimental\]** : Convert a SpatialExperiment back to cellspec
- [`cs_as_anndata()`](https://cttir.github.io/cellspecR/reference/cs_as_anndata.md)
  **\[experimental\]** : Convert a cellspec object to AnnData
- [`cs_app()`](https://cttir.github.io/cellspecR/reference/cs_app.md)
  **\[experimental\]** : Create the cellspec review application

## Methods

- [`print(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md)
  [`summary(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md)
  [`print(`*`<cellspec_summary>`*`)`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md)
  [`dim(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md)
  **\[experimental\]** : Print, summarise and measure a cellspec object
- [`as.data.frame(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md)
  [`as_tibble(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/as.data.frame.cellspec.md)
  **\[experimental\]** : Convert a cellspec object to a data frame
- [`` `[`( ``*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/sub-.cellspec.md)
  **\[experimental\]** : Subset a cellspec object by cells and features
- [`plot(`*`<cellspec>`*`)`](https://cttir.github.io/cellspecR/reference/plot.cellspec.md)
  **\[experimental\]** : Plot cellspec quality-control views

## Examples

- [`cs_example()`](https://cttir.github.io/cellspecR/reference/cs_example.md)
  **\[experimental\]** : A small synthetic cellspec object

## Package

- [`cellspecR`](https://cttir.github.io/cellspecR/reference/cellspecR-package.md)
  [`cellspecR-package`](https://cttir.github.io/cellspecR/reference/cellspecR-package.md)
  **\[experimental\]** : cellspecR: Read, Validate and Store Multiplexed
  Imaging Cell Tables
