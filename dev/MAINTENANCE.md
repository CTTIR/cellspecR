# Hosted portability follow-up — 3 November 2026

Published baseline: `0046842`. The earlier audit below is historical;
its publication-status statements predate that main commit.

The Windows job reported four integrity failures because base R’s
[`Sys.readlink()`](https://rdrr.io/r/base/Sys.readlink.html) returns
empty strings on Windows. Link detection now uses the explicit `fs`
dependency, so native file/directory links, dangling links and junctions
cannot be accepted as canonical members or overwrite destinations.
Overwrite preflight also refuses a linked `cellspec.json` before parsing
it.

The new synthetic regressions fail seven assertions against the frozen
baseline. The complete local suite passed 1,223 assertions with no
failures or warnings; the native Windows junction case is intentionally
reserved for Windows. Local coverage is 95.92644%, above the configured
90% floor. Shared house lint and workflow validation pass. Full
source-package check passed with zero errors, zero warnings and one
incoming-submission/development-version NOTE. Independent source review
checked the fs/libuv Windows link classification and the no-read sidecar
guard. Package-check results and exact-head hosted outcomes are retained
with the follow-up evidence.

The oldrel-3 row’s unavailable optional `anndataR` dependency is a
separate informational compatibility observation. No R minimum,
dependency requirement, test, or hosted gate was weakened. Checksums
still detect consistency rather than producer identity; filesystem races
are not an OS sandbox or lock.

Contracts: [R readlink
behavior](https://stat.ethz.ch/R-manual/R-devel/library/base/html/Sys.readlink.html)
and [fs file-type queries](https://fs.r-lib.org/reference/is_file.html).

------------------------------------------------------------------------

# Maintenance audit — 30 October 2026

Public baseline: `bd940f1baf937cd6a78f8741193ac419d34c712b` (1.1.0). The
local main checkout is 49 commits behind and remains untouched. This
isolated branch starts from current public main. No patient data,
fixtures or existing source exports are changed. GitHub has no open
issues; baseline hosted checks pass, but do not establish the
candidate’s readiness.

## Purpose and acceptance criteria

cellspecR carries segmented microscopy measurements between tools with
explicit units, identifiers, signal policies and provenance. A
dependable release must preserve identifiers and representable values,
reject partial or ambiguous imports, protect existing destinations on
failure, and distinguish verified self-contained storage from data that
depend on external paths. The local app must review the selected source
and expose only results of a successful read. Public function signatures
and the cellspec 1.0 contract remain stable.

## Findings and roadmap

| Priority | Confirmed evidence and impact | Changes and validation |
|----|----|----|
| Essential | `cs_write_npy(list(1), existing)` truncates an existing file to zero bytes before rejecting the input. | Encode before opening the destination. Preserve previous bytes on invalid input; test successful NumPy interchange. |
| Essential | A destination created during [`cs_write()`](https://cttir.github.io/cellspecR/dev/reference/cs_write.md) is replaced even with `overwrite=FALSE`; a file added during overwrite can also be deleted. `.cs_commit_stage()` never reads its overwrite argument or repeats the replaceability check. | Recheck the destination at commit time and retain staging cleanup/rollback. Exercise a concurrent appearance and late unrelated file. This does not provide cross-process locking. |
| Essential | [`cs_verify()`](https://cttir.github.io/cellspecR/dev/reference/cs_verify.md) ignores `.extra` and accepts a data symlink pointing outside the directory. | Include hidden entries and refuse symlink members without following directory links; reject unsafe portable paths, and verify control files too. Test relocation, modification, missing files and external links. |
| Essential | Actual NumPy 2.0.2 fixtures: int32 minimum becomes NA; uint32 at 2^31 and signed int64 values error on R’s reserved integer NA bit pattern. Exact 2^53 is rejected. Duplicate archive names silently resolve twice to the first member. | Decode unsigned halves without R’s signed-integer sentinel; preserve supported exact range through +/-2^53; reject ambiguous archives. Compare both byte orders with independently generated NumPy fixtures and NumPy reads of R output. |
| Essential | A QuPath table with two valid rows and a broken footer imports silently as two cells. IDs `001`/`002` become `1`/`2`. | Treat parser warnings as format errors and preserve zero-prefixed/large integer identifiers. Exercise valid and truncated exports and provenance counts. |
| Everyday use | The app reads the upload temporary path rather than the supplied filename; RDS/gzip dispatch and derived image identity depend on suffix/basename. Failed reads retain previous data and downloads. | Stage uploads under a safe original basename in session-local storage; clear results when input changes and before read. Test RDS/gzip names, failure and real browser downloads. |
| Documentation | AnnData documentation claims a Python runtime is mandatory although anndataR supports native in-memory objects. | Exercise the declared optional integrations and align their prerequisites with observed behavior. |

Milestone 1 repairs storage and numeric fidelity; milestone 2 qualifies
imports and the application; milestone 3 runs clean installation,
package checks, blocking lint, coverage, docs, interoperability and
direct first use. A repair is complete only after its failure path and
successful workflow both pass. External tool-produced microscopy
fixtures, hosted OS/R candidate CI and CRAN submission remain release
gates. New adapters, new scientific models, broad rewrites and
large-array streaming are deferred.

Authoritative references: [NumPy
format](https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html),
[AnnData
implementations](https://anndatar.scverse.org/reference/AnnData-usage.html).

Further confirmed integrity findings were repaired during review:
sidecar `channel_index=1.5` silently became `1`, and distinct cell/image
tuples containing carriage returns collided. Strict scalar/type checks
now reject lossy metadata, and internal length-prefixed keys keep valid
identifiers distinct. An adversarial malformed footer containing braces
also made cli evaluate the external diagnostic as an expression. All
external error-message forwarding in read/write/interop paths now
inserts literal text, with a regression that must retain both the
structured error class and the unevaluated expression. The original
write probe used a removed test hook and did not create its intended
race; `commit-stage-baseline.log` reproduces the actual defect directly
against the baseline function. Regression tests inject the late write
through the current completion function and check preserved source
bytes.

## Verification

Detailed baseline/probe and qualification logs are retained outside the
package in `../../evidence/cellspecR/`.

- Baseline: 187 tests, 1,141 passing assertions, no
  failures/errors/warnings and five optional-integration skips. The
  first test command could not start because devtools is absent;
  testthat ran the baseline successfully.
- Installed Bioconductor integrations now run: SpatialExperiment
  reproduces the original cells and measurements, and AnnData constructs
  an 80 by 4 native R `InMemoryAnnData`. Its test no longer treats any
  conversion error as success.
- Independent NumPy 2.0.2 fixtures cover eight signed/unsigned,
  little/big-endian boundary arrays. NumPy also reads all four R-written
  array types with exact values, dimensions, Unicode strings and
  booleans. No Python dependency was added to the package.
- A 100,000-cell, nine-feature synthetic round trip preserves exact
  cells and measurements in both formats. Observed write/read elapsed
  times are 0.591/0.404 seconds for Parquet and 2.389/3.572 seconds for
  compressed TSV on this machine; these are single-run measurements, not
  a platform-wide performance claim.
- Both canonical formats round-trip cells and measurements exactly from
  a fresh installed package. Output protection, hidden files, symbolic
  links, malformed tables, preserved IDs and metadata types have direct
  regression tests.
- The first complete source-package `--as-cran` check passes with zero
  errors, zero warnings and one NOTE (new submission/development
  version). The final frozen archive also passes with zero
  errors/warnings and the same single NOTE. All 1,210 installed test
  assertions pass, with zero failures, warnings or skips; examples,
  vignette rebuilds and both manuals pass. Two print snapshots were
  reviewed: their only differences are the intentional package version
  change; public API signature fixtures remain unchanged.
- Measured test coverage is 95.91%, above the required 90% floor. Final
  frozen-source coverage confirms that result. Blocking CTTIR house lint
  has zero findings. Actionlint and `git diff --check` pass;
  shellcheck/pyflakes are unavailable for actionlint.
- Installed Chromium journey reads an RDS upload through its original
  filename, preserves IDs 001/002 and sample-A, observes the correct
  coordinate conversion (rounded to two decimals in the table), and
  downloads validation/dictionary CSVs. A malformed next upload clears
  the previous review and exports `not_run`. No JavaScript errors. Both
  owned application servers were stopped. Desktop and 390 px screenshots
  were inspected; wide mobile tables now scroll horizontally by keyboard
  inside a focusable labelled region, without overflowing the page.
- Documentation builds 66 HTML pages with 1,889 local references and no
  missing files. Pandoc emits deprecated math-option diagnostics; the
  build succeeds. README preview badge fetching is unavailable in this
  Pandoc build; the generated Markdown retains its existing remote badge
  links.
- No high-confidence private-key/access-token patterns were found in the
  tracked text scan. This is a pattern scan, not a full-history security
  audit.

### First use

Prerequisites: R \>= 4.1 and the DESCRIPTION imports (including
data.table \>= 1.17.0). Shiny and optionally bslib/ggplot2 enable the
local review application. SpatialExperiment, SingleCellExperiment,
S4Vectors and anndataR are optional Bioconductor integrations. No Python
is required for canonical or NumPy I/O.

The isolated installed candidate on this machine can be used with:

``` sh
AUDIT_ROOT=/Users/rh/Documents/GitHub/.repository-audits/cttir-public-20261030
export R_LIBS_USER="$AUDIT_ROOT/evidence/cellspecR/archive-library:$AUDIT_ROOT/tools/R-library"
Rscript --vanilla -e 'library(cellspecR); x <- cs_example(); p <- tempfile(); cs_write(x,p); stopifnot(all(cs_verify(p)$ok),identical(cs_cells(x),cs_cells(cs_read_cellspec(p)))); print(x)'
Rscript --vanilla -e 'shiny::runApp(cellspecR::cs_app(),host="127.0.0.1",port=18745)'
```

For another machine, install the declared dependencies and run
`R CMD INSTALL` on the prepared source archive. GitHub main does not yet
contain these changes. The README provides the upload workflow and
signal-policy example.

### Release gates and deferred work

Local tests use synthetic fixtures. Comparative exports from actual
supported QuPath/MCQuant/inForm versions remain a release-owner
qualification task; no patient data were accessed. Run the hosted OS/R
matrix on the accepted commit, select a final non-development version,
refresh citation/deposit metadata and CRAN comments, rebuild/check the
submission package, then obtain any necessary publication approval. No
push, hosted candidate CI, CRAN submission or deposit has occurred.

Readers hold NumPy arrays in memory and reject unsupported
dimensions/integers; this is not a streaming solution for arbitrary-size
archives. Canonical checksums establish consistency, not producer
authentication, and canonical destination checks do not implement a
concurrent-writer lock. Deployment beyond the default local Shiny
session requires its own access-control and resource decisions.
