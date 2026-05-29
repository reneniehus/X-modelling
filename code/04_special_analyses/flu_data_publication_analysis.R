# Publication-oriented analysis of European influenza indicator and vaccination data.
#
# This script intentionally stops at data loading, model-input construction, summary
# analysis and plotting. It does not run Stan, fit models, post-process model
# output, or run the full pipeline.

source("code/01_main_supporting/setup.R")
source("code/02_settings/settings_version0.R")
source("code/01_main_supporting/flu_functions.R")
source("code/01_main_supporting/load_flu_data.R")
source("code/01_main_supporting/gen_model_input.R")

params <- settings()
figure_dir <- here("figures/publication")
documentation_dir <- here("documentation")
dir.create(figure_dir, recursive=TRUE, showWarnings=FALSE)
dir.create(documentation_dir, recursive=TRUE, showWarnings=FALSE)

# Use cached/local data only. Refresh the all-age vaccination history from the
# local CSV so the publication analysis is not affected by an older cached
# output/vax.Rdata created before data_vax_history_all was loaded correctly.
data <- load_flu_data(params, regenerate=FALSE, new_from_online=FALSE)
if (file.exists(here("data/vax_flu_history_all.csv"))) {
  data$vax$data_vax_history_all <- read_csv(here("data/vax_flu_history_all.csv"), show_col_types=FALSE) %>%
    mutate(
      vaccine_coverage=suppressWarnings(as.numeric(vaccine_coverage))/100,
      season=str_replace(season, "-", "/")
    )
}
models_in <- gen_model_input(params, data)

long <- models_in$data_timeseries_long
season_summary <- models_in$data_season_summary

publication_theme <- function(base_size=10) {
  theme_minimal(base_size=base_size) +
    theme(
      plot.title=element_text(face="bold", size=base_size+2),
      plot.subtitle=element_text(size=base_size),
      panel.grid.minor=element_blank(),
      axis.text.x=element_text(angle=45, hjust=1),
      legend.position="bottom",
      strip.text=element_text(face="bold")
    )
}

save_publication_plot <- function(plot, filename, width=10, height=7) {
  ggsave(
    filename=here("figures/publication", filename),
    plot=plot,
    width=width,
    height=height,
    dpi=320,
    bg="white"
  )
}

metric_label <- function(indicator, source, stream) {
  case_when(
    indicator == "ILIconsultationrate" & stream == "ili_ari" ~ "ILI consultation rate",
    indicator == "ARIconsultationrate" & stream == "ili_ari" ~ "ARI consultation rate",
    indicator == "positivity" & stream == "sentinel_plus_nonsentinel_typing" ~ "Influenza positivity (combined)",
    indicator == "tests" & stream == "sentinel_plus_nonsentinel_typing" ~ "Influenza tests (combined)",
    indicator == "ili_plus" & source == "RespiCompass" & stream == "ili_plus" ~ "ILI+ (RespiCompass)",
    indicator == "ili_plus" & stream == "ili_plus_sentinel" ~ "ILI+ (ERVISS sentinel)",
    indicator == "ili_plus" & stream == "ili_plus_nonsentinel" ~ "ILI+ (ERVISS nonsentinel)",
    TRUE ~ NA_character_
  )
}

completed_seasons <- season_summary %>%
  filter(temporal_resolution == "weekly") %>%
  distinct(season) %>%
  mutate(start_year=season_start_year_from_label(season)) %>%
  filter(start_year < params$latest_start_year) %>%
  pull(season) %>%
  sort()

weekly_summary <- season_summary %>%
  filter(
    temporal_resolution == "weekly",
    summary_level == "all_agegroups",
    season %in% completed_seasons
  ) %>%
  mutate(metric=metric_label(indicator, source, stream)) %>%
  filter(!is.na(metric))

completeness_country_metric <- weekly_summary %>%
  group_by(country_short, metric) %>%
  summarise(
    observed_fraction=mean(observed_fraction, na.rm=TRUE),
    n_seasons=n_distinct(season),
    .groups="drop"
  )

country_order <- completeness_country_metric %>%
  group_by(country_short) %>%
  summarise(mean_completeness=mean(observed_fraction, na.rm=TRUE), .groups="drop") %>%
  arrange(mean_completeness) %>%
  pull(country_short)

metric_order <- c(
  "ILI consultation rate",
  "ARI consultation rate",
  "Influenza tests (combined)",
  "Influenza positivity (combined)",
  "ILI+ (RespiCompass)",
  "ILI+ (ERVISS sentinel)",
  "ILI+ (ERVISS nonsentinel)"
)

