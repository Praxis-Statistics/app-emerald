# ie_criteria.R
# ---------------------------------------------------------------------------
# Lookup table for study FIVE's Inclusion/Exclusion (IE) criterion codes.
#
# The IE EDC form uses cryptic column names (IEITST1..IEITST9 for inclusion,
# IEETST1.. / IEETT8II for exclusion) with no criterion text. IE_CRITERIA maps
# each code to its protocol category, item tag, a short label (for chart axes)
# and the full criterion wording (for the browsable reference table).
#
# Mapping confirmed against the live response patterns (e.g. IEITST6 -- the
# "4+ countable motor seizures" criterion -- carries by far the most "No"
# answers; exclusion 8's two lab sub-parts arrive as the paired IEETST8I /
# IEETT8II columns with identical counts). Criterion 8 of the exclusion list
# (abnormal labs) splits into 8i (bilirubin) and 8ii (ALT/AST).
#
# NOTE: IEITST9 has no matching criterion in the supplied protocol text (it is
# the 9th inclusion column but only 8 inclusion criteria were provided, and it
# is mostly blank in the data). Its wording is left flagged for confirmation.
# ---------------------------------------------------------------------------

# code, category, item tag, short label (chart), full criterion text (table)
IE_CRITERIA <- data.frame(
  Code = c(
    "IEITST1", "IEITST2", "IEITST3", "IEITST4", "IEITST5",
    "IEITST6", "IEITST7", "IEITST8", "IEITST9",
    "IEETST1", "IEETST2", "IEETST3", "IEETST4", "IEETST5", "IEETST6",
    "IEETST7", "IEETST8I", "IEETT8II", "IEETST9", "IEETST10", "IEETST11"
  ),
  Category = c(
    rep("Inclusion", 9),
    rep("Exclusion", 12)
  ),
  Item = c(
    "Incl 1", "Incl 2", "Incl 3", "Incl 4", "Incl 5",
    "Incl 6", "Incl 7", "Incl 8", "Incl 9",
    "Excl 1", "Excl 2", "Excl 3", "Excl 4", "Excl 5", "Excl 6",
    "Excl 7", "Excl 8i", "Excl 8ii", "Excl 9", "Excl 10", "Excl 11"
  ),
  Short = c(
    "Informed consent",
    "DEE diagnosis (ERC-confirmed)",
    "Seizure onset <12 yrs",
    "Age 2-65 yrs",
    "Weight >7 kg",
    ">=4 countable motor seizures (28d)",
    "Stable ASM/intervention >=1 mo",
    "Seizure diary >=75% of days",
    "(not in provided protocol text)",
    "Clinically significant condition",
    "Cardiac history / arrhythmia risk",
    "Requires prohibited medication",
    ">=2 convulsive SE hospitalizations (6 mo)",
    "Abnormal ECG / QTcB out of range",
    ">2 sodium-channel-blocker ASMs",
    "Nerve stimulation timing",
    "Total bilirubin >1.5x ULN",
    "ALT/AST >3x ULN",
    "Experimental therapy <=30d / 5 half-lives",
    "Hypersensitivity to relutrigine",
    "Pregnant / breastfeeding"
  ),
  Criterion = c(
    # --- Inclusion ---
    "Participant (and caregiver, if applicable) is willing to sign informed consent per ICH/GCP, understands the trial purpose and procedures, can perform/comply with all required procedures and assessments including the seizure diary and appropriate contraception, and is willing to participate.",
    "Has a documented diagnosis of a developmental and epileptic encephalopathy (DEE) confirmed by the Eligibility Review Committee (ERC).",
    "Onset of seizures before 12 years of age.",
    "Male or female aged >=2 and <=65 years at the time of screening.",
    "Weight >7 kg at the time of signing consent/assent.",
    "Has >=4 countable motor seizures during the 28-day Baseline Observation Period, with no motor-seizure-free period longer than 21 consecutive days. (Countable motor seizures: tonic, clonic, tonic-clonic, atonic, focal to bilateral tonic-clonic, and focal seizures with observable motor symptoms; excludes myoclonic, absence, focal non-motor seizures, and epileptic spasms.)",
    "If prescribed any ASM or non-pharmacological intervention (incl. ketogenic diet and VNS) for epilepsy or other early-onset SCN2A-DEE symptoms, is on a stable dose/settings/parameters for 1 month prior to screening (excluding weight-based dose changes).",
    "Seizure diary completed on >=75% of days during the Screening/Baseline Observation Period.",
    "Criterion not included in the provided protocol text; mapping for IEITST9 to be confirmed.",
    # --- Exclusion ---
    "Any clinically significant ongoing disease, disorder, or laboratory abnormality; alcohol or drug abuse/dependence; environmental factor; or psychiatric, medical, or surgical condition that, in the investigator's judgment (with medical monitor/sponsor consultation), might jeopardize safety, impact scientific objectives, or interfere with participation.",
    "History of left bundle branch block, arrhythmias, Brugada syndrome, congenital heart disease, familial short QT syndrome, or family history of sudden death or ventricular arrhythmias (including idiopathic ventricular fibrillation).",
    "Required to take, or anticipated to require, any prohibited medication, dietary supplement, or food listed in Section 6.5.2 of the protocol.",
    ">=2 episodes of convulsive status epilepticus requiring hospitalization and intubation in the 6 months prior to screening.",
    "Abnormal ECG, including QTcB <350 or >450 ms (males) or <360 or >460 ms (females) at screening and/or Day 1, based on the average of triplicate measurements.",
    "Currently prescribed more than 2 sodium channel blocker ASMs (see Appendix 4 for the list).",
    "Any nerve stimulation device (VNS, responsive neurostimulation, etc.) placed less than 3 months prior to screening, or without at least 1 month of stable settings prior to screening.",
    "Abnormal labs at screening: serum total bilirubin >1.5x ULN. (Gilbert's-syndrome pattern -- elevated total bilirubin without ALT/AST elevation -- may be enrolled per medical monitor approval if conjugated bilirubin is within ULN.)",
    "Abnormal labs at screening: serum ALT or AST >3x ULN.",
    "Received any other experimental/investigational drug, device, or therapy within 30 days or 5 half-lives (whichever is longer) prior to screening, including any prior gene therapy.",
    "Known hypersensitivity to any component of the relutrigine formulation.",
    "Currently pregnant or breastfeeding, or planning to become pregnant during the trial or within 5 half-lives of the last study drug dose."
  ),
  stringsAsFactors = FALSE
)

