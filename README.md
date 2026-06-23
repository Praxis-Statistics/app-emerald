# app-emerald

Exploratory **teal** app for **non-CDISC EDC data**. A simple data viewer over **DM, AE, VS,
EG (ECG), EX (Study Drug Administration)** plus each **lab panel as its own dataset** — pulled
**live from DataBricks** (study **FIVE**) and deployed to **Posit Connect Cloud**.

`EX` is a single file; like the lab datasets its mixed numeric/text columns are split into
`<col>_num` / `<col>_char` via `split_mixed_columns()`.

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
| `install_packages.R` / `PACKAGES.txt` | package install helper / list |
| `run_app.sh` | install deps + launch locally |
| `.posit/publish/app-emerald.toml` | Posit Publisher deployment config |

Modules: `tm_front_page`, `tm_data_table`, `tm_variable_browser`, `tm_missing_data`
(the non-CDISC-safe subset of `teal.modules.general`).

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

More analytical modules, additional domains (IE/etc.), a SIX/FIVE study switcher, and snapshot
caching. See `~/.claude/plans/majestic-wondering-stallman.md`.
