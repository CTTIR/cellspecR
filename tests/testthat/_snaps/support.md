# cs_feature_support() validates its arguments

    Code
      cs_feature_support(x, features = "nope")
    Condition
      Error in `cs_feature_support()`:
      ! `features` must name existing features.
      x Unknown feature: "nope".
    Code
      cs_feature_support(x, features = 1)
    Condition
      Error in `cs_feature_support()`:
      ! `features` must be a character vector of feature identifiers.
      x Got a number.
    Code
      cs_feature_support(x, zero_tol = -1)
    Condition
      Error in `cs_feature_support()`:
      ! `zero_tol` must be a single finite number >= 0.
      x Got a number.
    Code
      cs_feature_support(list())
    Condition
      Error in `cs_feature_support()`:
      ! `x` must be a <cellspec> object.
      x Got an empty list.
      i Build one with `cs_new()` or `cs_read()`.
