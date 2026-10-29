# Write a cellspec directory

**\[experimental\]**

Writes a canonical cellspec directory in a neighbouring staging
directory, then renames it into place after the data, sidecar, manifest
and DONE marker are complete. Parquet is the default because it
preserves doubles exactly; the tsv.gz option is available for
interoperable text output.

## Usage

``` r
cs_write(x, dir, format = c("parquet", "tsv.gz"), overwrite = FALSE)
```

## Arguments

- x:

  A valid cellspec object.

- dir:

  Destination directory. Its parent is created when needed.

- format:

  Storage format: parquet or tsv.gz.

- overwrite:

  Whether an existing destination may be replaced. Only an empty
  directory or earlier `cs_write()` output is replaced: a directory
  whose `cellspec.json` carries the cellspec format marker and which
  holds nothing but the files `cs_write()` creates. Any other directory,
  for example one with an added file, is left untouched and an error
  naming the unexpected entries is raised.

## Value

x, invisibly.

## See also

cs_read_cellspec(), cs_verify()

Other canonical-format:
[`cs_read_cellspec()`](https://cttir.github.io/cellspecR/dev/reference/cs_read_cellspec.md),
[`cs_verify()`](https://cttir.github.io/cellspecR/dev/reference/cs_verify.md)

## Examples

``` r
path <- tempfile("cellspec-")
cs_write(cs_example(), path)
```
