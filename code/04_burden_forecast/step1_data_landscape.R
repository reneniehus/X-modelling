# ---- |-Burden forecast, Step 1: estimand, DAG, data landscape ----
# Part of the influenza season-burden forecast workflow
# (documentation/burden_forecast/analysis_plan.md). Run from the repo root.
# Produces figures 1.1-1.4 in documentation/burden_forecast/figures/.

# ---- |-Set up (repo pipeline, cached data) ----
source("code/01_main_supporting/setup.R")
source("code/02_settings/settings_version0.R"); params = settings()
source("code/01_main_supporting/flu_functions.R")
source("code/01_main_supporting/validate.R")
source("code/01_main_supporting/load_data.R")
source("code/01_main_supporting/gen_model_input.R")

data      = load_data(params, regenerate = F, new_from_online = F)
models_in = gen_model_input(params, data)

fig_dir = here("documentation/burden_forecast/figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# ---- |-Palette (light mode; dataviz reference instance) ----
pal = list(
  surface = "#fcfcfb", ink = "#0b0b0b", ink2 = "#52514e", muted = "#898781",
  grid = "#e1e0d9", baseline = "#c3c2b7",
  blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a",
  gray_na = "#e1e0d9", gray_zero = "#f0efec",
  seq = c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b")
)

theme_landscape = function(base_size = 10) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background  = element_rect(fill = pal$surface, colour = NA),
      panel.background = element_rect(fill = pal$surface, colour = NA),
      panel.grid.major = element_line(colour = pal$grid, linewidth = 0.25),
      panel.grid.minor = element_blank(),
      text        = element_text(colour = pal$ink),
      axis.text   = element_text(colour = pal$muted, size = base_size - 2),
      axis.title  = element_text(colour = pal$ink2, size = base_size - 1),
      plot.title    = element_text(face = "bold", size = base_size + 3),
      plot.subtitle = element_text(colour = pal$ink2, size = base_size),
      plot.caption  = element_text(colour = pal$muted, size = base_size - 2, hjust = 0),
      strip.text  = element_text(colour = pal$ink2, face = "bold", size = base_size - 1),
      legend.title = element_text(colour = pal$ink2, size = base_size - 1),
      legend.text  = element_text(colour = pal$ink2, size = base_size - 2),
      legend.position = "bottom"
    )
}

# ---- |-Shared tables: influenza ILI+ from both measurement systems ----
dl = models_in$data_timeseries_long

iliplus = dl %>%
  filter(pathogen == "Influenza", agegroup == "age_total",
         stream %in% c("ili_plus_sentinel", "ili_plus_respicompass")) %>%
  transmute(country_short, season, date, season_week,
            source = ifelse(stream == "ili_plus_sentinel",
                            "ERVISS sentinel (2021- )", "RespiCompass history (2014-2024)"),
            value)

# burden window: dates in [1 Oct, 31 May] of each season
in_window = function(date, season) {
  start_year = as.integer(substr(season, 1, 4))
  date >= as.Date(paste0(start_year, "-10-01")) &
    date <= as.Date(paste0(start_year + 1, "-05-31"))
}
iliplus = iliplus %>% mutate(window = in_window(date, season))

# ---- |-Figure 1.1: DAG of the measurement structure ----
nodes = tribble(
  ~name,         ~label,                                       ~x,   ~y,   ~kind,
  "drivers",     "Season drivers\n(drift, weather, immunity)", 0.3,  2.10, "latent",
  "careseek",    "Care seeking",                               1.7,  3.30, "latent",
  "incidence",   "Influenza\nincidence",                       1.7,  2.10, "latent",
  "otherili",    "Other-pathogen\nILI",                        1.7,  0.70, "latent",
  "reporting",   "Reporting\n(missing weeks)",                 3.3,  3.90, "observed",
  "ilirate",     "ILI consultation\nrate (obs)",               3.3,  2.70, "observed",
  "positivity",  "Positivity (obs)",                           3.55, 1.40, "observed",
  "testsn",      "Tests N (obs)",                              3.55, 0.30, "observed",
  "iliplusnode", "ILI+ (derived) =\nILI rate x positivity",    4.95, 2.05, "derived",
  "burden",      "SEASON BURDEN\n(estimand)",                  4.95, 3.50, "estimand"
)
edge = function(from, to, curve = 0) {
  a = nodes[nodes$name == from, ]; b = nodes[nodes$name == to, ]
  tibble(x = a$x, y = a$y, xend = b$x, yend = b$y, curve = curve)
}
edges = bind_rows(
  edge("drivers", "incidence"),
  edge("incidence", "ilirate"),  edge("careseek", "ilirate"),  edge("otherili", "ilirate"),
  edge("incidence", "positivity"), edge("otherili", "positivity"), edge("testsn", "positivity"),
  edge("reporting", "ilirate"),  edge("reporting", "positivity", curve = -0.40),
  edge("ilirate", "iliplusnode"), edge("positivity", "iliplusnode"),
  edge("incidence", "burden", curve = 0.22), edge("careseek", "burden")
) %>%
  mutate(dx = xend - x, dy = yend - y, len = sqrt(dx^2 + dy^2),
         # elliptical shrink so arrowheads stop at the label-box edge
         x1 = x + 0.52 * dx / len,    y1 = y + 0.26 * dy / len,
         x2 = xend - 0.56 * dx / len, y2 = yend - 0.30 * dy / len)

