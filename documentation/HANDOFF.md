# X-modelling — handoff briefing

> Snapshot for picking up work in a fresh (R-enabled) session. Reflects the state of `main` after the data-loader refactor (PR #3, merged). The repo is mid **"de-flu-ification"**: turning a working flu-specific project into a generic, clone-and-go template.

## 1. Purpose
R pipeline for **respiratory-virus (currently influenza) surveillance modelling** in EU/EEA countries. It pulls weekly ECDC + RespiCompass data, fits a **multi-season SIR** model per country/season, and produces **RespiCompass-style projections + an emailed report**. The working heart is **load data → build `models_in`**; modelling and reporting are to become ready-but-empty scaffolds.

## 2. How you interact with it
Entry point **`code/00_main.R`**, run top to bottom:
```r
gc()
source("code/01_main_supporting/setup.R")                 # libraries + helpers (e.g. EU_short)
source("code/02_settings/settings_version0.R"); params=settings()
source(... flu_functions.R, load_data.R, gen_model_input.R, run_model.R, process_and_save.R, send_report.R)
data      = load_data(params, regenerate=F, new_from_online=F)
models_in = gen_model_input(params, data)
models_out= run_model(params, data, models_in)
eyeballing(models_in, params, data)                        # quick visual sanity check
```
**Two flags drive everything:**
- `regenerate` — `F` reuses cached `output/*.Rdata`; `T` rebuilds them.
- `new_from_online` — `T` fetches from the internet and refreshes local snapshots; `F` reads local snapshots (now **self-bootstrapping**: fetches any missing snapshot automatically).

**Key settings** (`settings_version0.R` → `params`): `run_countries = IT,AT,BE,BG,HR`; `four_age_groups = 0-4,5-14,15-64,65+`; `latest_start_year=2025`; season = Aug 1 → Jul 31; `Rnull=1.5`; `rapid_stan_fit=T`; `send_report=T`.

## 3. Layout (what matters)
- `code/00_main.R` — orchestrator.
- `code/01_main_supporting/` — `load_data.R`, `gen_model_input.R`, `flu_functions.R` (big helper file: canonical-table builders, `data_into_all_season`, `eyeballing`, contacts), `run_model.R`, `model_SIR_multiseason.R` (the production model), `setup.R`/`setup_clean.R`, `send_report.R`.
- `data/`, `output/` (cached `.Rdata` + snapshots), `stan/`, `db/` (ECDC SQL access).
- **Legacy/parking:** `old code/` (288 files), `code/06_sandbox/`, `code/04_special_analyses/` — slated for removal/trimming, not production.

## 4. Data layer
**`data$...`** = `epi`, `vax`, `contact` (Prem matrices), `helpers_respicompass`, `demography_ECDC` (needs ECDC SQL DB — only inside ECDC network), `demography_respicast`.

**`load_data_epi()` now loads all 9 ERVISS CSVs via a `tribble` registry** (add a row → new stream). Keys under `data$epi$`:

| key | file | schema |
|---|---|---|
| `erviss_ili_ari` | ILIARIRates.csv | rates |
| `erviss_sari_rates` | SARIRates.csv | rates |
| `erviss_typing_sentinel` | sentinelTestsDetectionsPositivity.csv | detailed |
| `erviss_typing_nonsentinel` | nonSentinelTestsDetections.csv | detailed |
| `erviss_typing_sari` | SARITestsDetectionsPositivity.csv | detailed |
| `erviss_flu_type_subtype` | activityFluTypeSubtype.csv | detailed |
| `erviss_severity_nonsentinel` | nonSentinelSeverity.csv | detailed |
| `erviss_sequencing` | sequencingVolumeDetectablePrevalence.csv | detailed |
| `erviss_variants` | variants.csv | detailed |

Plus `respicompass_iliplus`. Shared helpers `recode_age()` + `standardise_erviss()` (adds ISO-week `date`, recodes age, adds `country_short`; `rates` = slim, `detailed` = keep all pathogen/variant/datasource cols).

**`gen_model_input()` → `models_in`:** `data_all_season` (intermediate), `data_timeseries_long`, `data_season_summary`, `contacts`. Decision made: **drop `data_all_season` from the output** (keep the other three); candidate new frames to consider: `data_latest`, `data_wide`, `data_availability`.

## 5. Current state
- PR #3 **merged** to `main` (`a059873`); development continues on branch `claude/epic-knuth-16o2d`.
- The loader rewrite is committed but was **never executed** (the session that wrote it had no R available) — see §6.

## 6. What's important ⚠️
1. **Verify the rewrite runs** — first thing in the R session: `data = load_data(params, regenerate=T, new_from_online=T)`, confirm all 9 `data$epi$erviss_*` load and `standardise_erviss` handles each schema; then re-run `gen_model_input` + `eyeballing` to confirm nothing downstream broke. Downstream depends on the preserved names/schemas `erviss_ili_ari` (slim) and `erviss_typing_sentinel/nonsentinel` (full).
2. **Stale cache:** `output/epi.Rdata` is git-tracked and holds the OLD 4-element list. With the default `regenerate=F`, you **won't see the 6 new datasets** — run `regenerate=T` once. Consider untracking `output/*.Rdata` (build artifacts).
3. New snapshots aren't on disk yet → first run needs `new_from_online=T` (or self-bootstrap fetches them).
4. `case_when(.default=)` needs dplyr ≥ 1.1.0 (fine — repo already uses `join_by`).
5. **Stale docs:** `PROJECT_SCOPE.md` / `PRODUCTION_CONTRACT.md` are stubs and still name `load_flu_data.R` / `run_flu_models.R` — update to `load_data.R` / `run_model.R`.
6. **Open decision (undecided):** where/how to host an ERVISS indicator catalogue (indicator × disease × completeness × notes). Recommended: a `documentation/erviss_indicators.csv` that **doubles as the loader's registry** so code + catalogue can't drift; alternatives are a markdown-only doc, or both.
7. **De-flu cleanup roadmap:** remove `old code/`, `06_sandbox/`, unused stan, extra model variants; make db + email optional; merge `setup.R`/`setup_clean.R`; split `flu_functions.R`; scaffold empty modelling + reporting stubs wired into `00_main.R`.
