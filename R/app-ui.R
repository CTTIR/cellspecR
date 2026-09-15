# User interface for the cellspec review app.

.cs_app_ui <- function(initial_path = NULL, max_upload_mb = 2048,
                       allow_local_paths = FALSE) {
  .cs_app_require("shiny")
  controls <- shiny::tagList(
    shiny::fileInput("f_export", "Cell table or cellspec directory", multiple = FALSE),
    if (allow_local_paths) shiny::textInput("local_path", "Local path", value = if (is.null(initial_path)) "" else initial_path),
    shiny::selectInput(
      "format", "Format", choices = c("Auto-detect" = "auto", cs_formats()$format),
      selected = "auto"
    ),
    shiny::numericInput("pixel_size", "Pixel size (\u00b5m/px)", value = NA, min = 0),
    shiny::actionButton("btn_read", "Read", class = "btn-primary w-100")
  )
  body <- shiny::tabsetPanel(
    shiny::tabPanel("Status", shiny::verbatimTextOutput("status")),
    shiny::tabPanel("Detection", shiny::tableOutput("detection")),
    shiny::tabPanel(
      "Validation",
      shiny::downloadButton("download_validation", "Download validation"),
      shiny::tableOutput("validation")
    ),
    shiny::tabPanel("Cells", shiny::tableOutput("cells")),
    shiny::tabPanel(
      "Dictionary",
      shiny::downloadButton("download_dictionary", "Download dictionary"),
      shiny::tableOutput("dictionary")
    ),
    shiny::tabPanel("Images", shiny::tableOutput("images")),
    shiny::tabPanel("Plot", shiny::plotOutput("overview"))
  )
  if (requireNamespace("bslib", quietly = TRUE)) {
    bslib::page_sidebar(
      title = "cellspecR",
      sidebar = bslib::sidebar(controls),
      body
    )
  } else {
    shiny::fluidPage(shiny::titlePanel("cellspecR"), shiny::sidebarLayout(
      shiny::sidebarPanel(controls), shiny::mainPanel(body)
    ))
  }
}
