# Printing the bslib app page compiles Sass. Keep the compiled CSS out of the
# user cache directory so that the tests write only to temporary files.
withr::local_options(sass.cache = FALSE, .local_envir = testthat::teardown_env())
