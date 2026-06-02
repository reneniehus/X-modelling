# eyeballing.R
#
# Visual "eyeballing" of the canonical tables produced by gen_model_input(). It returns a
# manifest of figures, each bundled with a short title, subtitle and a few narrative bullets,
# so a report (code/03_report/eyeballing_report.Rmd) can render every figure large with its
# findings underneath. Two families of figures:
#   - data-quality figures  : how complete / reliable each indicator is, across countries & seasons
#   - temporal-dynamics figs : how the indicators move over time, by disease and country
#
# The bullets are STATIC narrative placeholders on purpose -- edit them to match what you see.
# Default scope is every country and every season available in the data.

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Shared look & feel ##########
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# consistent colour per pathogen across every figure
pathogen_colours = c("Influenza"="#1b9e77", "SARS-CoV-2"="#7570b3", "RSV"="#d95f02")

# shared minimal theme (note: we call ggplot2::ggplot directly to bypass the global
# ggplot() override from setup.R, so colour/fill scales are fully under our control here)
theme_eyeball = function(base_size=14){
  ggplot2::theme_minimal(base_size=base_size) +
    ggplot2::theme(
      legend.position = "bottom",
      strip.text      = ggplot2::element_text(face="bold"),
      plot.title      = ggplot2::element_text(face="bold"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Individual figure builders ##########
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# ---- |-Quality 1: completeness heatmap (country x season x indicator) ----
fig_completeness = function(season_summary){
  # curated set of series to show, with a readable panel label and a fixed ordering
  quality_series = tribble(
    ~stream,             ~indicator,            ~pathogen,     ~panel,
    "ili_ari",           "ILIconsultationrate", NA,            "ILI consultation rate",
    "ili_ari",           "ARIconsultationrate", NA,            "ARI consultation rate",
    "typing_sentinel",   "positivity",          "Influenza",   "Influenza positivity (sentinel)",
    "typing_sentinel",   "positivity",          "SARS-CoV-2",  "SARS-CoV-2 positivity (sentinel)",
    "typing_sentinel",   "positivity",          "RSV",         "RSV positivity (sentinel)",
    "ili_plus_sentinel", "ili_plus",            "Influenza",   "ILI+ Influenza (sentinel)"
  )
  key_of = function(stream, indicator, pathogen) paste(stream, indicator, ifelse(is.na(pathogen), "", pathogen), sep="|")
  selected = quality_series %>% mutate(.k=key_of(stream, indicator, pathogen))

  df = season_summary %>%
    filter(summary_level=="all_agegroups", temporal_resolution=="weekly") %>%
    mutate(.k=key_of(stream, indicator, pathogen)) %>%
    inner_join(selected %>% select(.k, panel), by=".k") %>%
    mutate(panel=factor(panel, levels=quality_series$panel))

  ggplot2::ggplot(df, ggplot2::aes(season, country_short, fill=completeness)) +
    ggplot2::geom_tile(colour="white", linewidth=0.2) +
    ggplot2::facet_wrap(~panel, ncol=3) +
    ggplot2::scale_fill_viridis_c(limits=c(0,1), labels=scales::percent, na.value="grey92") +
    ggplot2::labs(title="Surveillance completeness across countries and seasons",
                  x=NULL, y=NULL, fill="Weeks reported / weeks in season") +
    theme_eyeball() +
    ggplot2::theme(axis.text.x=ggplot2::element_text(angle=45, hjust=1))
}

# ---- |-Quality 2: typing test volume (country x season) ----
fig_testing_volume = function(timeseries_long){
  # tests are a shared denominator across pathogens, so pick one pathogen to avoid triple-counting
  df = timeseries_long %>%
    filter(indicator=="tests", pathogen=="Influenza",
           stream %in% c("typing_sentinel", "typing_nonsentinel")) %>%
    summarise(total_tests=sum(value, na.rm=TRUE),
              .by=c(country_short, season, stream)) %>%
    mutate(total_tests=ifelse(total_tests <= 0, NA_real_, total_tests),   # 0 tests -> grey, not log10(0)
           stream=recode(stream, typing_sentinel="Sentinel", typing_nonsentinel="Non-sentinel"))

  ggplot2::ggplot(df, ggplot2::aes(season, country_short, fill=total_tests)) +
    ggplot2::geom_tile(colour="white", linewidth=0.2) +
    ggplot2::facet_wrap(~stream, ncol=2) +
    ggplot2::scale_fill_viridis_c(trans="log10", labels=scales::label_comma(), na.value="grey92") +
    ggplot2::labs(title="Typing test volume by country and season",
                  x=NULL, y=NULL, fill="Specimens tested (season total, log scale)") +
    theme_eyeball() +
    ggplot2::theme(axis.text.x=ggplot2::element_text(angle=45, hjust=1))
}

# ---- |-helper: continuous-time, one-panel-per-country line figure ----
# used by the temporal-dynamics figures so that all seasons sit on one continuous axis
# (small multiples over country x season would be unreadable for ~30 countries x ~12 seasons).
facet_country_lines = function(df, colour_var, title, y_lab, colour_lab,
                               colours=NULL, linetype_var=NULL){
  aes_args = list(x=quote(date), y=quote(value), colour=as.name(colour_var))
  if (!is.null(linetype_var)) aes_args$linetype = as.name(linetype_var)
  p = ggplot2::ggplot(df, do.call(ggplot2::aes, aes_args)) +
    ggplot2::geom_line(na.rm=TRUE, linewidth=0.4) +
    ggplot2::facet_wrap(~country_short, ncol=6, scales="free_y") +
    ggplot2::labs(title=title, x=NULL, y=y_lab, colour=colour_lab, linetype=NULL) +
    theme_eyeball(base_size=13)
  if (!is.null(colours)) p = p + ggplot2::scale_colour_manual(values=colours, na.value="grey60")
  p
}

# ---- |-Dynamics 1: ILI+ by pathogen ----
fig_iliplus_dynamics = function(timeseries_long){
  df = timeseries_long %>%
    filter(indicator=="ili_plus", stream=="ili_plus_sentinel", agegroup=="age_total")
  facet_country_lines(df, colour_var="pathogen",
                      title="ILI+ dynamics by pathogen (ILI rate x sentinel positivity)",
                      y_lab="ILI+", colour_lab="Pathogen", colours=pathogen_colours)
}

# ---- |-Dynamics 2: test positivity by pathogen ----
fig_positivity_dynamics = function(timeseries_long){
  df = timeseries_long %>%
    filter(indicator=="positivity", stream=="typing_sentinel", agegroup=="age_total")
  facet_country_lines(df, colour_var="pathogen",
                      title="Sentinel test positivity by pathogen",
                      y_lab="Positivity", colour_lab="Pathogen", colours=pathogen_colours)
}

# ---- |-Dynamics 3: ILI vs ARI consultation rates ----
fig_syndromic_dynamics = function(timeseries_long){
  df = timeseries_long %>%
    filter(stream=="ili_ari", agegroup=="age_total",
           indicator %in% c("ILIconsultationrate", "ARIconsultationrate"))
  facet_country_lines(df, colour_var="indicator_label",
                      title="Syndromic consultation rates: ILI vs ARI",
                      y_lab="Consultation rate", colour_lab="Indicator")
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### eyeballing(): assemble the figure manifest ##########
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Returns list(meta, figures); each figure = list(title, subtitle, bullets, plot).
# countries / seasons default to everything present in the data.
eyeballing = function(models_in, params=NULL, data=NULL, countries=NULL, seasons=NULL){
  long    = models_in$data_timeseries_long
  summary = models_in$data_season_summary
  if (is.null(countries)) countries = sort(unique(long$country_short))
  if (is.null(seasons))   seasons   = sort(unique(long$season))

  long    = long    %>% filter(country_short %in% countries, season %in% seasons)
  summary = summary %>% filter(country_short %in% countries, season %in% seasons)

  figures = list(

    # ---- quality figures ----
    completeness = list(
      title    = "Data completeness across countries and seasons",
      subtitle = "Fraction of in-season weeks with a reported value, by indicator (pooled over age).",
      bullets  = c(
        "ILI/ARI consultation rates are the most complete streams; most countries report the large majority of weeks in recent seasons. *(placeholder — edit)*",
        "Typing positivity is patchier and uneven across countries; several show large gaps in one or more seasons. *(placeholder — edit)*",
        "Pre-2020 seasons carry no SARS-CoV-2 or RSV typing — those blanks are expected, not missing data. *(placeholder — edit)*",
        "Country x season cells near zero are candidates to exclude from modelling. *(placeholder — edit)*"
      ),
      plot     = fig_completeness(summary)
    ),

    testing_volume = list(
      title    = "Typing test volume by country and season",
      subtitle = "Total specimens tested per season (log scale); a proxy for how trustworthy positivity is.",
      bullets  = c(
        "Sentinel testing volumes are typically smaller and noisier than non-sentinel. *(placeholder — edit)*",
        "Very low season totals make positivity (and hence ILI+) unstable for those country/seasons. *(placeholder — edit)*",
        "Large cross-country differences in volume reflect surveillance system size, not just disease burden. *(placeholder — edit)*"
      ),
      plot     = fig_testing_volume(long)
    ),

    # ---- temporal-dynamics figures ----
    iliplus_dynamics = list(
      title    = "ILI+ dynamics by pathogen",
      subtitle = "ILI consultation rate x sentinel positivity, one panel per country, continuous time.",
      bullets  = c(
        "Influenza ILI+ shows the classic sharp winter wave in most countries. *(placeholder — edit)*",
        "SARS-CoV-2 ILI+ appears from 2020/21 with less regular, multi-peak timing. *(placeholder — edit)*",
        "RSV ILI+ tends to lead the influenza peak by several weeks where both are observed. *(placeholder — edit)*",
        "Flat or absent curves indicate the country/season lacks ILI or positivity data (see the quality figures). *(placeholder — edit)*"
      ),
      plot     = fig_iliplus_dynamics(long)
    ),

    positivity_dynamics = list(
      title    = "Test positivity by pathogen",
      subtitle = "Sentinel positivity (detections / tests) per pathogen, one panel per country.",
      bullets  = c(
        "Positivity isolates pathogen circulation timing independent of consultation behaviour. *(placeholder — edit)*",
        "Influenza and RSV positivity are strongly seasonal; SARS-CoV-2 is more persistent year-round. *(placeholder — edit)*",
        "Spiky positivity in low-volume weeks (see test volume) should be read with caution. *(placeholder — edit)*"
      ),
      plot     = fig_positivity_dynamics(long)
    ),

    syndromic_dynamics = list(
      title    = "Syndromic consultation rates: ILI vs ARI",
      subtitle = "Raw ERVISS consultation rates, one panel per country.",
      bullets  = c(
        "ARI sits above ILI by construction (broader case definition). *(placeholder — edit)*",
        "The ILI/ARI gap and its seasonality varies by country, hinting at differing case definitions. *(placeholder — edit)*",
        "These raw rates are the syndromic backbone every ILI+ series is built on. *(placeholder — edit)*"
      ),
      plot     = fig_syndromic_dynamics(long)
    )
  )

  list(
    meta    = list(countries=countries, seasons=seasons,
                   n_countries=length(countries), n_seasons=length(seasons)),
    figures = figures
  )
}
