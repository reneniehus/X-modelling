# Quickstart — kicking off a project

A clone-and-go template for loading ERVISS / RespiCompass respiratory-surveillance data
(plus contact, vaccine and demography data) and turning it into tidy, model-ready tables
with a quality/dynamics report. See `data_overview.md` for what data is available.

## 1. Prerequisites
- **R 4.3+** (the renv lockfile pins R 4.3.3 and 164 packages).
- System libraries for two optional features: **pandoc** (to render the HTML report) and
  **libmagick++** (pulled in by `summarytools`). On Debian/Ubuntu:
  `apt-get install pandoc libmagick++-dev`.

## 2. Install dependencies
Open the project (`respi_starter.Rproj`) and restore the pinned package versions:
```r
renv::restore()
```

## 3. Run the pipeline
Open `code/00_main.R` and run it top to bottom. In order it:
1. sources `setup.R` (libraries + helpers) and `settings_version0.R` (`params`),
2. `load_data(params, regenerate, new_from_online)` -> the `data` list,
3. `gen_model_input(params, data)` -> `models_in` (long / wide / season-summary / contacts),
4. `eyeballing(models_in, params, data)` -> a figure manifest for the report.

Two flags drive data loading:
- `regenerate` — `F` reuse cached `output/*.Rdata`; `T` rebuild them.
- `new_from_online` — `T` fetch from the internet and refresh the local `data/` snapshots;
  `F` use the snapshots (self-bootstrapping: fetches anything missing). First offline run
  works because the snapshots are committed.

## 4. Change what it does — settings
Edit `code/02_settings/settings_version0.R` (the `params` list). Common knobs:
- `run_countries` — countries to focus on.
- `season_start_monthday` / `season_end_monthday`, `latest_start_year` — season window.
- `respicompass_round` — RespiCompass hub round folder (bump for a new season).
- `use_ecdc_db` — `TRUE` (only inside the ECDC network) to pull demography live from the
  ECDC SQL database instead of the committed snapshot.

To version a different configuration, copy the file to `settings_version1.R` and source that.

## 5. The eyeballing report
Render the large-format quality + dynamics HTML report:
```r
rmarkdown::render("code/03_report/eyeballing_report.Rmd")
```
Figures and their narrative bullets are defined in `code/01_main_supporting/eyeballing.R`
(edit the bullet placeholders to match what you see). The rendered `.html` is gitignored.

## 6. Add a new data stream
- **Another ERVISS file:** add one row to the `erviss_registry` tribble in `load_data.R`
  (name, file, snapshot, schema). The loop and standardisation handle the rest.
- **A non-ERVISS source:** write a `load_data_<x>()` builder following the existing pattern
  (uses `load_or_build()` for caching) and call it from the `load_data()` mother function.
- To surface it in `models_in`, add a small extractor in `gen_model_input.R` and bind it into
  `make_data_timeseries_long()`.

## 7. Tests / shielding from upstream changes
Lightweight contracts in `code/01_main_supporting/validate.R` fail loudly if ECDC renames or
drops a required column / stream. Run the suite (offline, from the committed snapshots):
```r
Rscript run_tests.R        # or: testthat::test_dir("tests/testthat")
```
It checks the data contracts, the canonical tables, and the key invariant
(`ILI+ == ILI × positivity`, and agreement with the RespiCompass ILI+).

## 8. Modelling (lightweight scaffold)
`run_model.R` is an intentionally empty orchestration stub; `model_*.R` in
`code/01_main_supporting/` are parked single-model templates (SIR, ARIMA, last-year-burden)
to graduate into production when a project needs them. `db/` holds the ECDC SQL client
(kept dormant). The contact-matrix transform lives in `flu_functions.R`.

## Layout
```
code/00_main.R                 orchestrator (run this)
code/01_main_supporting/       setup, validate, load_data, gen_model_input, eyeballing,
                               run_model, process_and_save, send_report, model_* scaffolds
code/02_settings/              settings_version0.R (params)
code/03_report/                eyeballing_report.Rmd
data/                          committed raw snapshots (offline bootstrap)
output/                        cached data lists (gitignored, regenerated)
db/                            ECDC SQL client (dormant)
tests/testthat/                contract + invariant tests
documentation/                 data_overview.md, quickstart.md
```