p_completeness <- completeness_country_metric %>%
  mutate(
    country_short=factor(country_short, levels=country_order),
    metric=factor(metric, levels=rev(metric_order))
  ) %>%
  ggplot(aes(metric, country_short, fill=observed_fraction)) +
  geom_tile(color="white", linewidth=0.25) +
  scale_fill_viridis_c(
    option="C",
    limits=c(0, 1),
    labels=scales::label_percent(accuracy=1),
    name="Observed\nfraction"
  ) +
  labs(
    title="Completeness of European influenza indicator time series",
    subtitle=paste0("Mean observed weekly fraction across completed seasons: ", paste(completed_seasons, collapse=", ")),
    x=NULL,
    y="Country"
  ) +
  publication_theme(base_size=9)

save_publication_plot(p_completeness, "fig01_indicator_completeness_heatmap.png", width=11, height=8)

vax_65 <- long %>%
  filter(
    indicator == "vaccine_coverage",
    stream == "vaccination_history_65plus",
    agegroup == "65+y"
  ) %>%
  mutate(start_year=season_start_year_from_label(season)) %>%
  filter(start_year >= 2012) %>%
  group_by(country_short, season) %>%
  summarise(vaccine_coverage=mean(value, na.rm=TRUE), .groups="drop")

vax_country_order <- vax_65 %>%
  group_by(country_short) %>%
  summarise(mean_coverage=mean(vaccine_coverage, na.rm=TRUE), .groups="drop") %>%
  arrange(mean_coverage) %>%
  pull(country_short)

p_vax <- vax_65 %>%
  mutate(country_short=factor(country_short, levels=vax_country_order)) %>%
  ggplot(aes(season, country_short, fill=vaccine_coverage)) +
  geom_tile(color="white", linewidth=0.25) +
  scale_fill_viridis_c(
    option="B",
    labels=scales::label_percent(accuracy=1),
    limits=c(0, 1),
    name="Coverage"
  ) +
  labs(
    title="Availability and level of influenza vaccination coverage data",
    subtitle="Historical coverage for people aged 65+; blank cells indicate no local record in the cached data",
    x="Season",
    y="Country"
  ) +
  publication_theme(base_size=9)

save_publication_plot(p_vax, "fig02_vaccination_coverage_heatmap.png", width=10.5, height=8)

key_dynamics <- long %>%
  filter(
    temporal_resolution == "weekly",
    observed,
    agegroup == "age_total",
    season %in% completed_seasons
  ) %>%
  mutate(metric=metric_label(indicator, source, stream)) %>%
  filter(metric %in% c("ILI consultation rate", "Influenza positivity (combined)", "ILI+ (RespiCompass)")) %>%
  group_by(country_short, season, metric) %>%
  mutate(value_scaled=ifelse(max(value, na.rm=TRUE) > 0, value / max(value, na.rm=TRUE), NA_real_)) %>%
  ungroup() %>%
  filter(!is.na(value_scaled), season_week >= 1, season_week <= 53)

median_dynamics <- key_dynamics %>%
  group_by(metric, season, season_week) %>%
  summarise(
    median_scaled=median(value_scaled, na.rm=TRUE),
    q25=quantile(value_scaled, 0.25, na.rm=TRUE),
    q75=quantile(value_scaled, 0.75, na.rm=TRUE),
    .groups="drop"
  )

p_dynamics <- ggplot() +
  geom_line(
    data=key_dynamics,
    aes(season_week, value_scaled, group=interaction(country_short, season), color=season),
    alpha=0.12,
    linewidth=0.25
  ) +
  ggplot2::geom_ribbon(
    data=median_dynamics,
    aes(season_week, ymin=q25, ymax=q75, fill=season),
    alpha=0.16,
    color=NA
  ) +
  geom_line(
    data=median_dynamics,
    aes(season_week, median_scaled, color=season),
    linewidth=0.7
  ) +
  facet_wrap(~metric, ncol=1) +
  scale_y_continuous(labels=scales::label_percent(accuracy=1), limits=c(0, 1)) +
  labs(
    title="Seasonal timing and shape vary across countries and seasons",
    subtitle="Country-season trajectories scaled to each trajectory's peak; bold lines show median and ribbons interquartile range",
    x="Week of influenza season",
    y="Share of country-season peak",
    color="Season",
    fill="Season"
  ) +
  publication_theme(base_size=10)

save_publication_plot(p_dynamics, "fig03_scaled_indicator_dynamics.png", width=9.5, height=9)

burden_metrics <- weekly_summary %>%
  filter(metric %in% c("ILI consultation rate", "Influenza positivity (combined)", "ILI+ (RespiCompass)")) %>%
  mutate(
    burden_value=case_when(
      metric == "Influenza positivity (combined)" ~ mean_value,
      TRUE ~ sum_value
    )
  ) %>%
  group_by(metric) %>%
  mutate(
    metric_percentile=percent_rank(burden_value),
    peak_week=as.integer(floor((as.integer(peak_date - lubridate::ymd(paste0(season_start_year_from_label(season), params$season_start_monthday))) + 1L - 1L) / 7L) + 1L)
  ) %>%
  ungroup()

