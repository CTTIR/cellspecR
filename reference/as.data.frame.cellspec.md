# Convert a cellspec object to a data frame

**\[experimental\]**

Combines the `cells` columns with selected measurement columns into one
wide data frame, for example to hand a table to modelling code.
Measurement columns are named by their feature identifiers.

## Usage

``` r
# S3 method for class 'cellspec'
as.data.frame(x, row.names = NULL, optional = FALSE, ..., features = NULL)

# S3 method for class 'cellspec'
as_tibble(x, ..., features = NULL)
```

## Arguments

- x:

  A `cellspec` object.

- row.names, optional:

  Ignored; present for compatibility with the generic.

- ...:

  Unused.

- features:

  Character vector of feature identifiers to include (default: all
  features).

## Value

A `data.frame` with one row per cell: the `cells` columns followed by
one double column per selected feature. `as_tibble()` returns the same
content as a tibble (requires the tibble package).

## See also

Other methods:
[`[.cellspec()`](https://cttir.github.io/cellspecR/reference/sub-.cellspec.md),
[`cellspec-methods`](https://cttir.github.io/cellspecR/reference/cellspec-methods.md),
[`plot.cellspec()`](https://cttir.github.io/cellspecR/reference/plot.cellspec.md)

## Examples

``` r
x <- cs_example()
df <- as.data.frame(x, features = cs_features(x, statistic = "mean"))
head(df)
#>   cell_id image_id sample_id        x         y    area     x_px     y_px
#> 1       1     img1        s1 355.8867 441.65396 36.5329 711.7733 883.3079
#> 2       2     img1        s1 331.0488 479.92247 54.2466 662.0976 959.8449
#> 3       3     img1        s1 113.7938 270.56093 78.4704 227.5877 541.1219
#> 4       4     img1        s1 108.9166 120.10323 52.8604 217.8332 240.2065
#> 5       5     img1        s1 399.6320 455.57838 67.7371 799.2640 911.1568
#> 6       6     img1        s1 235.4871  88.79277 61.8434 470.9741 177.5855
#>   cell:DAPI:mean cell:CD3e:mean cell:Pan-Cytokeratin:mean cell:FOXP3:mean
#> 1        31.7296        16.6653                   11.6708         17.8206
#> 2         5.5744       164.4467                    5.7050         40.6432
#> 3        18.3195        33.5342                    9.3728          2.9338
#> 4        19.2818       190.3371                   24.1383         13.6242
#> 5        29.6346         6.4369                  134.8476         90.9520
#> 6        24.0813        26.5155                    4.5571          9.0004
#>   nucleus:DAPI:mean nucleus:CD3e:mean nucleus:Pan-Cytokeratin:mean
#> 1           32.5585           17.4159                      13.0078
#> 2            6.4551          167.4534                       5.6793
#> 3           17.6285           39.1170                       9.7823
#> 4           20.2758          188.8126                      25.0871
#> 5           33.8960            7.4920                     138.3824
#> 6           26.4404           30.8429                       5.1774
#>   nucleus:FOXP3:mean
#> 1            18.7645
#> 2            42.4143
#> 3             3.2185
#> 4            15.1382
#> 5           101.5028
#> 6            10.2301
```
