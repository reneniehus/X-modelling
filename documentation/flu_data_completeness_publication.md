# Completeness and dynamics of European influenza indicator and vaccination data

## Abstract

We analysed cached/local influenza surveillance data for 25 countries and vaccination data for 30 European countries using the repository's model-input data structures. The analysis focuses on completed influenza seasons 2021/2022, 2022/2023, 2023/2024, 2024/2025 for weekly indicators and historical 65+ vaccination seasons available locally.

## Results

### Data completeness

Weekly indicator completeness differed more by indicator and country than by season. Combined influenza testing and positivity streams were comparatively complete, while ARI and several ILI+ streams showed substantial country-level gaps. Figure 1 displays these gaps directly, making missingness visible instead of allowing missing observations to be mistaken for low epidemic activity.

![Figure 1. Completeness of weekly influenza indicator data.](../figures/publication/fig01_indicator_completeness_heatmap.png)

### Vaccination coverage data

Historical vaccination records were more uneven over time than the main weekly testing streams. The 65+ coverage series provides the most comparable vaccination view across countries, while the all-group history remains heterogeneous in age-band definitions. Figure 2 therefore focuses on 65+ coverage availability and level.

![Figure 2. Historical influenza vaccination coverage in people aged 65+.](../figures/publication/fig02_vaccination_coverage_heatmap.png)

### Temporal dynamics

Scaled country-season trajectories show that flu timing and epidemic shape are not exchangeable across countries or seasons. Median peak timing was broadly mid-season, but the range of peak weeks was wide, especially for sparse ILI+ streams where missingness and reporting delays can move apparent peaks.

![Figure 3. Scaled seasonal dynamics for key indicators.](../figures/publication/fig03_scaled_indicator_dynamics.png)

### Between-country and between-season variation

Country-season intensity rankings varied across ILI consultation rates, combined positivity, and RespiCompass ILI+. This supports using indicator-specific quality diagnostics before interpreting cross-country differences as epidemiological differences.

![Figure 4. Country-season heterogeneity in burden and intensity.](../figures/publication/fig04_country_season_indicator_variation.png)

## Key findings and relevance

- ARI consultation rate: median country completeness 29% (range 0%-100%).
- ILI consultation rate: median country completeness 83% (range 12%-100%).
- ILI+ (ERVISS nonsentinel): median country completeness 61% (range 0%-100%).
- ILI+ (ERVISS sentinel): median country completeness 48% (range 0%-99%).
- ILI+ (RespiCompass): median country completeness 49% (range 0%-70%).
- Influenza positivity (combined): median country completeness 95% (range 56%-100%).
- Influenza tests (combined): median country completeness 100% (range 100%-100%).
- The five countries with the highest average multi-indicator completeness were SI (96%), CZ (91%), IE (84%), EE (83%), DK (80%).
- The five countries with the lowest average multi-indicator completeness were HU (30%), GR (35%), LU (39%), IT (47%), AT (48%).
- Historical 65+ vaccination coverage records were available for 30 countries and 266 country-seasons, with median coverage 40% and range 1%-78%.
- ILI consultation rate peaked at median season week 25 across country-seasons (range 7-41).
- ILI+ (RespiCompass) peaked at median season week 28 across country-seasons (range 1-44).
- Influenza positivity (combined) peaked at median season week 26 across country-seasons (range 1-48).
- Relevance: completeness varies materially by indicator and country, so model comparisons and visual interpretation should explicitly display missingness and avoid treating absent observations as epidemiological zeros.
- Relevance: country-season variation in peak timing and relative trajectory shape supports season-specific calibration and cautions against pooling countries without allowing heterogeneous temporal dynamics.

## Methods summary

- The script sources setup, settings, flu helper functions, local/offline data loading, and `gen_model_input()`.
- It uses `models_in$data_timeseries_long` as the canonical long-form data table and `models_in$data_season_summary` for season-level completeness and dynamics summaries.
- Weekly completeness is measured as the fraction of expected weekly rows with non-missing values in completed seasons. Vaccination availability is assessed from historical 65+ country-season coverage records.
- Figures are generated with reproducible R code and exported as 320 dpi PNG files suitable for manuscript review. They have passed internal consistency checks in this script, but should still receive domain-expert review before external publication.

## Limitations

- Completeness is measured at the data-table level and does not validate national reporting definitions, surveillance-system changes, or clinical comparability between countries.
- Historical vaccination age groups are heterogeneous outside the 65+ series, so cross-country interpretation should focus on comparable target groups unless additional harmonisation is performed.
- The latest configured season is excluded from the main weekly completeness analysis because it is not a completed season in the cached data context.

## Figures generated

- `figures/publication/fig01_indicator_completeness_heatmap.png`
- `figures/publication/fig02_vaccination_coverage_heatmap.png`
- `figures/publication/fig03_scaled_indicator_dynamics.png`
- `figures/publication/fig04_country_season_indicator_variation.png`

## Reproducibility

Run `Rscript --vanilla code/04_special_analyses/flu_data_publication_analysis.R` from the repository root. The script uses cached/local data (`new_from_online=FALSE`) and does not run Stan or fit models.
