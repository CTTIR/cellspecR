## Test environments

* Local: Ubuntu Linux, R 4.6.1
* GitHub Actions: Ubuntu, macOS and Windows (release; devel where available)

## R CMD check results

The development build has completed its reader and user-interface work. Local
validation of the built source tarball completed with 0 errors and 0 warnings;
the development version reports the expected incoming feasibility notes. Test
coverage is 95.45% overall. External QuPath/MCQuant/inForm fixture comparisons
and maintainer submission checks remain release-owner tasks.

## Notes

The package contains only synthetic, non patient data. Optional integrations
are guarded with `requireNamespace()` and examples do not access the network.
