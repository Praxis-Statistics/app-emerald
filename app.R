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

# Default columns shown per dataset in the Data Tables module. Every domain
# arrives with the same EDC scaffolding (MedrioID, Form, FormEntryDate, the two
# *_CREATE/LAST_UPD_DTM audit stamps, SubjectVisitFormID, VarGroup*Row,
# _rescued_data) that buries the informative fields on first read. These presets
# lead with SubjectID and the columns that actually characterise each domain.
# Visit is included only where the data is genuinely visit-based (VS, EG, EX,
# labs); for the per-subject domains (DM demographics, IE eligibility) Visit is
# uninformative, so we lead with status/demographics/criteria instead. Datasets
# not listed (CM_COUNTS, IE_COUNTS, IE_CRITERIA) are small and show all columns.
dt_vars <- list(
  # Demographics: one row/subject. Show who the subject is, not the visit.
  DM   = c("SubjectID", "Site", "SubjectStatus", "AGE", "SEX", "CHILDBP", "ETHNIC"),
  # Adverse events: event-based. Verbatim + preferred term, dates, grading.
  AE   = c("SubjectID", "Visit", "AETERM", "AETERM_PT", "AESTDAT", "AEENDAT",
           "AESEV", "AEREL", "AESER", "AEOUT"),
  # Vital signs: visit-based measurements.
  VS   = c("SubjectID", "Visit", "VSDAT", "POSITION", "SYSBP", "DIABP",
           "PULSE", "RESP", "TEMP"),
  # ECG: visit-based intervals + interpretation.
  EG   = c("SubjectID", "Visit", "EGDAT", "EGHR", "EGQTI", "EGQTCI", "EGQTCB",
           "EGPICS"),
  # Study drug administration: visit-based dose record.
  EX   = c("SubjectID", "Visit", "EXDAT", "EXDOSTIM", "EXDOSE", "EXDOSOT",
           "EXCYN"),
  # Concomitant meds: per-medication, not per-visit. Drug, reason, dose, dates.
  CM   = c("SubjectID", "CMTRT", "CMTRT_PREFERRED", "CMREASON", "CMDSTXT",
           "CMDOSU", "CMDOSFRQ", "CMROUTE", "CMSTDAT", "CMENDAT", "CMONGO"),
  # Inclusion/Exclusion: wide, one row/subject. The criteria responses ARE the
  # content; Visit is uninformative. Lead with status + the assessment date,
  # then every criterion column.
  IE   = c("SubjectID", "SubjectStatus", "IEIEDAT",
           "IEITST1", "IEITST2", "IEITST3", "IEITST4", "IEITST5", "IEITST6",
           "IEITST7", "IEITST8", "IEITST9",
           "IEETST1", "IEETST2", "IEETST3", "IEETST4", "IEETST5", "IEETST6",
           "IEETST7", "IEETST8I", "IEETT8II", "IEETST9", "IEETST10", "IEETST11"),
  # Lab panels: visit-based. Lead with test, result, units and reference range.
  CENTLAB = c("SubjectID", "Visit", "TEST", "LB1SCCL", "DATEC", "LBINAS"),
  FSH  = c("SubjectID", "Visit", "LB4YN", "LB4DAT", "LB4ORRES"),
  UR   = c("SubjectID", "Visit", "URDT", "URTST", "URRSLT1", "URRSLT2",
           "URUN", "URRRLL", "URRRUL", "URCLSG"),
  CHEM = c("SubjectID", "Visit", "CHMDT", "CHMTST", "CHMRSLT", "CHMUN",
           "CHMRRLL", "CHMRRUL", "CHMCLSG"),
  HEM  = c("SubjectID", "Visit", "LB7DAT", "LB7TEST", "LB7RES", "LB7TUN",
           "LB7LNL", "LB7UNL"),
  VIR  = c("SubjectID", "Visit", "VIRDT", "VIRTEST", "VIRRSLT1", "VIRRSLT2",
           "VIRUN"),
  PREG = c("SubjectID", "Visit", "LBDAT", "LBSPEC", "LBYN", "LBORRES1"),
  DRUG = c("SubjectID", "Visit", "DRUGTDT", "DRUGTST", "DRUGRSLT")
)
# Keep only presets whose dataset actually loaded this run (lab files vary), and
# drop any column not present so a schema change can't error the whole module.
dt_vars <- Map(function(nm, cols) intersect(cols, names(raw[[nm]])),
               names(dt_vars), dt_vars)[intersect(names(dt_vars), names(raw))]

# Guarantee SubjectID leads every table. Any loaded dataset that carries a
# SubjectID but has no curated preset above (e.g. CM_COUNTS, IE_COUNTS, an
# unexpected lab file) gets a default preset of all its columns with SubjectID
# pulled to the front. (IE_CRITERIA has no SubjectID, so it is untouched.)
for (nm in setdiff(names(raw), names(dt_vars))) {
  cols <- names(raw[[nm]])
  if ("SubjectID" %in% cols)
    dt_vars[[nm]] <- c("SubjectID", setdiff(cols, "SubjectID"))
}