kind_fill = c(latent = pal$surface, observed = pal$blue, derived = pal$orange, estimand = pal$aqua)
kind_brd  = c(latent = pal$muted,  observed = pal$blue, derived = pal$orange, estimand = pal$aqua)
kind_txt  = c(latent = pal$ink2,   observed = "white",  derived = "white",    estimand = "white")
nodes = nodes %>% mutate(fill = kind_fill[kind], brd = kind_brd[kind], txt = kind_txt[kind])

arr = arrow(length = unit(5, "pt"), type = "closed")
fig1 = ggplot2::ggplot() +
  geom_segment(data = filter(edges, curve == 0),
               aes(x = x1, y = y1, xend = x2, yend = y2),
               colour = pal$ink2, linewidth = 0.45, arrow = arr) +
  geom_curve(data = filter(edges, curve < 0),
             aes(x = x1, y = y1, xend = x2, yend = y2),
             curvature = -0.40, colour = pal$ink2, linewidth = 0.45, arrow = arr) +
  geom_curve(data = filter(edges, curve > 0),
             aes(x = x1, y = y1, xend = x2, yend = y2),
             curvature = 0.22, colour = pal$ink2, linewidth = 0.45, arrow = arr) +
  geom_label(data = nodes, aes(x, y, label = label),   # box: fill + border (text overpainted below)
             fill = nodes$fill, colour = nodes$brd, linewidth = 0.5,
             label.padding = unit(0.45, "lines"), label.r = unit(0.5, "lines"),
             size = 2.7, lineheight = 0.95, fontface = "bold") +
  geom_text(data = nodes, aes(x, y, label = label),    # text in its own colour
            colour = nodes$txt, size = 2.7, lineheight = 0.95, fontface = "bold") +
  coord_cartesian(xlim = c(-0.35, 5.75), ylim = c(-0.1, 4.35), clip = "off") +
  labs(title = "Figure 1.1  What produces the data (and the estimand)",
       subtitle = paste0("Gray-bordered boxes: latent. Blue: observed streams. Orange: the derived ILI+ measure. ",
                         "Green: the estimand.\nILI+ inherits noise from BOTH factors; reporting selects which weeks exist at all."),
       caption = "dagitty-equivalent code in documentation/burden_forecast/analysis_plan.md (section 3).") +
  theme_landscape() +
  theme(axis.text = element_blank(), axis.title = element_blank(),
        panel.grid.major = element_blank())
ggsave(file.path(fig_dir, "fig_1_1_dag.png"), fig1, width = 9.5, height = 6, dpi = 200, bg = pal$surface)

# ---- |-Figure 1.2: where data exists, and where it is missing ----
# Three states per country-week: value reported / week present but value NA / no row at all.
grid_avail = iliplus %>%
  group_by(source) %>%
  tidyr::complete(country_short, date) %>%
  ungroup() %>%
  mutate(state = case_when(
    !is.na(value) ~ "value reported",
    is.na(value) & !is.na(season) ~ "week present, value missing",
    TRUE ~ "week present, value missing")) %>%
  group_by(source, country_short, date) %>% slice(1) %>% ungroup()

# country order: by total reported weeks (most data on top)
c_order = grid_avail %>% filter(state == "value reported") %>%
  count(country_short) %>% arrange(n) %>% pull(country_short)
grid_avail = grid_avail %>%
  mutate(country_short = factor(country_short, levels = c_order))

season_starts = as.Date(paste0(2014:2026, "-08-01"))

fig2 = ggplot2::ggplot(grid_avail, aes(date, country_short, fill = state)) +
  geom_tile() +
  geom_vline(xintercept = season_starts, colour = pal$surface, linewidth = 0.7) +
  facet_wrap(~source, ncol = 1, scales = "free_y") +
  scale_fill_manual(name = NULL,
                    values = c("value reported" = pal$blue,
                               "week present, value missing" = pal$gray_na)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0, 0)) +
  labs(title = "Figure 1.2  Influenza ILI+ availability, country x week",
       subtitle = "Blank = country-week absent from the stream entirely. White seams mark season starts (1 Aug).\nThe two measurement systems overlap only in 2021/22-2023/24.",
       x = NULL, y = NULL,
       caption = "Streams: ili_plus_sentinel and ili_plus_respicompass, pathogen = Influenza, agegroup = age_total.") +
  theme_landscape() +
  theme(panel.grid.major = element_blank(), axis.text.y = element_text(size = 5.5))
ggsave(file.path(fig_dir, "fig_1_2_availability.png"), fig2, width = 12, height = 9, dpi = 200, bg = pal$surface)

