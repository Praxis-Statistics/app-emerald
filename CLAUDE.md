# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`app-emerald` is a `teal` (R/Shiny) data-viewer app for **non-CDISC EDC data**, study **FIVE**, pulled **live from DataBricks** and deployed to **Posit Connect Cloud**. There is no local data and no database fixture — every run hits DataBricks at startup. See `README.md` for the domain/lab-dataset reference tables.

## Commands

```bash
bash run_app.sh                      # install packages, then launch at http://localhost:3838
Rscript install_packages.R           # install deps only (idempotent)
Rscript -e "shiny::runApp()"         # launch (deps already installed)
```

There is **no test suite, linter, or build step** — it's a single Shiny app. "Running" it *is* the verification. The app loads data on launch, so it will fail immediately if DataBricks env vars or connectivity are wrong.

Interactive discovery helper (run in an R session with env vars set):
```r
source("R/data_databricks.R"); profile_lb_datasets(connect_databricks())  # list live lb* files: name, Form, dims
```

## Required environment

The app cannot start without these in `~/.Renviron` (locally) or the Connect content's Vars (deployed). `.Renviron` is gitignored.

- `DATABRICKS_HOST`, `DATABRICKS_WAREHOUSE_ID`, `DATABRICKS_TOKEN` — `brickster` + `DBI` auth
- `PRAXFIVE` — study-FIVE path prefix, e.g. `/Volumes/<catalog>/.../prax-five_` (or `STUDY_PREFIX`, which takes precedence)

## Architecture

Data flows in one direction at startup: **DataBricks CSVs → named list of data.frames → `teal_data()` container → modules.**

- **`R/data_databricks.R`** — `load_emerald_data()` is the single entry point. Opens one DBI connection, reads each domain CSV via the DataBricks `read_files()` SQL function (`read_study_csv()`), and returns a **named list**. Core domains: `DM, AE, VS, EG, EX, CM, CM_COUNTS, IE, IE_COUNTS`. Lab datasets are appended from `load_lb_datasets()`.
- **`app.R`** — entry point. Calls `load_emerald_data()` once, then builds the `teal_data` container *dynamically* with `do.call(teal_data, raw)` because the dataset names aren't known until the live read (lab files vary). Join keys are wired so the filter panel propagates `SubjectID` selections across domains: `DM` is the 1-row-per-subject primary; every other domain that *has* a `SubjectID` column is joined to it.
- **`R/lb_datasets.R`** — study FIVE splits labs across per-panel files (`lb1`, `lb4`, …); each becomes its **own** named dataset via the `LB_DATASETS` map (file stem → short name + label). Files not in the map still load under their upper-cased stem. Name collisions are de-duped with a numeric suffix. Loader is tolerant of missing files (`tryCatch` → skip).
- **`R/cm_counts.R`** — CM-specific count support (see below).
- **`R/ie_counts.R`** — IE-specific count support (see below).
- **`R/ie_criteria.R`** — `IE_CRITERIA` lookup table: maps each cryptic IE code (`IEITST*`/`IEETST*`) to category, item tag, short label and full protocol wording. Loaded as its own unlinked reference dataset, used to produce the readable `CriterionLabel` on `IE_COUNTS`, and rendered as a static HTML table (`ie_criteria_html()`) below the Eligibility Deviations plot via that module's `post_output`. `IEITST9` is unmapped (no protocol text supplied) — flagged in the table, do not silently invent wording for it.
- **`R/timecourse.R`** — `build_timecourse()` stacks the **visit-based** domains into one tidy long `TIMECOURSE` table (`SubjectID, Dataset, Test, Visit, Date, Value, Unit`) for the spaghetti viewer (see below). `tm_g_spaghetti()` is the custom module that plots it.

### Two recurring conventions to know

1. **`split_mixed_columns()`** (in `R/lb_datasets.R`) is applied to lab files, `EX`, and `CM`. For any column that *genuinely mixes* numbers and text, it adds `<col>_num` (numeric) and `<col>_char` (text) helper columns, leaving the original intact. Purely-numeric or purely-text columns are untouched. This lets a numeric finding be browsed as a distribution while text findings stay separate. If you add a new domain with mixed result columns, pass it through this.

