# app.R
# ---------------------------------------------------------------------------
# Emerald — exploratory teal app for non-CDISC EDC data.
# Pulls DM, AE, VS, EG, EX and the per-panel lab files live from DataBricks
# (study FIVE) and exposes them through the standard teal data-viewer modules.
# Each lab file is its own dataset (CENTLAB, FSH, UR, CHEM, HEM, VIR, PREG,
# DRUG, ...) — see R/lb_datasets.R.
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
# `raw` is a named list (DM, AE, VS, EG + one entry per lab dataset), so build
# the container dynamically rather than naming each domain by hand.
data <- do.call(teal_data, raw)

# Non-CDISC join keys so the filter panel propagates selections across domains
# on SubjectID. DM is 1 row/subject (primary); every other domain is many
# rows/subject. All domains are study FIVE, so SubjectID joins are valid. Only
# domains that actually carry a SubjectID column are linked.
jk <- list(join_key("DM", "DM", "SubjectID"))
for (nm in setdiff(names(raw), "DM")) {
  if ("SubjectID" %in% names(raw[[nm]]))
    jk <- c(jk, list(join_key("DM", nm, "SubjectID")))
}
join_keys(data) <- do.call(join_keys, jk)

# Assemble the app: a simple data viewer over all domains.
app <- init(
  data = data,
  modules = list(
    tm_front_page(
      header_text = c(
        "Emerald — EDC Data Explorer" =
          "Exploratory viewer for non-CDISC EDC data, study FIVE.",
        "Source" =
          "Data pulled live from DataBricks. DM, AE, VS, EG, EX (Study Drug Administration) plus each lab panel as its own dataset (CENTLAB, FSH, UR, CHEM, HEM, VIR, PREG, DRUG). Mixed numeric/text columns are split into <col>_num and <col>_char for easy distribution viewing.",
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
