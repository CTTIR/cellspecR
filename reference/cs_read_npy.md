# Read and write NumPy array files

**\[experimental\]**

`cs_read_npy()` reads one `.npy` file and `cs_read_npz()` reads the
arrays of an `.npz` archive, both without Python. Cell tables exported
from Python pipelines (centroids, labels, per-cell flags) can so be
brought into
[`cs_new()`](https://cttir.github.io/cellspecR/reference/cs_new.md)
directly. `cs_write_npy()` and `cs_write_npz()` write the same formats,
for example to hand results back or to build test fixtures.

Supported data types are booleans, signed and unsigned integers, 32- and
64-bit floats, 128-bit complex numbers, fixed-width Unicode (`U`) and
byte (`S`) strings, in either byte order and in C or Fortran order.
Object arrays (`O`, stored with Python's pickle) and structured data
types are refused. 64-bit and unsigned 32-bit integers are returned as
doubles; a value that a double cannot hold exactly is an error.

## Usage

``` r
cs_read_npy(path)

cs_read_npz(path, arrays = NULL)

cs_write_npy(x, path)

cs_write_npz(x, path)
```

## Arguments

- path:

  Path to a `.npy` file (`cs_read_npy()`, `cs_write_npy()`) or a `.npz`
  archive (`cs_read_npz()`, `cs_write_npz()`).

- arrays:

  Names of the arrays to read from the archive, without the `.npy`
  suffix. `NULL` reads all arrays.

- x:

  For `cs_write_npy()`: a logical, integer, double or character vector,
  matrix or array. For `cs_write_npz()`: a named list of such objects.

## Value

`cs_read_npy()` returns a vector for one-dimensional arrays, a matrix or
array with the same shape otherwise, and a length-one vector for
zero-dimensional arrays. `cs_read_npz()` returns a named list of these,
in archive order. The writers return `path` invisibly.

## Details

Arrays keep their logical shape: element `[i, j]` in R is element
`[i - 1, j - 1]` in NumPy, whatever the storage order. Trailing NUL
characters of fixed-width strings are dropped, as NumPy does.

`cs_write_npz()` stores the members uncompressed (as `numpy.savez()`
does) and needs no external `zip` program. Character data are written as
little-endian `U` strings, doubles as `<f8`, integers as `<i4` and
logical values as `|b1`; missing values are not allowed.

## Examples

``` r
path <- tempfile(fileext = ".npz")
cs_write_npz(list(x_um = c(1.5, 2.5), label = c("Tumour", "Treg")), path)
cs_read_npz(path)
#> $x_um
#> [1] 1.5 2.5
#> 
#> $label
#> [1] "Tumour" "Treg"  
#> 
cs_read_npz(path, arrays = "label")$label
#> [1] "Tumour" "Treg"  
```
