# Columns and controlled vocabularies of the cellspec format

**\[experimental\]**

Returns the specification tables as data: the columns each component may
carry, and the allowed values of every controlled vocabulary. The
validator
([`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md))
enforces exactly these tables, so other packages can use them to build
compatible objects.

## Usage

``` r
cs_vocabulary(what = c("columns", "vocabularies", "checks"))
```

## Arguments

- what:

  Which table to return: `"columns"`, `"vocabularies"` or `"checks"`.

## Value

For `what = "columns"`, a data frame with one row per specified column
and the character columns `component` (`"cells"`, `"dictionary"`,
`"images"`, `"channels"`, `"adjacency"`), `column`, `type` (R storage
type), `requirement` (`"MUST"`, `"SHOULD"`, `"MAY"`) and `description`.
For `what = "vocabularies"`, a data frame with the character columns
`vocabulary`, `value` and `description`. For `what = "checks"`, the
validation catalogue used by
[`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md):
character columns `check`, `level` (`"structure"` or `"semantic"`) and
`description`.

## See also

[`vignette("specification", package = "cellspecR")`](https://cttir.github.io/cellspecR/articles/specification.md)

Other specification:
[`cs_spec_version()`](https://cttir.github.io/cellspecR/reference/cs_spec_version.md)

## Examples

``` r
cols <- cs_vocabulary("columns")
cols[cols$component == "cells", c("column", "type", "requirement")]
#>                        column      type requirement
#> 1                     cell_id character        MUST
#> 2                    image_id character        MUST
#> 3                   sample_id character        MUST
#> 4                           x    double        MUST
#> 5                           y    double        MUST
#> 6                        area    double      SHOULD
#> 7                        x_px    double         MAY
#> 8                        y_px    double         MAY
#> 9                 object_type character         MAY
#> 10                     parent character         MAY
#> 11             classification character         MAY
#> 12                    tile_id character         MAY
#> 13            region__<layer> character         MAY
#> 14 boundary_distance__<layer>    double         MAY

voc <- cs_vocabulary("vocabularies")
voc$value[voc$vocabulary == "compartment"]
#> [1] "cell"      "nucleus"   "cytoplasm" "membrane" 

head(cs_vocabulary("checks"))
#>                    check     level
#> 1           object_class structure
#> 2      object_components structure
#> 3           spec_version structure
#> 4 cells_required_columns structure
#> 5     cells_column_types structure
#> 6   cells_reserved_names structure
#>                                                          description
#> 1                          The object is a list of class `cellspec`.
#> 2            All components exist and have the right container type.
#> 3 `spec_version` is a version string with a supported major version.
#> 4             `cells` has every MUST column and no duplicated names.
#> 5              Specified `cells` columns have their specified types.
#> 6                   No `cs__` columns; region layer names are valid.
```