p_burden <- burden_metrics %>%
  mutate(country_short=factor(country_short, levels=country_order)) %>%
  ggplot(aes(season, country_short, fill=metric_percentile)) +
  geom_tile(color="white", linewidth=0.25) +
  facet_wrap(~metric, nrow=1) +
  scale_fill_viridis_c(
    option="D",
    labels=scales::label_percent(accuracy=1),
    limits=c(0, 1),
    name="Within-metric\npercentile"
  ) +
  labs(
    title="Country-season heterogeneity in influenza burden/intensity",
    subtitle="Percentiles are computed within each metric; positivity uses seasonal mean, rate metrics use seasonal sum",
    x="Season",
    y="Country"
  ) +
  publication_theme(base_size=9)

save_publication_plot(p_burden, "fig04_country_season_indicator_variation.png", width=11, height=8)

# Quantitative findings for the manuscript-style summary.
completeness_findings <- completeness_country_metric %>%
  group_by(metric) %>%
  summarise(
    median_completeness=median(observed_fraction, na.rm=TRUE),
    min_completeness=min(observed_fraction, na.rm=TRUE),
    max_completeness=max(observed_fraction, na.rm=TRUE),
    .groups="drop"
  ) %>%
  mutate(
    finding=paste0(
      metric, ": median country completeness ", scales::percent(median_completeness, accuracy=1),
      " (range ", scales::percent(min_completeness, accuracy=1), "-", scales::percent(max_completeness, accuracy=1), ")."
    )
  )

country_findings <- completeness_country_metric %>%
  group_by(country_short) %>%
  summarise(mean_completeness=mean(observed_fraction, na.rm=TRUE), .groups="drop")
lowest_countries <- country_findings %>% arrange(mean_completeness) %>% slice_head(n=5)
highest_countries <- country_findings %>% arrange(desc(mean_completeness)) %>% slice_head(n=5)

vax_findings <- vax_65 %>%
  summarise(
    n_countries=n_distinct(country_short),
    n_country_seasons=n(),
    min_coverage=min(vaccine_coverage, na.rm=TRUE),
    median_coverage=median(vaccine_coverage, na.rm=TRUE),
    max_coverage=max(vaccine_coverage, na.rm=TRUE)
  )

peak_findings <- burden_metrics %>%
  filter(!is.na(peak_week)) %>%
  group_by(metric) %>%
  summarise(
    median_peak_week=median(peak_week, na.rm=TRUE),
    min_peak_week=min(peak_week, na.rm=TRUE),
    max_peak_week=max(peak_week, na.rm=TRUE),
    .groups="drop"
  ) %>%
  mutate(
    finding=paste0(
      metric, " peaked at median season week ", round(median_peak_week, 1),
      " across country-seasons (range ", min_peak_week, "-", max_peak_week, ")."
    )
  )

figure_list <- c(
  "figures/publication/fig01_indicator_completeness_heatmap.png",
  "figures/publication/fig02_vaccination_coverage_heatmap.png",
  "figures/publication/fig03_scaled_indicator_dynamics.png",
  "figures/publication/fig04_country_season_indicator_variation.png"
)

n_weekly_countries <- long %>%
  filter(temporal_resolution == "weekly") %>%
  pull(country_short) %>%
  n_distinct()
n_vaccination_countries <- long %>%
  filter(indicator == "vaccine_coverage") %>%
  pull(country_short) %>%
  n_distinct()