# Named vector code -> "Item: Short" display label, used to make IE chart axes
# and tables human-readable (e.g. "Incl 6: >=4 countable motor seizures (28d)").
# Codes with no entry fall back to themselves via the [[ ]] default in callers.
ie_criterion_labels <- function() {
  setNames(paste0(IE_CRITERIA$Item, ": ", IE_CRITERIA$Short), IE_CRITERIA$Code)
}

# Map a vector of codes to display labels, leaving unknown codes unchanged.
ie_label_codes <- function(codes) {
  lab <- ie_criterion_labels()
  out <- unname(lab[as.character(codes)])
  ifelse(is.na(out), as.character(codes), out)
}

# Static HTML reference table of the full criteria, for display directly under
# the Eligibility Deviations plot (via tm_g_bivariate's post_output). IE_CRITERIA
# never changes, so a plain shiny.tag table is all that's needed -- no reactive
# render. Inclusion rows are tinted blue, exclusion rows orange, to match the
# chart's fill = Category colouring.
ie_criteria_html <- function(crit = IE_CRITERIA) {
  cell <- "padding:4px 8px; vertical-align:top;"
  row <- function(i) {
    bg <- if (crit$Category[i] == "Inclusion") "#eef6ff" else "#fff3ee"
    htmltools::tags$tr(
      style = sprintf("background:%s;", bg),
      htmltools::tags$td(crit$Item[i],
        style = paste0(cell, "white-space:nowrap; font-weight:bold;")),
      htmltools::tags$td(crit$Code[i],
        style = paste0(cell, "white-space:nowrap; font-family:monospace;")),
      htmltools::tags$td(crit$Criterion[i], style = cell)
    )
  }
  htmltools::tagList(
    htmltools::tags$h4("Inclusion / Exclusion criteria reference",
                       style = "margin:16px 0 4px;"),
    htmltools::tags$p(
      "Criterion codes as they appear in the IE form. A deviation = an ",
      "inclusion criterion answered \"No\" or an exclusion criterion answered ",
      "\"Yes\".",
      style = "color:#555; font-size:12px; margin:0 0 8px;"),
    htmltools::tags$table(
      style = "border-collapse:collapse; width:100%; font-size:12px;",
      htmltools::tags$thead(
        htmltools::tags$tr(
          lapply(c("Item", "Code", "Criterion"), function(h)
            htmltools::tags$th(h,
              style = "text-align:left; border-bottom:2px solid #888; padding:4px 8px;"))
        )
      ),
      htmltools::tags$tbody(lapply(seq_len(nrow(crit)), row))
    )
  )
}
