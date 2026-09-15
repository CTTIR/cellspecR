# Summarise the signal support of features per image

**\[experimental\]**

Describes, for every image and feature, how much usable variation a
feature carries. A marker whose channel was blank, saturated or not
acquired shows up as `"constant"` or `"near_constant"` here before any
normalisation or gating hides the problem. Other packages (for example a
gating package) use the `support` column to declare markers
non-callable.

The `support` classes are assigned in this order:

1.  `"mostly_na"`: more than half of the values are missing.

2.  `"constant"`: all non-missing values are identical (for example an
    all-zero channel).

3.  `"near_constant"`: the 1st and 99th percentiles are identical, so at
    most about 1% of cells differ from the rest.

4.  `"ok"`: otherwise.

## Usage

``` r
cs_feature_support(
  x,
  features = cs_features(x, kind = "intensity", statistic = "mean"),
  zero_tol = 0
)
```

## Arguments

- x:

  A `cellspec` object.

- features:

  Character vector of feature identifiers. Defaults to all mean
  intensity features.

- zero_tol:

  Values with absolute value at most `zero_tol` count as zero for
  `fraction_zero`.

## Value

A data frame with one row per image and feature and the columns
`image_id`, `feature_id`, `marker`, `compartment`, `statistic`
(character), `n`, `n_na` (integer), `fraction_zero`, `sd`, `mad`, `q01`,
`q50`, `q99` (double, computed on non-missing values; `NA` when none)
and `support` (character, see Details).

## See also

Other validation:
[`cs_validate()`](https://cttir.github.io/cellspecR/reference/cs_validate.md)

## Examples

``` r
x <- cs_example()
cs_feature_support(x)
#>    image_id                   feature_id          marker compartment statistic
#> 1      img1               cell:DAPI:mean            DAPI        cell      mean
#> 2      img1               cell:CD3e:mean            CD3e        cell      mean
#> 3      img1    cell:Pan-Cytokeratin:mean Pan-Cytokeratin        cell      mean
#> 4      img1              cell:FOXP3:mean           FOXP3        cell      mean
#> 5      img1            nucleus:DAPI:mean            DAPI     nucleus      mean
#> 6      img1            nucleus:CD3e:mean            CD3e     nucleus      mean
#> 7      img1 nucleus:Pan-Cytokeratin:mean Pan-Cytokeratin     nucleus      mean
#> 8      img1           nucleus:FOXP3:mean           FOXP3     nucleus      mean
#> 9      img2               cell:DAPI:mean            DAPI        cell      mean
#> 10     img2               cell:CD3e:mean            CD3e        cell      mean
#> 11     img2    cell:Pan-Cytokeratin:mean Pan-Cytokeratin        cell      mean
#> 12     img2              cell:FOXP3:mean           FOXP3        cell      mean
#> 13     img2            nucleus:DAPI:mean            DAPI     nucleus      mean
#> 14     img2            nucleus:CD3e:mean            CD3e     nucleus      mean
#> 15     img2 nucleus:Pan-Cytokeratin:mean Pan-Cytokeratin     nucleus      mean
#> 16     img2           nucleus:FOXP3:mean           FOXP3     nucleus      mean
#>     n n_na fraction_zero       sd      mad      q01      q50      q99 support
#> 1  40    0             0 55.89735 23.28875 5.342665 22.83740 196.6072      ok
#> 2  40    0             0 53.27280 23.89833 3.096187 28.09990 199.8325      ok
#> 3  40    0             0 57.34683 62.94126 5.004781 56.53290 190.1744      ok
#> 4  40    0             0 52.50384 18.20989 2.112740 21.28175 180.7926      ok
#> 5  40    0             0 61.40774 23.19239 5.912202 25.49775 219.1563      ok
#> 6  40    0             0 55.63276 25.26395 3.401834 30.38670 206.2651      ok
#> 7  40    0             0 63.42668 73.04674 5.373141 59.67735 215.8480      ok
#> 8  40    0             0 57.69244 18.90048 2.283919 22.28605 199.0342      ok
#> 9  40    0             0 58.53436 20.03786 2.988894 22.01420 244.3955      ok
#> 10 40    0             0 66.69458 28.56081 4.921702 28.47630 222.8213      ok
#> 11 40    0             0 32.93950 15.91934 2.175821 21.38855 153.7864      ok
#> 12 40    0             0 46.85746 20.17315 2.366694 20.80870 153.1182      ok
#> 13 40    0             0 62.01664 22.65539 3.287665 24.58900 248.8221      ok
#> 14 40    0             0 73.14599 31.71444 5.544898 30.81445 245.5503      ok
#> 15 40    0             0 37.47605 19.42762 2.523328 22.80490 173.7608      ok
#> 16 40    0             0 52.05211 24.17572 2.829118 23.74025 171.9527      ok

# A blank channel is reported as constant
x$measurements[, "cell:FOXP3:mean"] <- 0
s <- cs_feature_support(x)
s[s$marker == "FOXP3", c("image_id", "feature_id", "support")]
#>    image_id         feature_id  support
#> 4      img1    cell:FOXP3:mean constant
#> 8      img1 nucleus:FOXP3:mean       ok
#> 12     img2    cell:FOXP3:mean constant
#> 16     img2 nucleus:FOXP3:mean       ok
```
