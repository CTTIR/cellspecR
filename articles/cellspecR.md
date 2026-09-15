# Getting started with cellspecR

`cellspecR` puts an explicit contract between segmentation and
downstream analysis. The first object to inspect is the deterministic
bundled example.

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
summary(x)
#> <cellspec summary> 2 images, 80 cells
#>  image_id sample_id n_cells n_markers n_features pixel_size  x_min  x_max
#>      img1        s1      40         4         19        0.5 22.498 504.86
#>      img2        s2      40         4         19        0.5 17.146 494.75
#>   y_min  y_max na_fraction
#>  20.589 508.74           0
#>   1.152 500.00           0
cs_validate(x)
#> <cellspec validation> 45 checks: 0 fail, 0 warn, 0 skip, 45 pass
#> pass 45 other checks
```

The dictionary describes every measurement, including its compartment
and statistic. Select features through dictionary fields rather than
parsing a feature name.

``` r

cs_features(x, kind = "intensity", marker = "CD3e", statistic = "mean")
#> [1] "cell:CD3e:mean"    "nucleus:CD3e:mean"
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
```

Signal selection is explicit and recorded as a policy.

``` r

policy <- cs_signal_policy(
  marker = c("CD3e", "FOXP3"),
  compartment = c("cell", "nucleus"),
  statistic = "mean"
)
selected <- cs_signal_matrix(x, policy)
head(selected$signal)
#>       CD3e    FOXP3
#> 1  16.6653  18.7645
#> 2 164.4467  42.4143
#> 3  33.5342   3.2185
#> 4 190.3371  15.1382
#> 5   6.4369 101.5028
#> 6  26.5155  10.2301
```

Finally, write an integrity checked directory and verify it before
handing the object to another analysis package.

``` r

destination <- file.path(tempdir(), "cellspec-getting-started")
cs_write(x, destination, overwrite = TRUE)
cs_verify(destination)
#>                        file
#> cells.parquet cells.parquet
#> cellspec.json cellspec.json
#> 1                      DONE
#>                                                                       expected
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json e23259ccf6c744a826d59f00258bffdee0e98903ef9308b4abfc2d9dc996a6f4
#> 1             489212cfabd36e232f1afd801d229a0a7557d54aa09083fbcec08611ff246cbc
#>                                                                       observed
#> cells.parquet 67ca57b984c08b81087d62183e3602dac68637447b40f3a7bf0697bc98557994
#> cellspec.json e23259ccf6c744a826d59f00258bffdee0e98903ef9308b4abfc2d9dc996a6f4
#> 1             489212cfabd36e232f1afd801d229a0a7557d54aa09083fbcec08611ff246cbc
#>                 ok
#> cells.parquet TRUE
#> cellspec.json TRUE
#> 1             TRUE
y <- cs_read_cellspec(destination)
identical(cs_cells(x), cs_cells(y))
#> [1] TRUE
```
