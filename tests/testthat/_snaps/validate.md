# failure messages are informative

    Code
      writeLines(msgs)
    Output
      object_class: Object is of class `list`, not `cellspec`.
      object_components: Components missing: `images`.
      spec_version: `spec_version` "2.0.0" has an unsupported major version; this build supports 1.x.
      cells_required_columns: `cells` lacks required column: `y`.
      cells_column_types: 1 column of `cells` has the wrong type: `x` (character, expected double).
      cells_reserved_names: 1 `cells` column name violates the reserved-name rules: `cs__tmp`. `cs__` is internal; layer names must match ^[A-Za-z0-9][A-Za-z0-9_.-]*$.
      cells_subject_id: `cells` has a `subject_id` column; subject identifiers belong in `images`.
      cells_ids_present: 1 row of `cells` with a missing or empty `cell_id`, `image_id` or `sample_id` (rows 1).
      cells_key_unique: 2 rows of `cells` share an `(image_id, cell_id)` key with another row, e.g. "img1/1".
      cells_coordinates_finite: 1 cell with a missing or non-finite `x` or `y`, e.g. "img1/1".
      cells_area_positive: 1 cell with a non-positive or infinite `area`, e.g. "img1/1".
      cells_images_known: 1 cell refers to `image_id` values missing from `images`: "img9".
      cells_sample_consistent: 1 cell whose `sample_id` differs from the `sample_id` of their image, e.g. "img1/1".
      measurements_type: `measurements` has storage type integer; it must be double.
      measurements_rows: `measurements` has 23 rows but `cells` has 24.
      measurements_names: Measurement column names do not equal `dictionary$feature_id` (not in dictionary: "cell:Other:mean"; missing from measurements: "cell:DAPI:mean").
      measurements_finite: 1 `NaN` or infinite value in `measurements`, in feature "cell:DAPI:mean"; convert them to `NA`.
      dictionary_required_columns: `dictionary` lacks required column: `unit`.
      dictionary_column_types: 1 column of `dictionary` has the wrong type: `marker_source` (numeric, expected character).
      dictionary_feature_id_unique: 1 dictionary row with a missing or duplicated `feature_id`, e.g. "other:detection_probability".
      dictionary_kind: 1 feature with an unknown `kind`, e.g. "other:detection_probability" (kinds: "texture").
      dictionary_intensity: 1 intensity feature without a marker, or with a compartment or statistic outside the vocabulary: "cell:DAPI:p95".
      dictionary_shape: 1 shape feature with a marker, or with a compartment or statistic outside the vocabulary: "cell:area".
      dictionary_other: 1 other feature with a marker, an unknown compartment or no statistic: "other:detection_probability".
      dictionary_unit: 1 feature with a unit outside the vocabulary, e.g. "cell:area" (units: "µm^2").
      dictionary_marker_names: 2 features with an empty, untrimmed or colon-containing marker name: " CD3e".
      dictionary_feature_id_format: 1 feature identifier not following `<compartment>:<marker>:<statistic>`, `<compartment>:<statistic>` or `other:<name>`: "DAPI_mean".
      dictionary_source_name: 1 feature without `source_name`: "cell:DAPI:mean".
      images_required_columns: `images` lacks required column: `pixel_size`.
      images_column_types: 1 column of `images` has the wrong type: `width_px` (character, expected integer).
      images_id_unique: 1 `images` row with a missing or duplicated `image_id`, e.g. "img1".
      images_sample_present: 1 image without `sample_id`, e.g. "img1".
      images_pixel_size: 1 image with a missing or non-positive `pixel_size`, e.g. "img1".
      images_dimensions: 1 image with non-positive `width_px` or `height_px`, e.g. "img1".
      channels_required_columns: `channels` lacks required column: `marker`.
      channels_column_types: 1 column of `channels` has the wrong type: `channel_index` (character, expected integer).
      channels_images_known: 1 channel row refers to `image_id` values missing from `images`: "img9".
      channels_index_contiguous: 1 image whose `channel_index` is not 1..n: "img1".
      channels_names: 1 channel row with an empty name or marker, or a marker used twice in one image.
      markers_in_channels: 1 image/marker combination without a channel, e.g. "img2/FOXP3".
      provenance_fields: `provenance` lacks field: `history`.
      adjacency_columns: `adjacency` lacks `method`.
      adjacency_endpoints: 1 contact with an endpoint missing from `cells`, e.g. "img1/999".
      adjacency_pairs: 1 contact not ordered as `cell_id_a < cell_id_b` or listed twice, e.g. "img1/2-1".
      adjacency_values: 1 contact with a negative or missing `shared_boundary` or an unknown `method` (rows 1).

