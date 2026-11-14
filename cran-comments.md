## Submission

This is a new submission (cellspecR 1.2.0).

## Test environments

- Local: macOS (aarch64-apple-darwin), R 4.6.1, 14 November 2026:
  full `R CMD check --as-cran` on the built source tarball, including
  PDF manual compilation with TinyTeX (TeX Live 2026) and HTML manual
  validation. This supersedes the earlier local check environment.
- GitHub Actions (r-lib/actions v2, `--as-cran`):
  - macos-latest (R release)
  - windows-latest (R release)
  - ubuntu-latest (R devel, release, oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'R. Heller <raban.heller@uni-ulm.de>'
  New submission

  This is the first submission of this package.

## Additional notes

* The Bioconductor packages in Suggests ('anndataR', 'S4Vectors',
  'SingleCellExperiment', 'SpatialExperiment', 'SummarizedExperiment') and
  the other suggested packages are used conditionally via
  `requireNamespace()`; tests skip when they are not installed.
* Examples, tests and vignettes use only small synthetic data, write only to
  `tempdir()` and do not access the network.
* The 'shiny' review application is only started on request and is not
  launched in examples, tests or vignettes.

## Downstream dependencies

There are currently no downstream dependencies on CRAN. The suite packages
'phenoscapR' and 'gatekeepR' (not on CRAN) suggest cellspecR.
