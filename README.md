# app-emerald

Exploratory **teal** app for **non-CDISC EDC data**. A simple data viewer over **DM, AE, VS,
EG (ECG), EX (Study Drug Administration), CM (Concomitant Medications), IE (Inclusion/Exclusion)**
plus each **lab panel as its own dataset** — pulled **live from DataBricks** (study **FIVE**) and
deployed to **Posit Connect Cloud**.

`EX` is a single file; like the lab datasets its mixed numeric/text columns are split into
`<col>_num` / `<col>_char` via `split_mixed_columns()`.

### Inclusion/Exclusion (IE)

`IE` loads as its own dataset. Study FIVE's IE form is **wide** — one row per subject with a
Yes/No response per eligibility criterion (inclusion `IEITST1`–`IEITST9`, exclusion `IEETST*` /
`IEETT8II`). From it, `build_ie_deviation_counts()` (`R/ie_counts.R`) derives `IE_COUNTS` — IE
reshaped to **long** format, one row per `(SubjectID, Criterion)` that carries a *deviation*
(an inclusion criterion answered "No", or an exclusion criterion answered "Yes"). So the
**Eligibility Deviations** module (`tm_g_bivariate`, criterion on x, y empty, filled by category)
shows a bar chart of **distinct subjects with a deviation per criterion**. Criteria with no
deviations simply don't appear. The full wide `IE` dataset stays browsable via the Variable
Browser / Data Tables.

The cryptic criterion codes are decoded by the `IE_CRITERIA` lookup table (`R/ie_criteria.R`) —
code → category, item tag (`Incl 6`, `Excl 8i`, …), short label and full protocol wording.
It loads as its own (unlinked, no-`SubjectID`) reference dataset, supplies the human-readable
`CriterionLabel` axis on the deviations chart, and is rendered as a static HTML table
(`ie_criteria_html()`) **directly below the Eligibility Deviations plot** via `tm_g_bivariate`'s
`post_output`. Mapping was confirmed against the live response patterns; **`IEITST9` has no
matching criterion in the supplied protocol text and is flagged for confirmation.**

### Concomitant medications (CM)

`CM` loads as its own dataset. From it, `build_cm_subject_counts()` (`R/cm_counts.R`) derives
`CM_COUNTS` — CM deduped to one row per `(SubjectID, CMTRT_PREFERRED)` (the WHO Drug preferred
name) — so the **Medication Counts** module (`tm_g_bivariate`, medication on x, y empty) shows a
bar chart of **distinct subjects per medication** rather than raw record counts. The full `CM`
dataset (verbatim `CMTRT`, ATC classes, dose, route, …) stays browsable via the Variable
Browser / Data Tables.

### Time course (spaghetti plots)

The visit-based domains store their measurements in incompatible shapes — `VS`, `EG`, `EX` are
**wide** (a column per parameter: `SYSBP`, `EGQTCB`, `EXDOSE`, …), while the lab panels are
**long** (a test-name column + a result column: `CHEM` is `CHMTST`/`CHMRSLT`, …). To browse any of
them as a line-per-subject time course from **one** pane, `build_timecourse()` (`R/timecourse.R`)
stacks them into a single tidy long table, `TIMECOURSE` (`SubjectID, Dataset, Test, Visit, Date,
Value, Unit`). Only numeric results are kept (a spaghetti plot needs a numeric Y), so qualitative
panels (`PREG`, `DRUG`) and text-result panels (`CENTLAB`, `UR`, `VIR`) drop out automatically.

The **Time Course (Spaghetti)** module (`tm_g_spaghetti()`, a custom `teal::module()`) plots it:
pick a **Dataset** then a **Test** from two dropdowns and get one line per subject — no faceting.
The X axis toggles between **Date** (true elapsed time, the default) and **Visit** (aligned, ordered
by median date), with an adaptive trend overlay (loess on Date, mean-per-visit on Visit) and an
optional log Y. It renders with **plotly**, so hovering a point shows that observation's
**subject, visit, value and date**. Filter-panel subject selections propagate in via the
`SubjectID` join to `DM`.

