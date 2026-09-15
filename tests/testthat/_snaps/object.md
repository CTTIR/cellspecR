# cs_new() rejects malformed inputs with informative errors

    Code
      cs_new(p$cells, p$measurements, NULL, p$images, p$channels)
    Condition
      Error in `cs_new()`:
      ! `dictionary` is required when `measurements` has columns.
      i Describe each of the 3 measurement columns with one dictionary row.
    Code
      cs_new(list(1), images = p$images)
    Condition
      Error in `cs_new()`:
      ! `cells` must be a data frame.
      x Got a list.
    Code
      cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels, provenance = "x")
    Condition
      Error in `cs_new()`:
      ! `provenance` must be a list or `NULL`.
      x Got a string.
    Code
      cs_new(p$cells, data.frame(a = "x"), p$dictionary, p$images, p$channels)
    Condition
      Error in `cs_new()`:
      ! `measurements` must contain numeric columns only.
      x Non-numeric column: "a".
    Code
      cs_new(p$cells, "x", p$dictionary, p$images, p$channels)
    Condition
      Error in `cs_new()`:
      ! `measurements` must be a numeric matrix or data frame.
      x Got a string.
    Code
      cs_new(p$cells, unname(p$measurements), p$dictionary, p$images, p$channels)
    Condition
      Error in `cs_new()`:
      ! `measurements` must have column names equal to `dictionary$feature_id`.

# cs_new() aborts with cellspec_error_invalid on rule violations

    Code
      cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
    Condition
      Error in `cs_new()`:
      ! `x` is not a valid <cellspec> object (1 failing check).
      x cells_key_unique: 2 rows of `cells` share an `(image_id, cell_id)` key with another row, e.g. "img1/c1".

# accessors return components and reject other objects

    Code
      cs_cells(list())
    Condition
      Error in `cs_cells()`:
      ! `x` must be a <cellspec> object.
      x Got an empty list.
      i Build one with `cs_new()` or `cs_read()`.
