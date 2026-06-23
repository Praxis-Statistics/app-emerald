# data_databricks.R
# ---------------------------------------------------------------------------
# Live data access for app-emerald. Pulls EDC domains (DM, AE, VS) straight
# from DataBricks via brickster + DBI, reading study CSVs with the Databricks
# read_files() SQL function. Pattern lifted from projects/demo/query_*_data.R.
#
# Auth & paths come from environment variables (set in ~/.Renviron locally and
# in the Posit Connect content's environment on deploy):
#   DATABRICKS_HOST          workspace host URL
#   DATABRICKS_WAREHOUSE_ID  SQL warehouse id
#   DATABRICKS_TOKEN         PAT used by brickster's unified auth
#   PRAXFIVE                 study-FIVE path prefix, e.g.
#                            /Volumes/<catalog>/.../prax-five_
# ---------------------------------------------------------------------------

library(brickster)
library(DBI)

# Per-panel lab dataset loader + the mixed-column splitter.
source(file.path("R", "lb_datasets.R"))

# Connect to the DataBricks SQL warehouse using ambient/env-var auth.
connect_databricks <- function() {
  DBI::dbConnect(
    brickster::DatabricksSQL(),
    warehouse_id = Sys.getenv("DATABRICKS_WAREHOUSE_ID")
  )
}

# Read one study CSV (e.g. "dm", "ae", "vs") via Databricks read_files().
# Path prefix comes from STUDY_PREFIX, falling back to PRAXFIVE for this app
# (study FIVE). The fallback keeps the loader usable standalone, with no
# dependency on demo/setup.R.
read_study_csv <- function(name, con,
                           prefix = Sys.getenv("STUDY_PREFIX",
                                               unset = Sys.getenv("PRAXFIVE"))) {
  if (!nzchar(prefix)) {
    stop("No study path prefix found. Set PRAXFIVE (or STUDY_PREFIX) in the ",
         "environment, e.g. PRAXFIVE=/Volumes/<catalog>/.../prax-five_")
  }
  csv_path <- paste0(prefix, name, ".csv")
  query <- sprintf(
    "SELECT * FROM read_files('%s', format => 'csv', header => true, inferColumnTypes => true)",
    csv_path
  )
  DBI::dbGetQuery(con, query)
}

# Pull the domains this app needs and return a named list of data.frames.
# Opens one connection and reuses it for all reads.
# Note: study FIVE stores ECG as a single "eg" file (study SIX splits it into
# eg1/eg2/eg3) -- this loads the single-file form.
load_emerald_data <- function() {
  con <- connect_databricks()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  core <- list(
    DM = read_study_csv("dm", con),
    AE = read_study_csv("ae", con),
    VS = read_study_csv("vs", con),
    EG = read_study_csv("eg", con),
    # EX (Study Drug Administration) is a single file. Pass it through the same
    # mixed numeric/text column splitter as the lab data (split_mixed_columns()
    # from R/lb_datasets.R) so dose findings view consistently.
    EX = split_mixed_columns(read_study_csv("ex", con))
  )

  # Each lab file (lb1, lb4, ...) becomes its own named dataset (CENTLAB, FSH,
  # UR, CHEM, HEM, VIR, PREG, DRUG, ...) with _num/_char helper columns added
  # for any mixed numeric/text column. See R/lb_datasets.R.
  c(core, load_lb_datasets(con))
}