# Assemble the app: a simple data viewer over all domains.
app <- init(
  data = data,
  modules = list(
    tm_front_page(
      header_text = c(
        "Emerald — EDC Data Explorer" =
          "Exploratory viewer for non-CDISC EDC data, study FIVE.",
        "Source" =
          "Data pulled live from DataBricks. DM, AE, VS, EG, EX (Study Drug Administration), CM (Concomitant Medications), IE (Inclusion/Exclusion) plus each lab panel as its own dataset (CENTLAB, FSH, UR, CHEM, HEM, VIR, PREG, DRUG). Mixed numeric/text columns are split into <col>_num and <col>_char for easy distribution viewing.",
        "Modules" =
          "Use the Modules dropdown to browse tables, variables and missing data, open Time Course (Spaghetti) to plot any numeric measurement over time per subject (toggle dataset and test), Medication Counts for distinct subjects per concomitant medication, or Eligibility Deviations for distinct subjects with an inclusion/exclusion deviation per criterion."
      )
    ),
    tm_data_table(
      label = "Data Tables",
      # Sensible per-domain default columns (see dt_vars above); users can still
      # add/remove any column via the module's variable selector.
      variables_selected = dt_vars
    ),
    tm_variable_browser(
      label = "Variable Browser"
    ),
    # Spaghetti (line-per-subject) viewer over the harmonised TIMECOURSE table.
    # Dataset + Test dropdowns drive a single pane (no faceting); X axis toggles
    # Visit (aligned, median-date ordered) vs Date. See tm_g_spaghetti() in
    # R/timecourse.R. Covers VS, EG, EX and the numeric lab panels.
    tm_g_spaghetti(label = "Time Course (Spaghetti)"),
    tm_missing_data(
      label = "Missing Data"
    ),
    # Distinct subjects per concomitant medication. CM_COUNTS is deduped to one
    # row per (SubjectID, CMTRT_PREFERRED) in R/cm_counts.R, so a count bar chart
    # of CMTRT_PREFERRED (x set, y left empty) = number of unique subjects per
    # medication, not raw record counts. swap_axes -> horizontal bars so the
    # WHO Drug preferred names stay readable.
    tm_g_bivariate(
      label = "Medication Counts",
      x = data_extract_spec(
        dataname = "CM_COUNTS",
        select = select_spec(
          label = "Medication (WHO Drug preferred name):",
          choices = variable_choices(raw$CM_COUNTS, "CMTRT_PREFERRED"),
          selected = "CMTRT_PREFERRED",
          fixed = TRUE
        )
      ),
      y = data_extract_spec(
        dataname = "CM_COUNTS",
        select = select_spec(
          label = "Y (leave empty for subject counts):",
          choices = variable_choices(raw$CM_COUNTS, "CMTRT_PREFERRED"),
          selected = NULL,
          multiple = FALSE,
          fixed = FALSE
        )
      ),
      swap_axes = TRUE,
      # "Top N" slider (default 20) so the chart shows only the busiest
      # medications instead of all ~370. See cm_top_n_transform() in R/cm_counts.R.
      transformators = list(cm_top_n_transform(default = 20))
    ),
    # Distinct subjects with an eligibility deviation, per criterion. IE_COUNTS
    # is the wide IE form reshaped to one row per (SubjectID, Criterion) carrying
    # a deviation (inclusion not met / exclusion present) in R/ie_counts.R, so a
    # count bar of CriterionLabel (x set, y empty) = unique subjects flagged per
    # criterion. CriterionLabel is the human-readable wording from the IE_CRITERIA
    # lookup (R/ie_criteria.R); fill = Category (needs color_settings) colours
    # inclusion vs exclusion apart; swap_axes -> horizontal bars keep labels legible.
    tm_g_bivariate(
      label = "Eligibility Deviations",
      x = data_extract_spec(
        dataname = "IE_COUNTS",
        select = select_spec(
          label = "Criterion:",
          choices = variable_choices(raw$IE_COUNTS, "CriterionLabel"),
          selected = "CriterionLabel",
          fixed = TRUE
        )
      ),
      y = data_extract_spec(
        dataname = "IE_COUNTS",
        select = select_spec(
          label = "Y (leave empty for subject counts):",
          choices = variable_choices(raw$IE_COUNTS, "CriterionLabel"),
          selected = NULL,
          multiple = FALSE,
          fixed = FALSE
        )
      ),
      fill = data_extract_spec(
        dataname = "IE_COUNTS",
        select = select_spec(
          label = "Colour by:",
          choices = variable_choices(raw$IE_COUNTS, "Category"),
          selected = "Category",
          fixed = TRUE
        )
      ),
      color_settings = TRUE,
      swap_axes = TRUE,
      # Full criteria reference table rendered directly below the plot, so the
      # cryptic codes/labels can be read in place. Static HTML (IE_CRITERIA never
      # changes) built by ie_criteria_html() in R/ie_criteria.R.
      post_output = ie_criteria_html()
    )
  )
) |>
  modify_title("Emerald — EDC Data Explorer (Study FIVE)")

shinyApp(app$ui, app$server)