# ---- |-Figure 1.3: the seasonal shapes behind the estimand (sentinel only) ----
sent = iliplus %>%
  filter(source == "ERVISS sentinel (2021- )", !is.na(value)) %>%
  mutate(highlight = case_when(
    season == "2025/2026" ~ "2025/26",
    season == "2024/2025" ~ "2024/25",
    TRUE ~ "earlier seasons"))

fig3 = ggplot2::ggplot(sent, aes(season_week, value, group = season)) +
  geom_line(data = ~ filter(.x, highlight == "earlier seasons"),
            colour = pal$baseline, linewidth = 0.35) +
  geom_line(data = ~ filter(.x, highlight == "2024/25"),
            aes(colour = "2024/25"), linewidth = 0.55) +
  geom_line(data = ~ filter(.x, highlight == "2025/26"),
            aes(colour = "2025/26"), linewidth = 0.55) +
  scale_colour_manual(name = NULL, values = c("2024/25" = pal$orange, "2025/26" = pal$blue),
                      guide = guide_legend(override.aes = list(linewidth = 1.2))) +
  facet_wrap(~country_short, ncol = 6, scales = "free_y") +
  scale_x_continuous(breaks = c(1, 14, 27, 40), labels = c("Aug", "Nov", "Feb", "May")) +
  labs(title = "Figure 1.3  Sentinel influenza ILI+ by season week - every country, every season",
       subtitle = "Gray: 2020/21-2023/24. Free y-scales: shapes are comparable, absolute levels differ by an order of magnitude.\nGaps in lines are missing weeks (compare Figure 1.2).",
       x = "season week (season runs 1 Aug - 31 Jul)",
       y = "ILI+ (influenza-attributable ILI consultations / 100k / week)",
       caption = "Free y-axes chosen deliberately: the estimand is per-country; cross-country level comparison comes in Figure 1.4.") +
  theme_landscape(base_size = 9)
ggsave(file.path(fig_dir, "fig_1_3_seasonal_curves.png"), fig3, width = 12, height = 9, dpi = 200, bg = pal$surface)

# ---- |-Figure 1.4: the estimand, empirically - burden matrix with completeness ----
burden = iliplus %>%
  filter(window) %>%
  group_by(source, country_short, season) %>%
  summarise(weeks_reported = sum(!is.na(value)),
            weeks_window   = dplyr::n(),
            burden         = ifelse(weeks_reported == 0, NA_real_,
                                    sum(value, na.rm = TRUE)),
            completeness   = weeks_reported / 35,  # 35 = full Oct-May window
            .groups = "drop") %>%
  mutate(flag_incomplete = completeness < 0.7 & !is.na(burden))

cap = 3000  # LU and MT (RespiCompass) reach ~60000 - implausible, see caption; capped so the rest stays readable
fig4 = ggplot2::ggplot(burden, aes(season, country_short, fill = pmin(burden, cap))) +
  geom_tile(colour = pal$surface, linewidth = 0.6) +
  geom_point(data = ~ filter(.x, flag_incomplete),
             aes(shape = "under 70% of window weeks reported"),
             colour = pal$ink, size = 1.1, stroke = 0.6) +
  facet_wrap(~source, ncol = 2, scales = "free_x") +
  scale_fill_gradientn(name = "season burden\n(cumulative ILI+, per 100k)",
                       colours = pal$seq, trans = "sqrt", na.value = pal$gray_zero,
                       breaks = c(0, 500, 1500, 3000), labels = c("0", "500", "1500", "3000+"),
                       guide = guide_colourbar(barwidth = unit(9, "cm"))) +
  scale_shape_manual(name = NULL, values = c("under 70% of window weeks reported" = 1)) +
  labs(title = "Figure 1.4  The estimand, observed: season burden by country x season",
       subtitle = "Sum of weekly ILI+ over 1 Oct - 31 May. Pale gray tile = no usable weeks. Open circle = burden shown but\nunder-counted (<70% of window weeks reported) - these sums are lower bounds, not measurements.",
       x = NULL, y = NULL,
       caption = paste0("Square-root fill scale, capped at 3000: LU and MT RespiCompass burdens reach ~60,000/100k - implausible, ",
                        "flagged as a data-quality issue for Step 2.\n2020/21 is a structural COVID anomaly in both systems.")) +
  theme_landscape() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major = element_blank(), axis.text.y = element_text(size = 5.5))
ggsave(file.path(fig_dir, "fig_1_4_burden_matrix.png"), fig4, width = 13, height = 8.5, dpi = 200, bg = pal$surface)

# ---- |-Console summary for the pause ----
cat("\nStep 1 figures written to", fig_dir, "\n")
print(burden %>% filter(!is.na(burden)) %>%
        group_by(source, season) %>%
        summarise(countries = dplyr::n(), median_burden = round(median(burden)),
                  incomplete = sum(flag_incomplete), .groups = "drop") %>%
        as.data.frame())
