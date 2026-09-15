# The cellspec 1.0 format

This document is the normative description of `cellspec` 1.0.0, the
table format for segmented cells from multiplexed tissue images. The key
words **MUST**, **SHOULD** and **MAY** are used as in RFC 2119. Every
table below is generated from the objects that the validator uses
([`cs_vocabulary()`](https://cttir.github.io/cellspecR/reference/cs_vocabulary.md)),
so the text and the checks cannot drift apart.

## 1. Object

A `cellspec` object is a list of class `"cellspec"` with these
components:

| Component | Type | Required | Content |
|----|----|----|----|
| `spec_version` | string | yes | `"1.0.0"` |
| `cells` | data frame | yes | one row per cell: identity and geometry (section 2) |
| `measurements` | double matrix | yes (may have 0 columns) | cells x features, rows in the order of `cells` (section 3) |
| `dictionary` | data frame | yes | one row per measurement column (section 4) |
| `images` | data frame | yes | one row per image (section 5) |
| `channels` | data frame | yes | one row per image and channel (section 5) |
| `provenance` | list | yes | origin of the data (section 6) |
| `adjacency` | data frame or `NULL` | no | cell-cell contacts (section 7) |

A whole slide carries up to about 1,000 numeric features for millions of
cells. A double matrix stores them compactly and maps directly to an
assay of a `SpatialExperiment`; `cells` stays a data frame because it
holds mixed types. Accessors return plain data frames. Rows of
`measurements` are aligned with `cells` by position; row names are not
used.

``` r

x <- cs_example()
x
#> <cellspec> spec 1.0.0
#>   cells     80 in 2 images (2 samples)
#>   features  19: 16 intensity, 2 shape, 1 other
#>   markers   4: DAPI, CD3e, Pan-Cytokeratin, FOXP3
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    simulate 1.0.0 (cellspecR simulator 0.0.0.9000)
```

## 2. Cells

| Column | Type | Requirement | Meaning |
|:---|:---|:---|:---|
| `cell_id` | character | MUST | Cell identifier, unique within `image_id`, never recycled. |
| `image_id` | character | MUST | Key into `images`. |
| `sample_id` | character | MUST | Biological sample (slide or section); constant per image. |
| `x` | double | MUST | Centroid, micrometres, image frame. |
| `y` | double | MUST | Centroid, micrometres, image frame. |
| `area` | double | SHOULD | Whole-cell area, square micrometres. |
| `x_px` | double | MAY | Centroid in full-resolution pixels. |
| `y_px` | double | MAY | Centroid in full-resolution pixels. |
| `object_type` | character | MAY | Object type as exported by the tool, e.g. `cell`. |
| `parent` | character | MAY | Parent annotation name as exported by the tool. |
| `classification` | character | MAY | Class assigned inside the source tool. |
| `tile_id` | character | MAY | Tile that owns the cell in tiled runs. |
| `region__<layer>` | character | MAY | Region label for annotation layer `<layer>`. |
| `boundary_distance__<layer>` | double | MAY | Signed distance to the region boundary of `<layer>`, micrometres, negative inside. |

Rules:

- The key `(image_id, cell_id)` MUST be unique.
- `x` and `y` MUST be finite. `area`, when present, MUST be positive or
  `NA`.
- Identifiers are character columns, never row names.
- Additional columns are allowed and SHOULD be snake_case. The prefixes
  `region__` and `boundary_distance__` are reserved for region
  annotations and `cs__` for internal use. A layer name MUST match
  `^[A-Za-z0-9][A-Za-z0-9_.-]*$`.
- `cells` MUST NOT contain clinical variables; `subject_id` belongs in
  `images`.

## 3. Measurements

- A double matrix with one row per cell.
- Column names are feature identifiers and MUST equal
  `dictionary$feature_id`, in the same order.
- Values are kept as exported by the source tool, in raw units. No
  transformation is applied on import. `NaN` and infinite values from
  sources are converted to `NA` and counted in `provenance$counts`.

## 4. Dictionary

| Column | Type | Requirement | Meaning |
|:---|:---|:---|:---|
| `feature_id` | character | MUST | Unique key; equals the measurement column name. |
| `kind` | character | MUST | `intensity`, `shape` or `other`. |
| `marker` | character | MUST | Marker name for intensity features, otherwise `NA`. |
| `compartment` | character | MUST | Compartment for intensity and shape features, otherwise `NA`. |
| `statistic` | character | MUST | Statistic from the vocabulary (free text for `other`). |
| `unit` | character | MUST | Unit from the vocabulary. |
| `source_name` | character | MUST | The exact original column header. |
| `marker_source` | character | MAY | Marker name before applying a marker map. |

Controlled vocabularies:

- `kind`: `intensity`, `shape`, `other`.
- `compartment`: `cell`, `nucleus`, `cytoplasm`, `membrane`, or `NA` for
  `other` features.
- `statistic` for intensity features: `mean`, `median`, `sd`, `min`,
  `max`, `sum`, `variance`.
- `statistic` for shape features: `area`, `perimeter`, `length`,
  `circularity`, `solidity`, `max_diameter`, `min_diameter`,
  `max_caliper`, `min_caliper`, `eccentricity`, `major_axis_length`,
  `minor_axis_length`, `extent`, `orientation`,
  `nucleus_cell_area_ratio`. Unknown shape measurements are stored as
  `kind = "other"`, never dropped.
- `unit`: `a.u.`, `um`, `um2`, `px`, `px2`, `rad`, `1`.

Feature identifiers are generated by readers and follow one rule per
kind:

| Kind | Identifier | Example |
|----|----|----|
| intensity | `<compartment>:<marker>:<statistic>` | `nucleus:FOXP3:mean` |
| shape | `<compartment>:<statistic>` | `cell:area` |
| other | `other:<name>` | `other:detection_probability` |

Downstream code MUST select features through their dictionary columns,
for example with
[`cs_features()`](https://cttir.github.io/cellspecR/reference/cs_features.md),
and not by splitting identifiers. Marker names MUST be trimmed and MUST
NOT contain `:`. Because identifiers follow the rule above and are
unique, no two features can describe the same kind, marker, compartment
and statistic.

``` r

cs_features(x, kind = "intensity", marker = "FOXP3")
#> [1] "cell:FOXP3:mean"      "cell:FOXP3:median"    "nucleus:FOXP3:mean"  
#> [4] "nucleus:FOXP3:median"
```

## 5. Images and channels

| Column | Type | Requirement | Meaning |
|:---|:---|:---|:---|
| `image_id` | character | MUST | Unique image identifier. |
| `sample_id` | character | MUST | Biological sample of the image. |
| `subject_id` | character | MAY | Pseudonymised subject identifier. |
| `pixel_size` | double | MUST | Micrometres per pixel at full resolution. |
| `pixel_size_y` | double | MAY | Only when pixels are not square. |
| `width_px` | integer | SHOULD | Full-resolution width in pixels. |
| `height_px` | integer | SHOULD | Full-resolution height in pixels. |
| `platform` | character | MAY | Imaging platform, e.g. `PhenoCycler-Fusion`. |
| `source_image` | character | MAY | Image file name (not a full path). |
| `source_image_sha256` | character | MAY | SHA-256 of the image file. |
| `geometry_ref` | character | MAY | Relative path to a GeoJSON file of cell outlines. |

| Column | Type | Requirement | Meaning |
|:---|:---|:---|:---|
| `image_id` | character | MUST | Key into `images`. |
| `channel_index` | integer | MUST | 1-based, contiguous per image. |
| `channel_name` | character | MUST | Channel name as stored in the image. |
| `marker` | character | MUST | Marker after mapping; equals `channel_name` when unmapped. |

Every intensity marker in the dictionary MUST appear in
`channels$marker` for every image of the object. A channel without
measurements is allowed, for example a nuclear stain used only for
segmentation.

## 6. Provenance

`provenance` is a list with at least these fields:

| Field | Content |
|----|----|
| `producer` | `tool` and `version` of the software that measured the cells |
| `reader` | `package`, `version`, `adapter` and `adapter_version` that built the object |
| `created_utc` | creation time, `YYYY-MM-DDTHH:MM:SSZ` |
| `inputs` | one entry per input file: `path_basename`, `bytes`, `sha256` |
| `counts` | `rows_read`, `rows_kept`, `na_converted`, `nonfinite_converted` |
| `parameters` | reader parameters, e.g. where the pixel size came from |
| `history` | steps that changed content: `step`, `function`, `time_utc`, `details` |

Input paths are stored as file names plus hash. Full paths leak private
directory structures and are stored only when a user explicitly asks for
it.

## 7. Adjacency (optional)

| Column | Type | Requirement | Meaning |
|:---|:---|:---|:---|
| `image_id` | character | MUST | Image of both cells. |
| `cell_id_a` | character | MUST | Smaller cell identifier of the pair (byte order). |
| `cell_id_b` | character | MUST | Larger cell identifier of the pair. |
| `shared_boundary` | double | MUST | Shared boundary length, micrometres. |
| `method` | character | MUST | How contacts were derived. |

`method` is one of `mask_touching`, `polygon_intersection`, `delaunay`.
Each unordered pair of cells appears at most once, ordered so that
`cell_id_a` sorts before `cell_id_b` in byte order, and both cells MUST
exist in `cells`. Subsetting an object drops contacts whose cells were
removed.

## 8. Coordinate frame and units

- The origin is the top-left corner of the top-left full-resolution
  pixel; x increases to the right and y increases downward (the QuPath
  convention).
- The centre of the pixel with 0-based index `i` lies at
  `(i + 0.5) * pixel_size`.
- Centroids `x` and `y` are in micrometres. Readers that receive pixel
  centroids MUST know the pixel size, from the file or from an argument,
  and MUST stop otherwise.
- When a tool reports both micrometre and pixel centroids, readers check
  that `abs(x - x_px * pixel_size) <= 0.5 * pixel_size` and stop on
  disagreement.
- The micro sign appears in exports as U+00B5, U+03BC, `um` or the
  mis-decoded `Âµ`. Readers normalise these variants before matching
  headers and keep the original header in `source_name`.

## 9. Directory layout

A `cellspec` directory holds one object on disk:

    <dir>/
      cells.parquet       cells columns, then one column per feature_id
      cellspec.json       spec_version, column types, dictionary, images,
                          channels, provenance
      adjacency.parquet   optional
      MANIFEST.sha256     "<sha256>  <relative path>" for every file above
      DONE                written last; holds the SHA-256 of MANIFEST.sha256

- The cell table is stored as Parquet by default, which keeps every
  double bit-exact. A tab-separated alternative (`cells.tsv.gz`,
  `adjacency.tsv.gz`) is readable by any tool; its numbers carry 15
  significant digits, so values can differ from the originals in the
  last representable digits.
- `cellspec.json` validates against the JSON Schema shipped in
  `system.file("schema", "cellspec-1.0.0.schema.json", package = "cellspecR")`.
- Writers stage the directory under a temporary name and rename it at
  the end, so a directory without `DONE` was not completely written.
- Readers refuse a directory without `DONE`, with a manifest mismatch,
  or with an unsupported major `spec_version`.

## 10. Validation rules

[`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)
checks an object against the rules above. Structure checks implement the
MUST rules and fail; semantic checks flag implausible content and warn.

| Check | Level | Rule |
|:---|:---|:---|
| `object_class` | structure | The object is a list of class `cellspec`. |
| `object_components` | structure | All components exist and have the right container type. |
| `spec_version` | structure | `spec_version` is a version string with a supported major version. |
| `cells_required_columns` | structure | `cells` has every MUST column and no duplicated names. |
| `cells_column_types` | structure | Specified `cells` columns have their specified types. |
| `cells_reserved_names` | structure | No `cs__` columns; region layer names are valid. |
| `cells_subject_id` | structure | `cells` carries no `subject_id` (it belongs in `images`). |
| `cells_ids_present` | structure | `cell_id`, `image_id` and `sample_id` are non-missing and non-empty. |
| `cells_key_unique` | structure | `(image_id, cell_id)` is unique. |
| `cells_coordinates_finite` | structure | `x` and `y` are finite. |
| `cells_area_positive` | structure | `area` is positive or `NA`. |
| `cells_images_known` | structure | Every `cells$image_id` exists in `images`. |
| `cells_sample_consistent` | structure | `cells$sample_id` equals the `sample_id` of its image. |
| `measurements_type` | structure | `measurements` is a double matrix. |
| `measurements_rows` | structure | `measurements` has one row per cell. |
| `measurements_names` | structure | Measurement column names equal `dictionary$feature_id`, in order. |
| `measurements_finite` | structure | `measurements` holds no `NaN` or infinite values. |
| `dictionary_required_columns` | structure | `dictionary` has every MUST column. |
| `dictionary_column_types` | structure | `dictionary` columns are character. |
| `dictionary_feature_id_unique` | structure | `feature_id` is non-missing and unique. |
| `dictionary_kind` | structure | `kind` is `intensity`, `shape` or `other`. |
| `dictionary_intensity` | structure | Intensity features have a marker, a compartment and an intensity statistic. |
| `dictionary_shape` | structure | Shape features have a compartment, a shape statistic and no marker. |
| `dictionary_other` | structure | Other features have a statistic and no marker. |
| `dictionary_unit` | structure | `unit` is from the unit vocabulary. |
| `dictionary_marker_names` | structure | Marker names are trimmed, non-empty and contain no `:`. |
| `dictionary_feature_id_format` | structure | `feature_id` follows the naming rule of its kind (so no two features share kind, marker, compartment and statistic). |
| `dictionary_source_name` | structure | `source_name` is non-missing and non-empty. |
| `images_required_columns` | structure | `images` has every MUST column. |
| `images_column_types` | structure | Specified `images` columns have their specified types. |
| `images_id_unique` | structure | `image_id` is non-missing, non-empty and unique. |
| `images_sample_present` | structure | `images$sample_id` is non-missing and non-empty. |
| `images_pixel_size` | structure | `pixel_size` (and `pixel_size_y`) is finite and positive. |
| `images_dimensions` | structure | `width_px` and `height_px` are positive or `NA`. |
| `channels_required_columns` | structure | `channels` has every MUST column. |
| `channels_column_types` | structure | `channels` columns have their specified types. |
| `channels_images_known` | structure | Every `channels$image_id` exists in `images`. |
| `channels_index_contiguous` | structure | `channel_index` is 1, 2, …, n within each image. |
| `channels_names` | structure | Channel names and markers are non-empty; markers are unique per image. |
| `markers_in_channels` | structure | Every intensity marker is a channel marker of every image. |
| `provenance_fields` | structure | `provenance` has every required field. |
| `adjacency_columns` | structure | `adjacency` has every MUST column with its type. |
| `adjacency_endpoints` | structure | Both cells of every contact exist in `cells`. |
| `adjacency_pairs` | structure | Pairs are ordered (`cell_id_a < cell_id_b`) and listed once. |
| `adjacency_values` | structure | `shared_boundary` is finite and non-negative; `method` is known. |
| `centroids_within_image` | semantic | Centroids lie inside the image extent (1 pixel tolerance). |
| `area_range` | semantic | `area` lies inside `area_range`. |
| `negative_intensity` | semantic | Intensity features hold no negative values. |
| `feature_na_fraction` | semantic | No feature has more than `na_max` missing values. |
| `feature_support` | semantic | Mean intensity features have usable variation in every image. |
| `duplicate_centroids` | semantic | No two cells of one image share a centroid. |

## 11. Versioning

- `spec_version` follows semantic versioning. Minor versions only add
  optional columns or components.
- A reader of major version 1 accepts every 1.y object whose minor
  version is not newer than its own.
- Readers of tool exports carry their own `adapter_version`, which
  changes whenever their output for the same input changes.
