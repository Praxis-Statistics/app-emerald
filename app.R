# app.R
# ---------------------------------------------------------------------------
# Emerald — exploratory teal app for non-CDISC EDC data.
# Pulls DM, AE and VS live from DataBricks (study FIVE) and exposes them
# through the standard teal data-viewer modules.
#
# Run locally:   shiny::runApp()   (or: bash run_app.sh)
# Requires DataBricks env vars (see R/data_databricks.R) in ~/.Renviron.
# ---------------------------------------------------------------------------

library(teal)
library(teal.modules.general)

source("R/data_databricks.R")

# Pull the data once at app startup.
raw <- load_emerald_data()

# Build a plain (non-CDISC) teal_data container from the live data.frames.
data <- teal_data(
  DM = raw$DM,
  AE = raw$AE,
  VS = raw$VS,
  EG = raw$EG
)

# Non-CDISC join keys so the filter panel propagates selections across domains
# on SubjectID. DM is 1 row/subject (primary); AE, VS & EG are many rows/subject.
# If the live schema uses a different subject-id column, adjust here (or drop
# join_keys entirely — the viewer modules below work without them).
join_keys(data) <- join_keys(
  join_key("DM", "DM", "SubjectID"),
  join_key("DM", "AE", "SubjectID"),
  join_key("DM", "VS", "SubjectID"),
  join_key("DM", "EG", "SubjectID")
)

# Assemble the app: a simple data viewer over the three domains.
app <- init(
  data = data,
  modules = list(
    tm_front_page(
      header_text = c(
        "Emerald — EDC Data Explorer" =
          "Exploratory viewer for non-CDISC EDC data, study FIVE.",
        "Source" =
          "Data pulled live from DataBricks (DM, AE, VS, EG).",
        "Modules" =
          "Use the Modules dropdown to browse tables, variables and missing data."
      )
    ),
    tm_data_table(
      label = "Data Tables"
    ),
    tm_variable_browser(
      label = "Variable Browser"
    ),
    tm_missing_data(
      label = "Missing Data"
    )
  )
) |>
  modify_title("Emerald — EDC Data Explorer (Study FIVE)")

shinyApp(app$ui, app$server)
