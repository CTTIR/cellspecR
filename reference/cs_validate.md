# Validate a cellspec object

**\[experimental\]**

`cs_validate()` checks an object against the `cellspec` specification
and returns a report with one row per check. `cs_assert_valid()` runs
the same checks and aborts when any check fails.

`level = "structure"` runs the MUST rules of the specification: required
columns and types, unique keys, finite centroids, dictionary vocabulary,
alignment of measurements, channels and optional adjacency. A failing
structure check means other packages cannot rely on the object.

`level = "semantic"` adds plausibility checks that produce warnings, not
failures: centroids outside the image, implausible cell areas, negative
intensities, features with many missing values, markers without usable
signal
([`cs_feature_support()`](https://cttir.github.io/cellspecR/reference/cs_feature_support.md))
and duplicated centroids, which usually indicate cells counted twice
when tiles were merged.

## Usage

``` r
cs_validate(
  x,
  level = c("structure", "semantic"),
  area_range = c(1, 5000),
  na_max = 0.01
)

cs_assert_valid(x, level = "structure", call = rlang::caller_env())
```

## Arguments

- x:

  A `cellspec` object.

- level:

  `"structure"` or `"semantic"` (structure plus semantic checks).

- area_range:

  Numeric vector of length 2: plausible whole-cell area in square
  micrometres for the `area_range` check.

- na_max:

  Largest acceptable fraction of missing values per feature for the
  `feature_na_fraction` check.

- call:

  The execution environment used in error messages; internal callers
  pass their own.

## Value

`cs_validate()` returns a data frame of class `cellspec_validation` with
one row per check and the columns `check` (character), `level`
(`"structure"` or `"semantic"`), `status` (`"pass"`, `"warn"`, `"fail"`,
or `"skip"` when a prerequisite check failed), `n` (integer number of
offending rows, features or values) and `message` (character, naming
columns or features and up to five examples). Rows are in catalogue
order; [`print()`](https://rdrr.io/r/base/print.html) shows failures
first.

`cs_assert_valid()` returns `x` invisibly, or aborts with an error of
class `cellspec_error_invalid` whose `report` field holds the report.

## See also

[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md)

Other validation:
[`cs_feature_support()`](https://cttir.github.io/cellspecR/reference/cs_feature_support.md)

## Examples

``` r
x <- cs_example()
cs_validate(x)
#> <cellspec validation> 45 checks: 0 fail, 0 warn, 0 skip, 45 pass
#> pass 45 other checks
report <- cs_validate(x, level = "semantic")
report[report$status != "pass", ]
#> <cellspec validation> 0 checks: 0 fail, 0 warn, 0 skip, 0 pass

# A broken object fails with a classed error
bad <- x
bad$cells$x[1] <- NA
try(cs_assert_valid(bad))
#> Error in eval(expr, envir) : 
#>   `x` is not a valid <cellspec> object (1 failing check).
#> ✖ cells_coordinates_finite: 1 cell with a missing or non-finite `x` or `y`,
#>   e.g. "img1/1".
```
