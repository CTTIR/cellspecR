# Reader cross-check record

The bundled exports are synthetic and contain no patient data. The following
record maps the reader cross-checks in `instructions/05_TESTING.md` to the
evidence currently available in this development build.

| ID | Source and comparison | Evidence | Status |
|---|---|---|---|
| CS-B01 | QuPath 0.7.0 channel-first export | `inst/extdata/qupath-0.7.0-instanseg.tsv`, SHA-256 `eeae5412f14c506ab1c19f6486657cf9309508f6695e3ca23fe5bfe03de3891d`; exact header and row tests in `test-adapter-qupath.R` | recorded |
| CS-B02 | QuPath compartment-first contract | Synthetic `Nucleus: CD3e: Mean` and `Cell: CD3e: Mean` headers in adapter tests | recorded |
| CS-B03 | segmantR centroid and feature conventions | Synthetic pixel-centroid and channel-statistic tables in `test-adapter-other.R` | recorded |
| CS-B04 | MCQuant export conventions | Synthetic MCQuant table with pixel centroids, calibration and morphology in `test-adapter-other.R` | recorded |
| CS-B05 | inForm position and signal columns | Synthetic `Cell X Position`, `Cell Y Position` and `DAPI Mean` table in `test-adapter-other.R` | recorded |

QuPath 0.6.0, MCQuant and inForm binary exports are not installed on this
machine. Their external fixture comparisons remain a maintainer or CI task;
the adapter tests preserve the documented column grammars and fail clearly
when calibration or required identifiers are absent.
