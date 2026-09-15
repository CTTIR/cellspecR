# Select one signal per cell and marker

**\[experimental\]**

Applies a `cs_signal_policy` to the intensity measurements in a
`cellspec` object. A preferred value is used when it is non-missing and
at least the row's `min_value`; otherwise the configured fallback is
tested.

## Usage

``` r
cs_signal_matrix(x, policy, image_id = NULL)
```

## Arguments

- x:

  A `cellspec` object.

- policy:

  A `cs_signal_policy` created by
  [`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md).

- image_id:

  Optional image identifier. When supplied, only cells from that image
  are returned.

## Value

A list with `signal`, a cells by markers numeric matrix, `source`, a
character matrix describing the selected source, and `policy`, the
validated policy. Source values are `"<compartment>:<statistic>"`,
`"fallback:<compartment>:<statistic>"` or `"unavailable"`.

## See also

[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md)

Other signals:
[`cs_marker_map()`](https://cttir.github.io/cellspecR/reference/cs_marker_map.md),
[`cs_read_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_read_signal_policy.md),
[`cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.md),
[`cs_write_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_write_signal_policy.md)

## Examples

``` r
x <- cs_example()
policy <- cs_signal_policy(cs_markers(x))
selected <- cs_signal_matrix(x, policy)
selected$signal[, 1:2]
#>        DAPI     CD3e
#> 1   31.7296  16.6653
#> 2    5.5744 164.4467
#> 3   18.3195  33.5342
#> 4   19.2818 190.3371
#> 5   29.6346   6.4369
#> 6   24.0813  26.5155
#> 7  133.7387  48.3400
#> 8  108.9936 205.9034
#> 9   41.1782  29.0966
#> 10  13.9255  22.0039
#> 11   5.2126  76.4789
#> 12  31.0010  20.5449
#> 13 171.0040 159.6717
#> 14 107.9310  85.1976
#> 15  21.0609  48.9259
#> 16 101.9609  61.6761
#> 17  13.1304  39.8273
#> 18 114.0909  15.1845
#> 19  95.1428  18.5123
#> 20  41.6574 113.3236
#> 21 166.2902  27.1171
#> 22   5.5461  29.0827
#> 23 212.9764 136.4018
#> 24   6.2627  19.3159
#> 25  41.3807  39.1086
#> 26  55.8962   1.3282
#> 27   7.9960  12.4137
#> 28  17.9735  67.3726
#> 29  15.4342   6.7498
#> 30  14.3834  11.9688
#> 31  11.5762  38.0856
#> 32 120.4570  14.4792
#> 33  21.5935  11.4580
#> 34 147.1378  14.7547
#> 35  10.1984  23.4833
#> 36   8.6335  29.6572
#> 37  13.1495   5.8615
#> 38  11.8506   8.1795
#> 39  15.5081  11.5671
#> 40  47.0861  44.2072
#> 1   75.9318 136.2283
#> 2  119.9755 130.8204
#> 3    5.0617   8.5446
#> 4    1.8171  41.4087
#> 5   77.7874 217.8956
#> 6   26.8731   5.8744
#> 7   21.4012 142.1992
#> 8   27.7239  14.3220
#> 9    4.8217  28.4807
#> 10 116.8894  17.2876
#> 11  24.3082  23.9871
#> 12  11.1367  23.6451
#> 13   7.5043   4.3126
#> 14   9.0503  29.2059
#> 15  11.8600  68.7578
#> 16  29.0260  11.1006
#> 17  12.5941  22.0476
#> 18 146.1850 178.8168
#> 19  12.4994  16.5780
#> 20   6.6639  73.5430
#> 21  49.6253   6.9933
#> 22  77.0584  10.3396
#> 23   8.5926  13.6475
#> 24   5.2848 141.8186
#> 25  22.6272  17.0960
#> 26  96.3507  29.3634
#> 27  16.4542  21.4546
#> 28 124.4366  10.0016
#> 29  18.8177 113.8623
#> 30  20.2170   9.8800
#> 31  85.1764 225.9706
#> 32  12.2432 208.1091
#> 33  35.6233  73.9157
#> 34  98.1132  81.6005
#> 35  13.6345  27.1717
#> 36   9.1107 110.1646
#> 37  16.6287  28.4719
#> 38  91.2071  13.3398
#> 39  29.7930 161.9798
#> 40 307.1858  85.0682
```
