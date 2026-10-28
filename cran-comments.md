## Test environments

* Local: Ubuntu 26.04 LTS, R 4.6.1
* GitHub Actions: Ubuntu (R devel, release and oldrel-1), macOS (R release)
  and Windows (R release)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* "Version contains large components (1.0.0.9000)": this is the development
  version number; it will be bumped to a release version before submission.

## Notes

The Bioconductor packages in Suggests (anndataR, S4Vectors,
SingleCellExperiment, SpatialExperiment, SummarizedExperiment) and the other
suggested packages are used conditionally. The package also passes
`R CMD check --as-cran` with `_R_CHECK_DEPENDS_ONLY_=true`.

Examples and tests use only small synthetic data, write only to temporary
files and do not access the network.
