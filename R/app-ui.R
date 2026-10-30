# User interface for the cellspec review app.

.cs_app_ui <- function(initial_path = NULL,
                       allow_local_paths = FALSE) {
  .cs_app_require("shiny")
  controls <- shiny::tagList(
    shiny::fileInput("f_export", "Cell table file (CSV, TSV, gzip or RDS)", multiple = FALSE),
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
    shiny::tabPanel("Detection", .cs_app_table("detection", "Detection table")),
    shiny::tabPanel(
      "Validation",
      shiny::downloadButton("download_validation", "Download validation"),
      .cs_app_table("validation", "Validation table")
    ),
    shiny::tabPanel("Cells", .cs_app_table("cells", "Cells table")),
    shiny::tabPanel(
      "Dictionary",
      shiny::downloadButton("download_dictionary", "Download dictionary"),
      .cs_app_table("dictionary", "Dictionary table")
    ),
    shiny::tabPanel("Images", .cs_app_table("images", "Images table")),
    shiny::tabPanel("Plot", shiny::plotOutput("overview")),
    shiny::tabPanel("About", .cs_app_about())
  )
  if (requireNamespace("bslib", quietly = TRUE)) {
    bslib::page_sidebar(
    window_title = "cellspecR",
      title = shiny::tagList(.cttir_brand_logo(), "cellspecR"),
      sidebar = bslib::sidebar(controls),
      body
    )
  } else {
    shiny::fluidPage(shiny::titlePanel(shiny::tagList(.cttir_brand_logo(), "cellspecR"),
      windowTitle = "cellspecR"), shiny::sidebarLayout(
      shiny::sidebarPanel(controls), shiny::mainPanel(body)
    ))
  }
}

# Keep wide metadata accessible on narrow displays and from the keyboard.
.cs_app_table <- function(id, label) {
  shiny::div(class = "table-responsive", tabindex = 0, role = "region",
    `aria-label` = label, shiny::tableOutput(id))
}
