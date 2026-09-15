# cellspecR performance measurements

Generated with `CELLSPECR_BENCH_CELLS=500` (1000 cells; 17 markers) on Linux 7.0.0-29-generic.

Results are one-iteration smoke measurements; rerun on a CI runner
before release to record the second hardware profile.

## canonical_write_read

# A tibble: 1 × 13
  expression      min median `itr/sec` mem_alloc `gc/sec` n_itr  n_gc total_time
  <bch:expr>    <bch> <bch:>     <dbl> <bch:byt>    <dbl> <int> <dbl>   <bch:tm>
1 { cs_write(x… 188ms  188ms      5.31    11.3MB     15.9     1     3      188ms
# ℹ 4 more variables: result <list>, memory <list>, time <list>, gc <list>

## semantic_validation

# A tibble: 1 × 13
  expression      min median `itr/sec` mem_alloc `gc/sec` n_itr  n_gc total_time
  <bch:expr>    <bch> <bch:>     <dbl> <bch:byt>    <dbl> <int> <dbl>   <bch:tm>
1 "cs_validate… 119ms  119ms      8.38    6.12MB     25.1     1     3      119ms
# ℹ 4 more variables: result <list>, memory <list>, time <list>, gc <list>

## signal_matrix

# A tibble: 1 × 13
  expression      min median `itr/sec` mem_alloc `gc/sec` n_itr  n_gc total_time
  <bch:expr>   <bch:> <bch:>     <dbl> <bch:byt>    <dbl> <int> <dbl>   <bch:tm>
1 cs_signal_m… 29.4ms 29.4ms      34.0    1.76MB        0     1     0     29.4ms
# ℹ 4 more variables: result <list>, memory <list>, time <list>, gc <list>

## tiled_read

# A tibble: 1 × 13
  expression      min median `itr/sec` mem_alloc `gc/sec` n_itr  n_gc total_time
  <bch:expr>    <bch> <bch:>     <dbl> <bch:byt>    <dbl> <int> <dbl>   <bch:tm>
1 "cs_read(til… 313ms  313ms      3.19    10.3MB     22.3     1     7      313ms
# ℹ 4 more variables: result <list>, memory <list>, time <list>, gc <list>

## spatial_experiment

# A tibble: 1 × 13
  expression      min median `itr/sec` mem_alloc `gc/sec` n_itr  n_gc total_time
  <bch:expr>    <bch> <bch:>     <dbl> <bch:byt>    <dbl> <int> <dbl>   <bch:tm>
1 cs_as_spe(x,… 147ms  147ms      6.79    7.12MB     6.79     1     1      147ms
# ℹ 4 more variables: result <list>, memory <list>, time <list>, gc <list>
