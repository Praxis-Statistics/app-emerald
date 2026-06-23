# cm_counts.R
# ---------------------------------------------------------------------------
# Concomitant medications (CM) count support.
#
# The CM file (prax-562-311_cm.csv) holds one row per reported medication
# record, so a subject on the same drug across multiple visits/rows appears
# many times. build_cm_subject_counts() dedupes CM to one row per
# (SubjectID, medication) so a plain count bar chart of the medication column
# (e.g. tm_g_bivariate with no y) shows the number of DISTINCT SUBJECTS taking
# each medication, not the raw record count.
#
# Default medication column is CMTRT_PREFERRED -- the WHO Drug standardized
# preferred name -- so trade-name variants (Briviact / Brivaracetam) collapse to
# one medication. The full CM dataset keeps every column (verbatim CMTRT, ATC
# classes, dose, route, ...) for browsing in the Variable Browser / Data Tables.
# ---------------------------------------------------------------------------

library(dplyr)

# Distinct subjects per concomitant medication. Deduping (SubjectID, med) means
# a count bar of <med> = unique subjects, not record counts. Only the id + med
# columns are kept so the counts stay correct for that one medication column.
build_cm_subject_counts <- function(cm, id = "SubjectID", med = "CMTRT_PREFERRED") {
  stopifnot(id %in% names(cm), med %in% names(cm))
  keep <- !is.na(cm[[med]]) & nzchar(trimws(as.character(cm[[med]])))
  dplyr::distinct(cm[keep, c(id, med), drop = FALSE])
}

# A teal transformator that adds a "Top N" slider to a module and trims
# CM_COUNTS to the N medications with the most distinct subjects, ordered so the
# largest bars lead. Without it the bar chart shows all ~370 medications -- an
# unreadable wall; top 20 keeps it legible while staying interactive.
#
# Requires teal + shiny to be loaded (they are, via app.R) when this is called.
# The trim runs inside within(data(), ...) so it stays in teal's reproducible
# "Show R code". Re-runs whenever the slider changes.
cm_top_n_transform <- function(default = 20, max = 50, med = "CMTRT_PREFERRED") {
  teal::teal_transform_module(
    label = "Top N medications",
    datanames = "CM_COUNTS",
    ui = function(id) {
      ns <- shiny::NS(id)
      shiny::sliderInput(
        ns("n_top"), "Show top N medications (by # subjects)",
        min = 5, max = max, value = default, step = 5
      )
    },
    server = function(id, data) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::reactive({
          within(
            data(),
            {
              .ord <- names(sort(table(CM_COUNTS[[MED]]), decreasing = TRUE))
              CM_COUNTS <- CM_COUNTS[CM_COUNTS[[MED]] %in% head(.ord, N), , drop = FALSE]
              # order the factor so the busiest medications lead the bar chart
              CM_COUNTS[[MED]] <- factor(CM_COUNTS[[MED]], levels = rev(head(.ord, N)))
              rm(.ord)
            },
            N = input$n_top,
            MED = med
          )
        })
      })
    }
  )
}