2. **Some count datasets are derived, not raw — keep the full domain too.** Two follow this pattern:
   - **`CM_COUNTS`** — `build_cm_subject_counts()` dedupes `CM` to one row per `(SubjectID, CMTRT_PREFERRED)` so the **Medication Counts** `tm_g_bivariate` (medication on x, y empty) charts *distinct subjects per medication*, not raw record counts. `CMTRT_PREFERRED` is the WHO Drug standardized name (collapses trade-name variants). The "Top N" slider is a `teal_transform_module` (`cm_top_n_transform()`) whose trim runs inside `within(data(), ...)` so it stays in teal's reproducible "Show R code".
   - **`IE_COUNTS`** — `build_ie_deviation_counts()` reshapes the **wide** `IE` form (one row/subject, a Yes/No column per criterion) to **long**: one row per `(SubjectID, Criterion)` carrying a *deviation*. A deviation is an inclusion criterion (`IEITST*`) answered `"No"` **or** an exclusion criterion (`IEETST*`/`IEETT8II`) answered `"Yes"` — note the flag value differs by category. The **Eligibility Deviations** `tm_g_bivariate` charts distinct subjects per criterion on the readable `CriterionLabel` axis (decoded via `IE_CRITERIA`), `fill = Category` (requires `color_settings = TRUE`). Both `Criterion` (code) and `CriterionLabel` are factors pre-ordered by count so the busiest bars lead; no Top N needed (~21 criteria, sparse).

   In both cases the full verbatim domain (`CM`, `IE`) stays browsable separately, and the derived `*_COUNTS` dataset carries a `SubjectID` so the startup join-key loop links it to `DM`.

   - **`TIMECOURSE`** — `build_timecourse()` (`R/timecourse.R`) harmonises the visit-based domains, which store measurements in *incompatible shapes*, into one tidy long table: `VS/EG/EX` are **wide** (a column per parameter — `SYSBP`, `EGQTCB`, `EXDOSE`, …) while the lab panels are **long** (a `TEST`-name column + a result column — e.g. `CHEM`'s `CHMTST`/`CHMRSLT`). A per-dataset spec (`.TIMECOURSE_SPEC`) maps each into rows of `SubjectID, Dataset, Test, Visit, Date, Value, Unit`. Only **numeric** results are kept (a spaghetti plot needs a numeric Y; uses the `<col>_num` helper from `split_mixed_columns()` when present), so qualitative panels (`PREG`, `DRUG`) and text-result panels (`CENTLAB`, `UR`, `VIR`) naturally drop out. `Visit` is a factor ordered by median date. `Date` is parsed from the EDC `%d-%b-%Y` strings (`.tc_date()` tries several formats, leaves unparseable as `NA`). `TIMECOURSE` carries `SubjectID` so the join loop links it to `DM`.

### Module set

The non-CDISC-safe subset of `teal.modules.general` — `tm_front_page`, `tm_data_table`, `tm_variable_browser`, `tm_missing_data` — plus three custom modules: two `tm_g_bivariate` charts (Medication Counts, Eligibility Deviations) and **`tm_g_spaghetti()`** (`R/timecourse.R`), a hand-written `teal::module()` line-per-subject viewer over `TIMECOURSE`. It has Dataset + Test dropdowns driving a single pane (no faceting), an X-axis toggle (Date = true elapsed time, default; Visit = aligned/ordered), an adaptive overlay (loess on Date, mean-per-visit on Visit) and a log-Y option. Because the visit labels include many per-subject `"Unscheduled Visit (date)"` entries (~46 levels), **Date is the meaningful default axis**; Visit alignment is offered but cluttered. The data is not CDISC, so CDISC-specific modules are intentionally excluded.

  `tm_g_spaghetti()` reads `data()[["TIMECOURSE"]]` directly inside its server (teal 1.x passes `data` as a `reactive(teal_data)`); unlike the `tm_g_bivariate` modules it does **not** populate teal's "Show R code" — acceptable for an exploratory plot. It renders with **plotly** (`ggplotly(p, tooltip = "text")`) so each point shows a `Subject / Visit / value / date` hover tooltip — the hover text is built into a `.tip` column carried on a `text` aesthetic on the points layer. This is why the app depends on `plotly` (in `PACKAGES.txt` / `install_packages.R`); the Visit-mean overlay is **pre-aggregated** (not `stat_summary`) so it translates cleanly through `ggplotly`.

## Study FIVE vs SIX gotcha

This app targets study **FIVE**, which stores some domains as single files where study SIX splits them — notably `EG` (ECG) is one file here (SIX splits to `eg1/eg2/eg3`). A FIVE/SIX switcher is explicitly out of scope (see README).

## Deploy

Posit Publisher → Connect Cloud, config in `.posit/publish/`. After publishing, set the four DataBricks env vars on the content and restart. Confirm the app loads data and all modules render.
