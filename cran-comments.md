## Test environments

* Local: Ubuntu Linux, R 4.6.1
* GitHub Actions: Ubuntu, macOS and Windows (release; devel where available)

## R CMD check results

This is the first submission of cellspecR 1.0.0. The package provides the
versioned cellspec contract, canonical storage, tool readers, validation,
interoperability helpers, quality-control plots and a local Shiny review app.
Local validation of the built source tarball completed with 0 errors and 0
warnings. Test coverage is 95.46% overall. External QuPath/MCQuant/inForm
fixture comparisons and maintainer builder/submission checks remain
release-owner tasks.

## Notes

The package contains only synthetic, non patient data. Optional integrations
are guarded with `requireNamespace()` and examples do not access the network.
