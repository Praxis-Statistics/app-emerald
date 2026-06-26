# ie_counts.R
# ---------------------------------------------------------------------------
# Inclusion/Exclusion (IE) eligibility-criteria count support.
#
# Study FIVE's IE form is WIDE: one row per subject, with a Yes/No response per
# eligibility criterion -- inclusion criteria IEITST1..IEITST9 and exclusion
# criteria IEETST1.. (plus the oddly-stemmed IEETT8II). A "deviation" means the
# subject did not satisfy a criterion:
#   inclusion criterion  -> answer "No"  (inclusion NOT met)
#   exclusion criterion  -> answer "Yes" (exclusion condition present)
#
# build_ie_deviation_counts() reshapes IE to LONG format -- one row per
# (SubjectID, Criterion) that carries a deviation -- so a plain count bar chart
# of the Criterion column (tm_g_bivariate with no y) shows the number of
# DISTINCT SUBJECTS with an eligibility deviation per criterion. The Category
# column ("Inclusion not met" / "Exclusion met") colours the two kinds apart.
# The full wide IE dataset keeps every column for browsing in the Variable
# Browser / Data Tables.
# ---------------------------------------------------------------------------

library(dplyr)

# Criterion code -> human-readable label lookup (R/ie_criteria.R).
source(file.path("R", "ie_criteria.R"))

# Long-format deviation rows from the wide IE form. Criteria with no deviations
# never appear (no row), which is the desired "no eligibility issues" reading.
# Criterion (raw code) and CriterionLabel (readable, from IE_CRITERIA) are both
# returned as factors ordered by descending count so the busiest criteria lead
# the bar chart (with swap_axes the top level sits at the top).
build_ie_deviation_counts <- function(ie, id = "SubjectID") {
  stopifnot(id %in% names(ie))

  # (column prefixes, the answer that flags a deviation, the category label)
  specs <- list(
    list(cols = grep("^IEITST",         names(ie), value = TRUE),
         hit = "NO",  category = "Inclusion not met"),
    list(cols = grep("^IEETST|^IEETT",  names(ie), value = TRUE),
         hit = "YES", category = "Exclusion met")
  )

  parts <- list()
  for (s in specs) {
    for (cn in s$cols) {
      v   <- toupper(trimws(as.character(ie[[cn]])))
      dev <- !is.na(v) & v == s$hit
      if (!any(dev)) next
      parts[[length(parts) + 1L]] <- data.frame(
        SubjectID = ie[[id]][dev],
        Criterion = cn,
        Category  = s$category,
        stringsAsFactors = FALSE
      )
    }
  }

  out <- if (length(parts))
    dplyr::distinct(do.call(rbind, parts))
  else
    data.frame(SubjectID = character(), Criterion = character(),
               Category = character(), stringsAsFactors = FALSE)
  names(out)[1] <- id

  # Readable label per criterion code (e.g. "Incl 6: >=4 countable motor ...").
  out$CriterionLabel <- ie_label_codes(out$Criterion)

  # Order both code and label factors by descending deviation count so the
  # busiest criteria lead the bar chart.
  ord       <- names(sort(table(out$Criterion), decreasing = TRUE))
  ord_label <- ie_label_codes(ord)
  out$Criterion      <- factor(out$Criterion,      levels = rev(ord))
  out$CriterionLabel <- factor(out$CriterionLabel, levels = rev(ord_label))
  out
}
