# About panel for the cellspec review app.

.cs_app_about <- function() {
  .cs_app_require("shiny")
  shiny::tagList(
    shiny::h3("About cellspecR"),
    # One string: separate children are joined with spaces, which would
    # stand before the full stops.
    shiny::p(paste0(
      "Version ", as.character(utils::packageVersion("cellspecR")),
      ". Specification ", cs_spec_version(), "."
    )),
    shiny::p(
      "cellspecR defines a versioned table contract for segmented cells from",
      " multiplexed tissue images."
    ),
    shiny::p(
      shiny::a("Project website", href = "https://cttir.github.io/cellspecR/"),
      " - ",
      shiny::a("Source repository", href = "https://github.com/CTTIR/cellspecR")
    )
  )
}
