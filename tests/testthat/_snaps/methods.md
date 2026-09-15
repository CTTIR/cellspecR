# print() output is stable and fits in 80 columns

    Code
      print(x)
    Output
      <cellspec> spec 1.0.0
        cells     80 in 2 images (2 samples)
        features  19: 16 intensity, 2 shape, 1 other
        markers   4: DAPI, CD3e, Pan-Cytokeratin, FOXP3
        pixel     0.5 um/px
        adjacency none
        source    simulate 1.0.0 (cellspecR simulator 1.0.0)

---

    Code
      print(sim_object())
    Output
      <cellspec> spec 1.0.0
        cells     24 in 2 images (2 samples)
        features  9: 6 intensity, 2 shape, 1 other
        markers   3: DAPI, CD3e, FOXP3
        pixel     0.5 um/px
        adjacency 16 contacts
        source    simulate 1.0.0 (cellspecR simulator 1.0.0)

# summary() returns one row per image with exact values

    Code
      print(s)
    Output
      <cellspec summary> 1 image, 3 cells
       image_id sample_id n_cells n_markers n_features pixel_size x_min x_max y_min
           img1        s1       3         2          3        0.5     1     3     4
       y_max na_fraction
           6           0

# [ rejects ambiguous or invalid indices

    Code
      x[1]
    Condition
      Error in `x[1]`:
      ! Subset a <cellspec> object with two indices.
      i Use `x[i, ]` for cells and `x[, j]` for features.
    Code
      x[c(TRUE, FALSE), ]
    Condition
      Error in `x[c(TRUE, FALSE), ]`:
      ! Logical `i` must have one non-missing value per cells (24).
      x Got length 2.
    Code
      x[c(1, 1), ]
    Condition
      Error in `x[c(1, 1), ]`:
      ! `i` selects some cells more than once.
      i Duplicated cells would break the uniqueness of identifiers.
    Code
      x[c(-1, 2), ]
    Condition
      Error in `x[c(-1, 2), ]`:
      ! `i` cannot mix positive and negative positions.
    Code
      x[1000, ]
    Condition
      Error in `x[1000, ]`:
      ! `i` selects positions beyond the 24 cells.
    Code
      x[-1000, ]
    Condition
      Error in `x[-1000, ]`:
      ! Negative `i` is out of range (there are 24 cells).
    Code
      x["c1", ]
    Condition
      Error in `x["c1", ]`:
      ! `i` cannot be a character vector when selecting cells.
      i Select cells with a logical vector, e.g. `x[cs_cells(x)$image_id == "img1", ]`.
    Code
      x[, "nope"]
    Condition
      Error in `x[, "nope"]`:
      ! `j` must name existing features.
      x Unknown: "nope".
    Code
      x[NA_integer_, ]
    Condition
      Error in `x[NA_integer_, ]`:
      ! `i` must be logical, whole-number positions or (for features) identifiers.
      x Got an integer `NA`.
    Code
      x[1.5, ]
    Condition
      Error in `x[1.5, ]`:
      ! `i` must be logical, whole-number positions or (for features) identifiers.
      x Got a number.
