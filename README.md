# X-modelling

A clone-and-go R template for standing up a respiratory-virus modelling project quickly —
public-health emergency or routine season. It ships a working data layer (ECDC ERVISS +
RespiCompass surveillance, contacts, vaccination, demography), tidy model-ready tables, a
data-quality / dynamics report, input-data validation, tests, and a pinned environment, so a
new project starts from a running pipeline rather than a blank repo.

## Quick start

```r
renv::restore()                       # install the pinned dependencies (see renv.lock)
source("code/00_main.R")              # run the pipeline end to end
```

`code/00_main.R` is the entry point. In order it:

1. loads settings (`code/02_settings/settings_version0.R` → `params`),
2. `load_data(params)` → the `data` list (raw, per-source streams),
3. `gen_model_input(params, data)` → `models_in` (canonical long / wide / season-summary tables),
4. `eyeballing(models_in, params, data)` → a figure manifest for the report,
5. `run_model(...)` → modelling scaffold to fill in per project.

Two flags control loading: `regenerate` (rebuild the `output/*.Rdata` caches) and
`new_from_online` (refetch from the internet vs. use the committed `data/` snapshots — the
snapshots let a fresh clone run fully offline).

## What you'll edit first

- **`code/02_settings/settings_version0.R`** — countries, season window, data round, report
  email. Copy to `settings_version1.R` to version a new configuration.
- **`code/01_main_supporting/gen_model_input.R`** — add extractors / `+`-indicators.
- **`code/01_main_supporting/run_model.R`** — wire in a model (parked `model_*.R` templates:
  SIR, ARIMA, last-year-burden).

## Tests

Lightweight contracts (`code/01_main_supporting/validate.R`) fail loudly if an upstream source
renames or drops a required column. Run the suite offline from the committed snapshots:

```r
Rscript run_tests.R
```

## Layout

```
code/00_main.R                 orchestrator (run this)
code/01_main_supporting/       setup, validate, load_data, gen_model_input, eyeballing,
                               run_model, process_and_save, send_report, model_* scaffolds
code/02_settings/              settings_version0.R (params)
code/03_report/                eyeballing_report.Rmd
data/                          committed raw snapshots (offline bootstrap)
output/                        cached data lists (gitignored, regenerated)
db/                            ECDC SQL client (dormant unless params$use_ecdc_db = TRUE)
tests/testthat/                contract + invariant tests
documentation/                 data_overview.md, quickstart.md
```

## Docs

- [`documentation/quickstart.md`](documentation/quickstart.md) — fuller getting-started guide.
- [`documentation/data_overview.md`](documentation/data_overview.md) — the data streams and tables.
- [`PROJECT_SCOPE.md`](PROJECT_SCOPE.md) — what's in scope and the production path.

## Reproducibility

`renv.lock` pins all dependencies; `renv::restore()` reproduces the environment. On Claude Code
web sessions a `SessionStart` hook installs system libraries and hydrates the renv library
offline (`.claude/hooks/session-start.sh`).
