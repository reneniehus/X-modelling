# Project Scope (Active Production Path)

This repository's primary purpose is to ...

## Active production path

The active, supported production path is:

1. `code/00_main.R` (entrypoint)
2. `code/02_settings/settings_version0.R` (scenario and runtime settings)
3. `code/01_main_supporting/load_flu_data.R` (data loading and caching)
4. `code/01_main_supporting/run_flu_models.R` (model orchestration)
5. `code/01_main_supporting/model_SIR_multiseason.R` (SIR multi-season fit/projection)
6. `code/01_main_supporting/process_and_save.R` (post-processing and outputs)

## In scope

- 1
- 2

## Out of scope (for production)

- 1
- 2

## Legacy and exploratory code

...