# semantic checks warn about implausible content

    Code
      print(r)
    Output
      <cellspec validation> 51 checks: 0 fail, 6 warn, 0 skip, 45 pass
      WARN centroids_within_image: 1 cell with a centroid more than one pixel outside the image, e.g. "img1/1".
      WARN area_range: 2 cells with `area` outside 1-5000 square micrometres, e.g. "img1/2", "img1/3".
      WARN negative_intensity: 1 negative intensity value in 1 feature: cell:CD3e:mean (1).
      WARN feature_na_fraction: 1 feature with more than 1% missing values: nucleus:DAPI:mean (12.5%).
      WARN feature_support: 1 image/feature combination without usable signal: "img2/cell:FOXP3:mean (constant)".
      WARN duplicate_centroids: 1 cell sharing a centroid with an earlier cell of the same image (possible tile-merge duplicates), e.g. "img1/6".
      pass 45 other checks

# print() lists fails first and summarises passes

    Code
      print(cs_validate(x))
    Output
      <cellspec validation> 45 checks: 3 fail, 0 warn, 0 skip, 42 pass
      FAIL cells_key_unique: 2 rows of `cells` share an `(image_id, cell_id)` key with another row, e.g. "img1/1".
      FAIL images_pixel_size: 2 images with a missing or non-positive `pixel_size`, e.g. "img1", "img2".
      FAIL adjacency_endpoints: 1 contact with an endpoint missing from `cells`, e.g. "img1/2".
      pass 42 other checks

# cs_assert_valid() returns the object or aborts with the report

    Code
      cs_assert_valid(bad)
    Condition
      Error:
      ! `x` is not a valid <cellspec> object (2 failing checks).
      x cells_coordinates_finite: 12 cells with a missing or non-finite `x` or `y`, e.g. "img1/1", "img1/2", "img1/3", "img1/4", "img1/5" and 7 more.
      x images_pixel_size: 2 images with a missing or non-positive `pixel_size`, e.g. "img1", "img2".

# cs_assert_valid() abbreviates reports with many failures

    Code
      cs_assert_valid(x)
    Condition
      Error:
      ! `x` is not a valid <cellspec> object (12 failing checks).
      x cells_reserved_names: 1 `cells` column name violates the reserved-name rules: `cs__a`. `cs__` is internal; layer names must match ^[A-Za-z0-9][A-Za-z0-9_.-]*$.
      x cells_subject_id: `cells` has a `subject_id` column; subject identifiers belong in `images`.
      x cells_coordinates_finite: 1 cell with a missing or non-finite `x` or `y`, e.g. "img1/1".
      x cells_area_positive: 1 cell with a non-positive or infinite `area`, e.g. "img1/2".
      x measurements_finite: 1 `NaN` or infinite value in `measurements`, in feature "cell:DAPI:mean"; convert them to `NA`.
      x dictionary_unit: 1 feature with a unit outside the vocabulary, e.g. "cell:DAPI:mean" (units: "bad").
      x dictionary_source_name: 1 feature without `source_name`: "cell:CD3e:mean".
      x images_pixel_size: 2 images with a missing or non-positive `pixel_size`, e.g. "img1", "img2".
      x images_dimensions: 2 images with non-positive `width_px` or `height_px`, e.g. "img1", "img2".
      x channels_names: 1 channel row with an empty name or marker, or a marker used twice in one image.
      i 2 more failing checks; run `cs_validate()` for the full report.