### Lab datasets

Study FIVE splits labs across per-panel EDC files (`lb1`, `lb4`, `lb5`, …). Each loads as its own
named dataset (name taken from the file's `Form` value) so it gets its own viewer:

| File | Dataset | Form |
|------|---------|------|
| `lb1` | `CENTLAB` | Central Laboratory Assessments |
| `lb4` | `FSH` | Serum FSH Test |
| `lb5` | `UR` | Local Lab Urinalysis |
| `lb6` | `CHEM` | Local Lab Chemistry |
| `lb7` | `HEM` | Local Lab Hematology |
| `lb8` | `VIR` | Local Lab Viral Serology |
| `lb9` | `PREG` | Pregnancy Test |
| `lb10` | `DRUG` | Local Urine Drug Test |

Names/labels live in `LB_DATASETS` (`R/lb_datasets.R`); unlisted files load under their upper-cased
stem (e.g. `lb11` → `LB11`). For easy viewing, any column that **mixes numbers and text** gets two
helper columns — `<col>_num` (numeric, for distributions) and `<col>_char` (the text) — added by
`split_mixed_columns()`. Run `profile_lb_datasets(connect_databricks())` to list the live files.

## What's here

| File | Purpose |
|------|---------|
| `app.R` | teal app entry point — builds `teal_data()` and the viewer modules |
| `R/data_databricks.R` | live DataBricks access (`brickster` + `DBI`, `read_files()`) |
| `R/lb_datasets.R` | per-panel lab loader: names each `lb*` file + splits mixed numeric/text columns |
| `R/cm_counts.R` | concomitant-meds count helper: dedupes CM to distinct subjects per medication |
| `R/ie_counts.R` | inclusion/exclusion count helper: reshapes wide IE to distinct subjects per deviation |
| `R/ie_criteria.R` | IE criterion lookup: code → category, label, full protocol wording (`IE_CRITERIA`) |
| `R/timecourse.R` | harmonises visit-based domains into long `TIMECOURSE` + the spaghetti viewer (`tm_g_spaghetti()`) |
| `install_packages.R` / `PACKAGES.txt` | package install helper / list |
| `run_app.sh` | install deps + launch locally |
| `.posit/publish/app-emerald.toml` | Posit Publisher deployment config |

Modules: `tm_front_page`, `tm_data_table`, `tm_variable_browser`, `tm_missing_data`,
`tm_g_bivariate` (Medication Counts, Eligibility Deviations) and the custom `tm_g_spaghetti`
(Time Course) — the non-CDISC-safe subset of `teal.modules.general` plus our own modules.

## Run locally

```bash
bash run_app.sh          # installs packages, then launches at http://localhost:3838
```
or, in R:
```r
source("install_packages.R")
shiny::runApp()
```

Requires the DataBricks environment variables below in your `~/.Renviron`.

## Required environment variables

Set locally in `~/.Renviron`; on Posit Connect set them on the content (Content → Vars).
`.Renviron` is gitignored — never commit credentials.

| Variable | Purpose |
|----------|---------|
| `DATABRICKS_HOST` | DataBricks workspace host URL |
| `DATABRICKS_WAREHOUSE_ID` | SQL warehouse id used by the connection |
| `DATABRICKS_TOKEN` | PAT used by `brickster` unified auth (needed on Connect) |
| `PRAXFIVE` | Study-FIVE path prefix, e.g. `/Volumes/<catalog>/.../prax-five_` |

## Deploy to Posit Connect Cloud

1. Publish via **Posit Publisher** (IDE extension or `publisher deploy`) using
   `.posit/publish/app-emerald.toml`, to the same Connect Cloud account as `app-teal`.
2. In the Connect dashboard, set the four environment variables above on the deployed content.
3. Restart the content, then open the URL and confirm the app loads data and all modules render.

## Out of scope (future iterations)

More analytical modules, further domains, a SIX/FIVE study switcher, and snapshot
caching. See `~/.claude/plans/majestic-wondering-stallman.md`.