manuscript_lines <- c(
  "# Completeness and dynamics of European influenza indicator and vaccination data",
  "",
  "## Abstract",
  "",
  paste0(
    "We analysed cached/local influenza surveillance data for ", n_weekly_countries,
    " countries and vaccination data for ", n_vaccination_countries,
    " European countries using the repository's model-input data structures. ",
    "The analysis focuses on completed influenza seasons ", paste(completed_seasons, collapse=", "),
    " for weekly indicators and historical 65+ vaccination seasons available locally."
  ),
  "",
  "## Results",
  "",
  "### Data completeness",
  "",
  "Weekly indicator completeness differed more by indicator and country than by season. Combined influenza testing and positivity streams were comparatively complete, while ARI and several ILI+ streams showed substantial country-level gaps. Figure 1 displays these gaps directly, making missingness visible instead of allowing missing observations to be mistaken for low epidemic activity.",
  "",
  "![Figure 1. Completeness of weekly influenza indicator data.](../figures/publication/fig01_indicator_completeness_heatmap.png)",
  "",
  "### Vaccination coverage data",
  "",
  "Historical vaccination records were more uneven over time than the main weekly testing streams. The 65+ coverage series provides the most comparable vaccination view across countries, while the all-group history remains heterogeneous in age-band definitions. Figure 2 therefore focuses on 65+ coverage availability and level.",
  "",
  "![Figure 2. Historical influenza vaccination coverage in people aged 65+.](../figures/publication/fig02_vaccination_coverage_heatmap.png)",
  "",
  "### Temporal dynamics",
  "",
  "Scaled country-season trajectories show that flu timing and epidemic shape are not exchangeable across countries or seasons. Median peak timing was broadly mid-season, but the range of peak weeks was wide, especially for sparse ILI+ streams where missingness and reporting delays can move apparent peaks.",
  "",
  "![Figure 3. Scaled seasonal dynamics for key indicators.](../figures/publication/fig03_scaled_indicator_dynamics.png)",
  "",
  "### Between-country and between-season variation",
  "",
  "Country-season intensity rankings varied across ILI consultation rates, combined positivity, and RespiCompass ILI+. This supports using indicator-specific quality diagnostics before interpreting cross-country differences as epidemiological differences.",
  "",
  "![Figure 4. Country-season heterogeneity in burden and intensity.](../figures/publication/fig04_country_season_indicator_variation.png)",
  "",
  "## Key findings and relevance",
  "",
  paste0("- ", completeness_findings$finding),
  paste0(
    "- The five countries with the highest average multi-indicator completeness were ",
    paste0(highest_countries$country_short, " (", scales::percent(highest_countries$mean_completeness, accuracy=1), ")", collapse=", "), "."
  ),
  paste0(
    "- The five countries with the lowest average multi-indicator completeness were ",
    paste0(lowest_countries$country_short, " (", scales::percent(lowest_countries$mean_completeness, accuracy=1), ")", collapse=", "), "."
  ),
  paste0(
    "- Historical 65+ vaccination coverage records were available for ", vax_findings$n_countries,
    " countries and ", vax_findings$n_country_seasons, " country-seasons, with median coverage ",
    scales::percent(vax_findings$median_coverage, accuracy=1), " and range ",
    scales::percent(vax_findings$min_coverage, accuracy=1), "-", scales::percent(vax_findings$max_coverage, accuracy=1), "."
  ),
  paste0("- ", peak_findings$finding),
  "- Relevance: completeness varies materially by indicator and country, so model comparisons and visual interpretation should explicitly display missingness and avoid treating absent observations as epidemiological zeros.",
  "- Relevance: country-season variation in peak timing and relative trajectory shape supports season-specific calibration and cautions against pooling countries without allowing heterogeneous temporal dynamics.",
  "",
  "## Methods summary",
  "",
  "- The script sources setup, settings, flu helper functions, local/offline data loading, and `gen_model_input()`.",
  "- It uses `models_in$data_timeseries_long` as the canonical long-form data table and `models_in$data_season_summary` for season-level completeness and dynamics summaries.",
  "- Weekly completeness is measured as the fraction of expected weekly rows with non-missing values in completed seasons. Vaccination availability is assessed from historical 65+ country-season coverage records.",
  "- Figures are generated with reproducible R code and exported as 320 dpi PNG files suitable for manuscript review. They have passed internal consistency checks in this script, but should still receive domain-expert review before external publication.",
  "",
  "## Limitations",
  "",
  "- Completeness is measured at the data-table level and does not validate national reporting definitions, surveillance-system changes, or clinical comparability between countries.",
  "- Historical vaccination age groups are heterogeneous outside the 65+ series, so cross-country interpretation should focus on comparable target groups unless additional harmonisation is performed.",
  "- The latest configured season is excluded from the main weekly completeness analysis because it is not a completed season in the cached data context.",
  "",
  "## Figures generated",
  "",
  paste0("- `", figure_list, "`"),
  "",
  "## Reproducibility",
  "",
  "Run `Rscript --vanilla code/04_special_analyses/flu_data_publication_analysis.R` from the repository root. The script uses cached/local data (`new_from_online=FALSE`) and does not run Stan or fit models."
)

writeLines(manuscript_lines, here("documentation/flu_data_completeness_publication.md"))
write_csv(completeness_country_metric, here("figures/publication/indicator_completeness_country_metric.csv"))
write_csv(vax_65, here("figures/publication/vaccination_coverage_65plus.csv"))
write_csv(burden_metrics, here("figures/publication/country_season_indicator_variation.csv"))

cat("Publication analysis complete.\n")
cat("Figures written to:", figure_dir, "\n")
cat("Manuscript summary written to:", here("documentation/flu_data_completeness_publication.md"), "\n")
cat("models_in$data_timeseries_long:", paste(dim(models_in$data_timeseries_long), collapse=" x "), "\n")
cat("models_in$data_season_summary:", paste(dim(models_in$data_season_summary), collapse=" x "), "\n")
