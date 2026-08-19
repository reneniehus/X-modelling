# CLAUDE.md

Orientation for Claude Code sessions working in this repo. Everything here was verified
against the code; trust it over guesses, but re-verify before relying on line numbers.

## What this repo is

A clone-and-go R template for standing up a respiratory-virus modelling project:
real ECDC **ERVISS** + **RespiCompass** surveillance snapshots in `data/`, loaded and
standardised into canonical model-ready tables, with a data-quality ("eyeballing") report.
The **data layer is the durable core**; modelling is a deliberately empty scaffold
(`run_model()` is a stub — see PROJECT_SCOPE.md). Sibling repos: `flu-susceptible-fit`
(archived; grew out of this template), `pandemic_toolbook` (simulation + inference toolbox).

## Commands (always run from the repo root)

```bash
Rscript run_tests.R                      # test suite: ~30 s, 16 tests, fully offline
Rscript -e 'source("code/00_main.R")'    # whole pipeline: ~20 s from caches, offline
```

The trailing `Warning message: no DISPLAY variable so Tk is not available` on every run
is harmless (summarytools loads tcltk headless). Do not chase it.

## Environment / packages — IMPORTANT

- All required packages are **pre-installed in the system library**. The renv autoloader
  is disabled container-wide (`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`), so `.Rprofile`
  does nothing here. **Do NOT run `renv::restore()`** — unnecessary, and it hits the network.
  (The `renv::restore()` step in quickstart.md is for humans on their own machines.)
- Container R 4.3.3 exactly matches the renv.lock pin (138 packages).
- **Not installed** (deliberately slimmed from the lockfile): `rstan`, `cmdstanr`,
  `tidybayes`, `arrow`. The parked SIR scaffolds are therefore non-runnable as-is, and the
  `.stan` files they reference do not exist in the repo.
- `pandoc` and imagemagick are present (needed only for the report render).

## Pipeline map

`code/00_main.R` orchestrates: `setup.R` (libraries + helpers, see gotchas) →
`settings_version0.R` → `params` → `load_data(params, regenerate, new_from_online)` →
`gen_model_input(params, data)` → `models_in` → `run_model()` (empty stub) →
`eyeballing()` (figure manifest for the report).

`models_in` canonical tables: `data_timeseries_long` (single source of truth),
`data_timeseries_wide` (one column per stream__indicator__pathogen), `data_season_summary`
(per country × season, with completeness measures), `contacts` (Prem matrices collapsed
to 4 age groups). ILI+ (= ILI consultation rate × positivity) is built for Influenza,
SARS-CoV-2 and RSV.

### Flags that matter

- `regenerate` (arg at 00_main.R:21): `F` = reuse `output/*.Rdata` caches (short-circuits
  everything else); `T` = rebuild streams from snapshots.
- `new_from_online`: `T` = fetch from GitHub raw and refresh the committed `data/`
  snapshots; `F` = read snapshots. Only consulted when a rebuild actually runs.
  A fresh clone runs fully offline — every snapshot, including the RespiCompass
  helper/demography files, is committed in `data/`.
- `params$use_ecdc_db`: keep `FALSE` outside the ECDC internal network (routes demography
  to the dormant `db/` RODBC client).
- `params$respicompass_round`: hub round folder baked into RespiCompass URLs; bump per season.

## Data conventions

ISO2 codes in `country_short` (Greece = "GR"); weekly dates are ISO-week Wednesdays;
ages recoded to `age_00_04 / age_05_14 / age_15_64 / age_65_99 / age_total`; seasons run
Aug 1 → Jul 31, labeled `"2024/2025"`. `documentation/data_overview.md` tables every stream.

## Extension points (good places to build)

- **Wire a model**: the per-country loop in `run_model.R` (~line 19). Scaffold params like
  `params$SIR_simple`, `$load_earlyfit`, `$scenarios` do NOT exist in settings yet — add a
  settings block first.
- **Parked scaffolds** in `code/01_main_supporting/` — unpolished by design, known warts:
  `model_SIR_multiseason.R` (572 lines, most developed; age-structured, rstan::vb),
  `model_SIR_simple.R` / `model_SIR_simple_r0.R` (reference missing `stan/` files),
  `model_arima_simple.R` (live `browser()` at line 15), `model_last_year_burden.R`
  (real bug at line 40: `load(values_vec)` should be `log(values_vec)`).
- **New ERVISS stream**: one row in the `erviss_registry` tribble (load_data.R ~93–104),
  then a small extractor in `gen_model_input.R` bound into `make_data_timeseries_long()`.
- **Loaded but unexploited streams** (in `data$epi`, no extractor yet): sari_rates,
  typing_sari, flu_type_subtype, severity_nonsentinel, sequencing, variants.
- **Settings versioning**: copy `settings_version0.R` → `settings_version1.R`, repoint
  the source line at 00_main.R:8.

## Gotchas

- **Report render fails standalone**: `eyeballing_report.Rmd`'s setup chunk sources every
  helper except `validate.R`. Working invocation:
  `Rscript -e 'library(here); source(here("code/01_main_supporting/validate.R")); rmarkdown::render("code/03_report/eyeballing_report.Rmd")'`
  (~67 s, writes a ~13 MB gitignored HTML).
- Tests **write** to `output/` (they rebuild the epi cache) — expected, not a bug.
- `setup.R` rebinds globals: `ggplot()` is overridden to append a Dark2 colour scale
  (`eyeballing.R` calls `ggplot2::ggplot` to bypass it), ribbon/interval geoms get
  `alpha=0.4`, `mean_qi` gets `.width=0.80`; tidylog is loaded then detached keeping only
  `*_log` verbs.
- `transform_contracts()` (flu_functions.R ~306) is a typo'd name for the contact-matrix
  transform and relies on R's partial `$` matching internally — it works; don't rename it
  in only one place.
- `params$run_countries` and `params$simulation_seed` are declared but consumed nowhere.
- Some scaffolds read/write `../Big data/` outside the repo — leave that pattern alone
  unless asked.

## Git

Work on `main` unless told otherwise; remote is `origin` →
`https://github.com/reneniehus/respi_starter`. Stage with `git add -A` and verify with
`git status --short` before committing (renamed files stage silently; edited ones do not).
