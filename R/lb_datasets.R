# lb_datasets.R
# ---------------------------------------------------------------------------
# Study FIVE's lab data is split across per-panel EDC files (lb1, lb4, lb5,
# ...). Each is a different test form, so each gets its OWN teal dataset with a
# meaningful short name (taken from the file's `Form` value) instead of being
# combined.
#
# For easy viewing, split_mixed_columns() inspects each loaded file and -- for
# any column that genuinely mixes numbers and text -- adds two helper columns:
#   <col>_num   the numeric values (NA where the value isn't a number)
#   <col>_char  the text values    (NA where the value IS a number)
# so a numeric finding can be browsed as a distribution while the text findings
# stay separate. The original column is left untouched. Columns that are purely
# numeric or purely text are left alone (study FIVE's EDC already separates most
# results into distinct numeric/categorical columns, e.g. URRSLT2 vs URRSLT1).
#
# Reuses read_study_csv() from R/data_databricks.R.
# ---------------------------------------------------------------------------

library(DBI)

# File stem -> dataset name + human label. Names confirmed from each file's
# `Form` value in study FIVE (study 562-311). Files not listed here still load,
# under their upper-cased stem (e.g. lb11 -> LB11).
LB_DATASETS <- list(
  lb1  = list(name = "CENTLAB", label = "Central Laboratory Assessments"),
  lb4  = list(name = "FSH",     label = "Serum FSH Test"),
  lb5  = list(name = "UR",      label = "Local Lab Urinalysis"),
  lb6  = list(name = "CHEM",    label = "Local Lab Chemistry"),
  lb7  = list(name = "HEM",     label = "Local Lab Hematology"),
  lb8  = list(name = "VIR",     label = "Local Lab Viral Serology"),
  lb9  = list(name = "PREG",    label = "Pregnancy Test"),
  lb10 = list(name = "DRUG",    label = "Local Urine Drug Test")
)

# Add <col>_num / <col>_char for every column that mixes numeric and text
# values. Datetime/housekeeping columns are skipped by name; everything else is
# decided purely from its contents.
split_mixed_columns <- function(d, skip = "_DTM$|_rescued_data") {
  for (cn in names(d)) {
    if (grepl(skip, cn)) next
    x <- d[[cn]]
    if (!is.character(x) && !is.factor(x)) next            # numeric cols are fine as-is
    chr <- trimws(as.character(x))
    nonblank <- nzchar(chr) & !is.na(chr)
    if (!any(nonblank)) next
    num <- suppressWarnings(as.numeric(chr))
    has_num <- any(!is.na(num) & nonblank)
    has_txt <- any(is.na(num) & nonblank)
    if (!(has_num && has_txt)) next                         # only split genuine mixes
    d[[paste0(cn, "_num")]]  <- num
    d[[paste0(cn, "_char")]] <- ifelse(is.na(num) & nonblank, chr, NA_character_)
  }
  d
}

# Read each lab file as its own dataset (tolerant of missing files), apply the
# mixed-column split, and return a named list keyed by the chosen dataset name.
load_lb_datasets <- function(con, files = paste0("lb", 1:15)) {
  out <- list()
  for (nm in files) {
    d <- tryCatch(read_study_csv(nm, con),
                  error = function(e) {
                    message(sprintf("  [skip] %s not found", nm)); NULL })
    if (is.null(d)) next
    cfg  <- LB_DATASETS[[nm]]
    name <- if (!is.null(cfg)) cfg$name else toupper(nm)
    base <- name; k <- 2L                                   # guard name collisions
    while (name %in% names(out)) { name <- paste0(base, k); k <- k + 1L }
    out[[name]] <- split_mixed_columns(d)
  }
  if (length(out) == 0)
    warning("load_lb_datasets(): no lab files loaded; check lb* names / PRAXFIVE.")
  out
}

# Discovery helper: print each lab file's dataset name, dims and columns so the
# LB_DATASETS map can be reviewed. Run interactively:
#   source("R/data_databricks.R"); profile_lb_datasets(connect_databricks())
profile_lb_datasets <- function(con, files = paste0("lb", 1:15)) {
  rows <- list()
  for (nm in files) {
    d <- tryCatch(read_study_csv(nm, con), error = function(e) NULL)
    if (is.null(d)) next
    cfg <- LB_DATASETS[[nm]]
    rows[[nm]] <- data.frame(
      file = nm,
      name = if (is.null(cfg)) toupper(nm) else cfg$name,
      form = if ("Form" %in% names(d)) as.character(d$Form[1]) else NA_character_,
      n_rows = nrow(d), n_cols = ncol(d), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  print(out, row.names = FALSE)
  invisible(out)
}
