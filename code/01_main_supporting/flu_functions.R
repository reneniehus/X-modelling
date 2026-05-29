


# Computing the severity factor due to vaccines, assuming no waning
vaccine_severity_nowane = function(
    vaccine_uptake, # [t,a] fraction of population vaccinated by time-bin and by age
    VE_severe # assumed reduction in severity by a typical administered dose 
){
  severity_factor_vaccines = 1 - ( vaccine_uptake*VE_severe )
  
  list_out = list(
    severity_factor_vaccines=severity_factor_vaccines
  )
  return(list_out)
}

# Computing the severity factor due to natural immunity
natural_severity = function(
    incident_infections, # [t,a] # infections by time-bin, and by age
    natual_severity_options=NULL # a list of options for natural severity module 
){
  severity_factor_natural = (incident_infections*0 + 1)
  
  list_out = list(
    severity_factor_natural=severity_factor_natural
  )
  return(list_out)
}

mnaming = function(df,mnames){
  names(df) = mnames
  return(df)
}

# Computing severe outcomes from infections
severity_factor = function(
    incident_infections, # [t,a] infections by time-bin, and by age
    severity_baseline, # [a] fraction of infections that is severe by age
    severity_factor_vaccines, # [t,a] modifying factor for severity due to vaccines
    severity_factor_natural, # [t,a] modifying factor for severity due to natural immunity
    severity_options=NULL # a list of options for severity module 
){
  # 1: combine the factors impacting severity
  severity_factor_combined = severity_factor_vaccines*severity_factor_natural
  # 2: modulate the baseline severity using the combined severity factors, get the effective severity
  severity_modulated = severity_factor_combined
  for (a_i in 1:length(severity_baseline) ) {
    severity_modulated[,a_i] = severity_baseline[a_i] * severity_factor_combined[,a_i]
  }
  # 3: compute the severe outcomes given infections and the effective severity 
  incident_severe = incident_infections*severity_modulated
  
  list_out = list(
    severity_factor_combined=severity_factor_combined, # [t,a] combined factors that impact the raw severity
    severity_modulated=severity_modulated, # [t,a] the effective severity after accounting for all severity factors
    incident_severe=incident_severe # [t,a] the severe indicator
  )
  return(list_out)
}

combine_all_targets_SIR_simple = function(date_v,
                                          incident_infections,
                                          vaccine_uptake,
                                          incident_severe) {
  mout=tibble(
    date=date_v,
    inc_infections=incident_infections[,1],
    inc_doses=vaccine_uptake[,1],
    inc_death=incident_severe[,1]
  )
  return(mout)
}

rep_warning_wed = function(df_rep,ind_name){
  # reporting warning for the case of reporting on weekdays other than Wednesday
  if (nrow(df_rep)==0) return(invisible(NULL))
  shouldbe_wednesday=df_rep$date %>% weekdays() %>% table() %>% names()
  warn1 = (length(shouldbe_wednesday)>1); warn2 = shouldbe_wednesday[1]!="Wednesday"
  if (warn1|warn2) {pr=paste("Warning: some",ind_name,"reports on days other than Wed \n"); cat(red(pr))}
  return(invisible(NULL))
}


season_start_year_from_label <- function(season) {
  as.integer(stringr::str_sub(season, 1, 4))
}

add_season_time_columns <- function(df, params=NULL) {
  if (!"date" %in% names(df)) df$date <- as.Date(NA)
  df$date <- as.Date(df$date)
  if (!"season" %in% names(df)) df$season <- NA_character_
  season_start_year <- season_start_year_from_label(df$season)
  season_start_date <- lubridate::ymd(paste0(season_start_year, params$season_start_monthday))
  df %>% mutate(
    season_start_year = season_start_year,
    season_start_date = season_start_date,
    season_day = as.integer(date - season_start_date) + 1L,
    season_week = as.integer(floor((season_day - 1L) / 7L) + 1L),
    iso_week = ifelse(is.na(date), NA_character_, ISOweek::ISOweek(date))
  )
}

normalise_indicator_label <- function(indicator) {
  case_when(
    indicator == "ILIconsultationrate" ~ "ILI consultation rate",
    indicator == "ARIconsultationrate" ~ "ARI consultation rate",
    indicator == "ili_plus" ~ "ILI+",
    indicator == "positivity" ~ "Influenza positivity",
    indicator == "detections" ~ "Influenza detections",
    indicator == "tests" ~ "Influenza tests",
    indicator == "vaccine_coverage" ~ "Vaccination coverage",
    TRUE ~ indicator
  )
}

normalise_indicator_unit <- function(indicator) {
  case_when(
    indicator %in% c("positivity", "vaccine_coverage") ~ "proportion",
    indicator %in% c("detections", "tests") ~ "count",
    indicator %in% c("ILIconsultationrate", "ARIconsultationrate", "ili_plus") ~ "rate",
    TRUE ~ NA_character_
  )
}

prepare_timeseries_piece <- function(df, params=NULL, source=NULL, stream=NULL, value_col="value", indicator_default=NULL) {
  if (!"date" %in% names(df)) df$date <- as.Date(NA)
  if (!"target" %in% names(df) & "indicator" %in% names(df)) df$target <- df$indicator
  if (!"target" %in% names(df)) df$target <- indicator_default
  if (is.null(df$target)) df$target <- NA_character_
  if (!"agegroup" %in% names(df)) df$agegroup <- "age_total"
  if (!"pathogentype" %in% names(df)) df$pathogentype <- NA_character_
  if (!"pathogensubtype" %in% names(df)) df$pathogensubtype <- NA_character_
  if (!value_col %in% names(df)) df[[value_col]] <- NA_real_
  df %>%
    transmute(
      country_short,
      season,
      date=as.Date(date),
      indicator=target,
      indicator_label=normalise_indicator_label(target),
      source=source,
      stream=stream,
      scenario=NA_character_,
      agegroup,
      pathogentype,
      pathogensubtype,
      value=as.numeric(.data[[value_col]]),
      unit=normalise_indicator_unit(target),
      temporal_resolution="weekly",
      observed=!is.na(value)
    ) %>%
    add_season_time_columns(params=params)
}

unnest_season_stream <- function(data_all_season, nested_col) {
  data_all_season %>%
    select(country_short, season, all_of(nested_col)) %>%
    tidyr::unnest(cols=all_of(nested_col))
}

make_data_timeseries_long <- function(data_all_season, data=NULL, params=NULL) {
  pieces <- list(
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "inc_iliari"), params=params, source="ERVISS", stream="ili_ari"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "typing_sentinel"), params=params, source="ERVISS", stream="sentinel_typing"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "typing_nonsentinel"), params=params, source="ERVISS", stream="nonsentinel_typing"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "typing_combined"), params=params, source="ERVISS", stream="sentinel_plus_nonsentinel_typing", value_col="value_add_narm"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "respicompass_ili_plus"), params=params, source="RespiCompass", stream="ili_plus"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "erviss_ili_plus_sentinel"), params=params, source="ERVISS", stream="ili_plus_sentinel", indicator_default="ili_plus"),
    prepare_timeseries_piece(unnest_season_stream(data_all_season, "erviss_ili_plus_nonsentinel"), params=params, source="ERVISS", stream="ili_plus_nonsentinel", indicator_default="ili_plus")
  )
  long_df <- bind_rows(pieces)
  if (!is.null(data$vax$data_vax_history)) {
    vax_history <- data$vax$data_vax_history %>%
      transmute(
        country_short=iso2_code,
        season,
        date=as.Date(NA),
        indicator="vaccine_coverage",
        indicator_label=normalise_indicator_label(indicator),
        source=source,
        stream="vaccination_history_65plus",
        scenario="observed_history",
        agegroup=target_group,
        pathogentype=NA_character_,
        pathogensubtype=NA_character_,
        value=as.numeric(vaccine_coverage),
        unit=normalise_indicator_unit(indicator),
        temporal_resolution="seasonal",
        observed=!is.na(value)
      ) %>%
      add_season_time_columns(params=params)
    long_df <- bind_rows(long_df, vax_history)
  }
  if (!is.null(data$vax$data_vax)) {
    vax_scenarios <- data$vax$data_vax %>%
      pivot_longer(cols=c("higher_vax_coverage", "lower_vax_coverage", "no_vaccination"),
                   names_to="scenario", values_to="vaccine_coverage") %>%
      transmute(
        country_short=iso2_code,
        season=paste0(params$latest_start_year, "/", params$latest_start_year + 1),
        date=as.Date(NA),
        indicator="vaccine_coverage",
        indicator_label=normalise_indicator_label(indicator),
        source="RespiCompass",
        stream="vaccination_scenario",
        scenario,
        agegroup=target_group,
        pathogentype=NA_character_,
        pathogensubtype=NA_character_,
        value=as.numeric(vaccine_coverage),
        unit=normalise_indicator_unit(indicator),
        temporal_resolution="seasonal",
        observed=!is.na(value)
      ) %>%
      add_season_time_columns(params=params)
    long_df <- bind_rows(long_df, vax_scenarios)
  }
  long_df %>% arrange(country_short, season, source, stream, indicator, scenario, agegroup, date)
}

summarise_timeseries_group <- function(df) {
  df %>% summarise(
    n_rows=n(),
    n_observed=sum(observed, na.rm=TRUE),
    observed_fraction=mean(observed, na.rm=TRUE),
    sum_value=sum(value, na.rm=TRUE),
    mean_value=mean(value, na.rm=TRUE),
    max_value=ifelse(all(is.na(value)), NA_real_, max(value, na.rm=TRUE)),
    peak_date=ifelse(all(is.na(value)) | all(is.na(date)), as.Date(NA), date[which.max(replace_na(value, -Inf))]),
    first_date=ifelse(all(is.na(date)), as.Date(NA), min(date, na.rm=TRUE)),
    last_date=ifelse(all(is.na(date)), as.Date(NA), max(date, na.rm=TRUE)),
    .groups="drop"
  ) %>% mutate(
    peak_date=as.Date(peak_date, origin="1970-01-01"),
    first_date=as.Date(first_date, origin="1970-01-01"),
    last_date=as.Date(last_date, origin="1970-01-01")
  )
}

make_data_season_summary <- function(data_all_season, data_timeseries_long, data=NULL, params=NULL) {
  age_specific <- data_timeseries_long %>%
    group_by(country_short, season, indicator, indicator_label, source, stream, scenario, agegroup, unit, temporal_resolution) %>%
    summarise_timeseries_group() %>%
    mutate(summary_level="agegroup")
  all_agegroups <- data_timeseries_long %>%
    group_by(country_short, season, indicator, indicator_label, source, stream, scenario, unit, temporal_resolution) %>%
    summarise_timeseries_group() %>%
    mutate(agegroup="all_agegroups", summary_level="all_agegroups")
  bind_rows(age_specific, all_agegroups) %>%
    select(country_short, season, indicator, indicator_label, source, stream, scenario, agegroup, summary_level, unit, temporal_resolution, everything()) %>%
    arrange(country_short, season, source, stream, indicator, summary_level, agegroup)
}

eyeballing <- function(models_in, params=NULL, data=NULL, countries=NULL, seasons=NULL, interactive=TRUE) {
  data_timeseries_long <- models_in$data_timeseries_long
  data_season_summary <- models_in$data_season_summary
  if (is.null(countries)) countries <- params$run_countries
  if (is.null(countries) || length(countries)==0) countries <- data_timeseries_long$country_short %>% unique() %>% head(6)
  if (is.null(seasons)) seasons <- data_timeseries_long$season %>% unique()
  plot_data <- data_timeseries_long %>% filter(country_short %in% countries, season %in% seasons)
  p_indicators <- plot_data %>%
    filter(temporal_resolution=="weekly", agegroup=="age_total", indicator %in% c("ILIconsultationrate", "ARIconsultationrate", "ili_plus", "positivity")) %>%
    ggplot(aes(date, value, color=indicator_label, linetype=stream)) +
    geom_line(na.rm=TRUE) +
    facet_grid(country_short ~ season, scales="free_y") +
    labs(title="Flu indicator dynamics by country and season", x=NULL, y="Value", color="Indicator", linetype="Stream") +
    theme_minimal()
  p_quality <- data_season_summary %>%
    filter(country_short %in% countries, season %in% seasons, summary_level=="all_agegroups", indicator %in% c("ILIconsultationrate", "ARIconsultationrate", "ili_plus", "positivity", "tests")) %>%
    ggplot(aes(season, observed_fraction, fill=indicator_label)) +
    geom_col(position="dodge") +
    facet_grid(country_short ~ stream) +
    coord_cartesian(ylim=c(0, 1)) +
    labs(title="Observed fraction / completeness by season", x=NULL, y="Observed fraction", fill="Indicator") +
    theme_minimal() +
    theme(axis.text.x=element_text(angle=45, hjust=1))
  p_testing <- plot_data %>%
    filter(temporal_resolution=="weekly", agegroup=="age_total", indicator %in% c("tests", "detections", "positivity"), stream %in% c("sentinel_typing", "nonsentinel_typing", "sentinel_plus_nonsentinel_typing")) %>%
    ggplot(aes(date, value, color=stream)) +
    geom_line(na.rm=TRUE) +
    facet_grid(indicator_label + country_short ~ season, scales="free_y") +
    labs(title="Influenza testing, detections and positivity", x=NULL, y="Value", color="Stream") +
    theme_minimal()
  p_age <- plot_data %>%
    filter(temporal_resolution=="weekly", indicator %in% c("ILIconsultationrate", "ARIconsultationrate", "ili_plus"), agegroup != "age_total") %>%
    ggplot(aes(date, value, color=agegroup)) +
    geom_line(na.rm=TRUE) +
    facet_grid(indicator_label + country_short ~ season, scales="free_y") +
    labs(title="Age-specific flu indicators", x=NULL, y="Value", color="Age group") +
    theme_minimal()
  plots <- list(indicator_dynamics=p_indicators, data_quality=p_quality, testing_dynamics=p_testing, age_dynamics=p_age)
  interactive_plots <- NULL
  if (interactive && requireNamespace("plotly", quietly=TRUE)) {
    interactive_plots <- purrr::map(plots, plotly::ggplotly)
  }
  list(
    plots=plots,
    interactive_plots=interactive_plots,
    data_used=plot_data,
    note=if (is.null(interactive_plots)) "Install/load plotly to receive interactive ggplotly versions of the plots." else "Interactive plotly versions are available in interactive_plots."
  )
}


data_into_all_season = function(data,params,withforce=F){
  # function that loops through countries and seasons and makes all useful data available through a list (avoid model choices here)
  
  file_doesnot_exist = !file.exists("output/all_season.Rdata")
  if (file_doesnot_exist|withforce==T) {
    # initiate list
    df_collect = list()
    df_i = 1
    
    # loop only through countries where ILIconsultationrate exists
    country_short_input_v=data$epi$erviss_ili_ari %>% 
      filter(target=="ILIconsultationrate") %>% 
      pull(country_short) %>% unique() ; length(country_short_input_v)
    
    for (country_short_input_i in country_short_input_v) { # country_short_input_i = country_short_input_v[1] 
      start_year = data$epi$erviss_ili_ari %>% filter(country_short==country_short_input_i) %>% 
        pull(date) %>% min() %>% year() %>% as.numeric()
      while( start_year<=params$latest_start_year ) {
        
        season     = paste0(start_year,"/",start_year+1)
        start_date = ymd(paste0(start_year,params$season_start_monthday))
        end_date   = ymd(paste0(start_year+1,params$season_end_monthday))
        date_v = seq(from=start_date,to=end_date,by="day")
        date_v_wed = date_v[weekdays(date_v)=="Wednesday"]
        start_year = start_year+1 # do this up here due to next; statements
        
        ## ili/ari
        data$epi$erviss_ili_ari %>% 
          filter(country_short == country_short_input_i) %>% 
          select(-country_short) %>% 
          filter( date%in%date_v ) -> xinc_iliari; rep_warning_wed(xinc_iliari,"ili/ari")
        if ( nrow(xinc_iliari) == 0 ) next;
        
        # fill data gaps
        crossing(target=c("ILIconsultationrate","ARIconsultationrate"), 
                 date=date_v_wed,
                 agegroup=c("age_00_04", "age_15_64", "age_05_14", "age_65_99", "age_total")
        ) %>% 
          left_join(  xinc_iliari,by = join_by(target,date,agegroup) ) %>% 
          fill(c("agegroup", "target"),.direction = "downup") -> xinc_iliari
        
        ## typing_sentinel
        data$epi$erviss_typing_sentinel %>% 
          filter(country_short == country_short_input_i,date%in%date_v) %>% 
          filter(pathogen=="Influenza",pathogensubtype=="total") %>% 
          select(-country_short,-survtype,-countryname,-pathogen,-age,-yearweek) -> xtyping_sent
        # fill tdata gaps
        if (nrow(xtyping_sent)>=1) crossing( date=date_v_wed,
                                             indicator=c("detections","positivity","tests"  ) ) %>% 
          left_join( xtyping_sent, by = join_by(date,indicator) ) %>% 
          fill( c("pathogentype", "pathogensubtype"),.direction = "downup" ) -> xtyping_sent; 
        # calculate my own positivity
        xtyping_sent %>% group_by(date) %>%  mutate(
          value=ifelse(indicator=="positivity",
                       value[indicator=="detections"]/value[indicator=="tests"],
                       value)
        ) %>% ungroup() %>% mutate(value=replace_inf(value,NA)) -> xtyping_sent
        rep_warning_wed(xtyping_sent,"sent_typing")
        
        
        # typing_nonsentinel
        data$epi$erviss_typing_nonsentinel %>% 
          filter(country_short == country_short_input_i,date%in%date_v) %>%
          filter(pathogen=="Influenza",pathogensubtype=="total") %>% 
          select(-country_short,-survtype,-countryname,-pathogen,-age,-yearweek) -> xtyping_nonsent
        # fill the date gaps
        if (nrow(xtyping_nonsent)>=1) crossing( date=date_v_wed,
                                                indicator=c("detections","positivity","tests"  ) ) %>% 
          left_join( xtyping_nonsent, by = join_by(date,indicator) ) %>% 
          fill( c("pathogentype", "pathogensubtype"),.direction = "downup" ) -> xtyping_nonsent
        # compute positivty
        
        xtyping_nonsent %>% group_by(date) %>%  mutate(
          value=ifelse(indicator=="positivity",
                       value[indicator=="detections"]/value[indicator=="tests"],
                       value)
        ) %>% ungroup() %>% mutate(value=replace_inf(value,NA)) -> xtyping_nonsent; rep_warning_wed(xtyping_nonsent,"nonsent_typing")
        xtyping_nonsent %>% filter(value %>% is.infinite()) -> mytest
        if (nrow(mytest)>0) {browser()}
        ## combine sentinel and non-sentinel
        xtyping_sent    %>% rename(value_sent=value)   -> x1
        xtyping_nonsent %>% rename(value_nonsent=value)-> x2
        xtyping_combined=left_join(x1,x2,by = join_by(date, indicator, pathogentype,pathogensubtype)) %>%
          mutate(value_add_narm=replace_na(value_sent,0)+replace_na(value_nonsent,0)  ) %>% 
          group_by(date) %>%  mutate(
            value_add_narm=ifelse(indicator=="positivity",
                                  value_add_narm[indicator=="detections"]/value_add_narm[indicator=="tests"],
                                  value_add_narm)
          ) %>% ungroup()
        
        ## respicompass ili_plus
        data$epi$respicompass_iliplus %>% 
          filter(country_short == country_short_input_i) %>% 
          select(-country_short) %>% 
          filter( date%in%date_v ) -> x_iliplus; rep_warning_wed(x_iliplus,"respicompass_iliplus")
        crossing(target=c("ili_plus"), 
                 date=date_v_wed,
                 agegroup=c("age_00_04", "age_15_64", "age_05_14", "age_65_99", "age_total")
        ) %>% 
          left_join(  x_iliplus,by = join_by(target,date,agegroup) ) %>% 
          fill(c("agegroup", "target"),.direction = "downup") -> x_iliplus
        
        ## erviss-based ili_plus
        . %>% select(date,value) -> mfu
        xinc_iliari %>% filter(target=="ILIconsultationrate") %>% select(date,agegroup,value) %>% rename(ILI=value) -> x1
        xtyping_sent %>% filter(indicator=="positivity")%>% mfu() %>% rename(pos=value)  -> x2_sent
        xtyping_nonsent %>% filter(indicator=="positivity")%>% mfu() %>% rename(pos=value) -> x2_nonsent
        . %>% transmute(date=date,agegroup=agegroup,value=pos*ILI) -> mfu
        x1 %>% left_join(x2_sent,by = 'date') %>% mfu() -> x_iliplus_erviss_sent
        x1 %>% left_join(x2_nonsent,by = 'date') %>% mfu() -> x_iliplus_erviss_nonsent
        
        ## data quality measures
        ili_sum=xinc_iliari %>% filter(target=="ILIconsultationrate") %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ili_quality=xinc_iliari %>% filter(target=="ILIconsultationrate") %>% mutate(v_q= !is.na(value)&(value>0) ) %>% summarise(x=mean( v_q )) %>% pull(x)
        ari_sum=xinc_iliari %>% filter(target=="ARIconsultationrate") %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ari_quality=xinc_iliari %>% filter(target=="ARIconsultationrate") %>% mutate(v_q= !is.na(value)&(value>0) ) %>% summarise(x=mean( v_q )) %>% pull(x)
        
        ntests_sent = xtyping_sent %>% filter(indicator=="tests") %>% summarise(msum=sum(value,na.rm=T)) %>% pull(msum)
        tests_sentinel_quality = xtyping_sent %>% filter(indicator=="tests") %>% summarise(x=mean(value>5,na.rm=T)) %>% pull(x)
        ntests_nonsent = xtyping_nonsent%>% filter(indicator=="tests")%>% summarise(msum=sum(value,na.rm=T)) %>% pull(msum)
        tests_nonsentinel_quality = xtyping_nonsent %>% filter(indicator=="tests") %>% summarise(x=mean(value>5,na.rm=T)) %>% pull(x)
        ili_plus_sum=x_iliplus %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ili_plus_erviss_sent_sum=x_iliplus_erviss_sent %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ili_plus_erviss_nonsent_sum=x_iliplus_erviss_nonsent %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        
        ili_plus_agesplit_sum=x_iliplus %>% filter(agegroup!="age_total") %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ili_plus_erviss_sent_agesplit_sum=x_iliplus_erviss_sent %>% filter(agegroup!="age_total") %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        ili_plus_erviss_nonsent_agesplit_sum=x_iliplus_erviss_nonsent %>% filter(agegroup!="age_total") %>% summarise(x=sum(value,na.rm=T)) %>% pull(x)
        
        ili_plus_quality=x_iliplus %>% summarise(x=mean(!is.na(value))) %>% pull(x)
        ili_plus_erviss_sent_quality=x_iliplus_erviss_sent %>% summarise(x=mean(!is.na(value))) %>% pull(x)
        ili_plus_erviss_nonsent_quality=x_iliplus_erviss_nonsent %>% summarise(x=mean(!is.na(value))) %>% pull(x)
        
        ## plotting
        xinc_iliari %>% ggplot(aes(date,value))+geom_line()
        xtyping_sent %>% filter(indicator=="positivity") %>% ggplot(aes(date,value))+geom_line()
        xtyping_nonsent %>% filter(indicator=="positivity") %>% ggplot(aes(date,value))+geom_line()
        x_iliplus %>% filter(agegroup=="age_total") %>% ggplot(aes(date,value))+geom_line()
        
        ## skipping 
        # if ( nrow(xinc_iliari) < 10 ) next;
        # if ( sum_inc < 300 ) next;
        
        ## printing
        pr=paste0("> Run: ",country_short_input_i," | ",season,
                  " | ili/ari: ",my_comma(ili_sum),"/",my_comma(ari_sum),
                  " | tests-sent/nonsent/combined:",
                  my_comma(ntests_sent),"/",my_comma(ntests_nonsent),"/",my_comma(ntests_sent+ntests_nonsent),
                  "\n"); cat(green(pr))
        
        # put data together
        df_collect[[df_i]] = tibble(
          country_short=country_short_input_i,
          season=season,
          #
          ili_sum=ili_sum,
          ili_quality=ili_quality,
          ari_sum=ari_sum,
          ari_quality=ari_quality,
          tests_sentinel=ntests_sent,
          tests_sentinel_quality=tests_sentinel_quality,
          tests_nonsentinel=ntests_nonsent,
          tests_nonsentinel_quality=tests_nonsentinel_quality,
          # ili plus, 3 versions
          ili_plus_sum=ili_plus_sum,
          ili_plus_agesplit_sum=ili_plus_agesplit_sum,
          ili_plus_quality=ili_plus_quality,
          #
          ili_plus_erviss_sent_sum=ili_plus_erviss_sent_sum,
          ili_plus_erviss_sent_agesplit_sum=ili_plus_erviss_sent_agesplit_sum,
          ili_plus_erviss_sent_quality=ili_plus_erviss_sent_quality,
          #
          ili_plus_erviss_nonsent_sum=ili_plus_erviss_nonsent_sum,
          ili_plus_erviss_nonsent_agesplit_sum=ili_plus_erviss_nonsent_agesplit_sum,
          ili_plus_erviss_nonsent_quality=ili_plus_erviss_nonsent_quality,
          # nested dataframes
          nest(xinc_iliari) %>% rename(inc_iliari=data),
          nest(xtyping_sent) %>% rename(typing_sentinel=data),
          nest(xtyping_nonsent) %>% rename(typing_nonsentinel=data),
          nest(xtyping_combined) %>% rename(typing_combined=data),
          nest(x_iliplus) %>% rename(respicompass_ili_plus=data),
          nest(x_iliplus_erviss_sent) %>% rename(erviss_ili_plus_sentinel=data),
          nest(x_iliplus_erviss_nonsent) %>% rename(erviss_ili_plus_nonsentinel=data)
        )
        df_i = df_i + 1
      } # season loop
    } # country loop
    all_season = bind_rows(df_collect)
    save(all_season,file="output/all_season.Rdata")
  }
  
  
  load(file="output/all_season.Rdata")
  return(all_season)
}

transform_contracts = function(data,params) {
  
  #stop("Implement the 5th age group!")
  contacts_normalized_all = list()
  
  if (T){
    xlocations = data$helpers_respicompass$iso2_code
    for (country_i in xlocations$location_name){ # country_i = xlocations$location_name[1]
      
      # Load original contact matrix
      contacts_orig = data$contact[[country_i]]
      if (length(contacts_orig) == 1 ){ # If contact matrix for this country is not available, skip and go to the next
        next
      }
      
      # Get age-group sizes
      x_pop = data$demography_respicast$population_pyramid_fin %>% 
        filter(country==country_i)
      x_pop_vec = x_pop$population 
      x_pop_vec = c(x_pop_vec[1:16], sum(x_pop_vec[17:21]))
      
      # Add the 80+ age group, assuming it has same per person nr of contacts as 75-79y age group
      x_contacts = cbind(contacts_orig, contacts_orig[,16])
      x_contacts = rbind(x_contacts, x_contacts[16,])
      contacts_orig = x_contacts
      
      # Fix the contact matrix non-symmetry issue by taking the mean value of the two (taking population size into account)
      # computing m′ij as in [https://cran.r-project.org/web/packages/socialmixr/vignettes/socialmixr.html]
      # mij is the mean number of contacts made by members of age group i with members of age group j
      # thus ROWS are needed for the transmission process -> contacts[i,]
      contacts = NA*contacts_orig
      for (ii in 1:nrow(contacts_orig)){
        for (jj in 1:nrow(contacts_orig)){
          contacts[ii,jj] = (contacts_orig[ii,jj]*x_pop_vec[ii] + contacts_orig[jj,ii]*x_pop_vec[jj]) / (2*x_pop_vec[ii])
        }
      }

      # Get total number of contacts per age group; aka, each element is total number of contacts between age group i and j
      # Specifically, multiply contacts[i,j] by the population size of age group i (which is x_pop_vec[i])
      contacts_total = as.matrix(contacts) * x_pop_vec
      # Need to use the transpose in the pop matrix above such that columns of the population matrix have the same element
      # This is because value contact[i,j] represents number of contacts of person in age group i with persons in age group j
      if (!isSymmetric(contacts_total, check.attributes = FALSE)){
        stop("The contacts_total matrix is not symmetric!")
      }
      ####
      #total_nr_contacts_per_person = sum( contacts_total[row(contacts_total)>=col(contacts_total)] ) / sum(x_pop_vec)
      #contacts = contacts_total / (t(matrix(rep( x_pop_vec, 17), nrow = 17)) * total_nr_contacts_per_person)
      ####
      
      # Change from 16 age groups to 4
      contacts_total_new = matrix(NA,4,4)
      #
      contacts_total_new[1,1] = contacts_total[1,1]
      #
      tmp_matrix = contacts_total[2:3,2:3] 
      contacts_total_new[2,2] = sum(tmp_matrix[row(tmp_matrix)>=col(tmp_matrix)]) # This part ensures that we add diagonal + only one off-diagonal part (e.g., upper but not lower), ensuring we don't count things twice
      contacts_total_new[1,2] = sum(contacts_total[1,2:3])
      contacts_total_new[2,1] = sum(contacts_total[2:3,1])
      #
      tmp_matrix = contacts_total[4:13,4:13]
      contacts_total_new[3,3] = sum(tmp_matrix[row(tmp_matrix)>=col(tmp_matrix)])
      contacts_total_new[1,3] = sum(contacts_total[1,4:13])
      contacts_total_new[3,1] = sum(contacts_total[4:13,1])
      contacts_total_new[2,3] = sum(contacts_total[2:3,4:13])
      contacts_total_new[3,2] = sum(contacts_total[4:13,2:3])
      #
      tmp_matrix = contacts_total[14:17,14:17]
      contacts_total_new[4,4] = sum(tmp_matrix[row(tmp_matrix)>=col(tmp_matrix)])
      contacts_total_new[1,4] = sum(contacts_total[1,14:17])
      contacts_total_new[4,1] = sum(contacts_total[14:17,1])
      contacts_total_new[2,4] = sum(contacts_total[2:3,14:17])
      contacts_total_new[4,2] = sum(contacts_total[14:17,2:3])
      contacts_total_new[3,4] = sum(contacts_total[4:13,14:17])
      contacts_total_new[4,3] = sum(contacts_total[14:17,4:13])
      
      # Go from total number of contacts back to mij: is the mean number of contacts made by members of age group i with members of age group j
      x_new_pop = data$demography_respicast$population_pyramid %>% filter(country == country_i) %>% 
        select(age_group,population) %>% deframe()
      x_new_pop = x_new_pop[c("0-4","5-14","15-64","65+")] # ensure right ordering
      contacts_recovered = contacts_total_new / x_new_pop
      
      ## obtain matrix such at average number of contacts per person equalt to one
      # Get total mean number of contacts per person
      total_nr_contacts_per_person = sum( contacts_total_new[ row(contacts_total_new)>=col(contacts_total_new) ] ) / sum(x_pop_vec)
      # Get a new contact matrix with only 4 age groups, such that average number of contacts per person equals to one
      x_pop_matrix = t(matrix(rep(x_new_pop,4), nrow=4))
      # The new contact matrix where elements are per person contacts between age group i and j such that the population-weighted average number of contacts is 1
      contacts_normalized = contacts_total_new / (x_pop_matrix * total_nr_contacts_per_person)
      
      contacts_normalized_all[[country_i]] = contacts_recovered
    }
  }
  
  # create EU average by summing all locations
  contacts_collect = contacts_normalized_all[[1]]*0
  collect_counter = 0
  for (country_i in names(contacts_normalized_all)) {
    contacts_collect = contacts_collect + contacts_normalized_all[[country_i]]
    collect_counter = collect_counter + 1
  }
  EU_contacts = contacts_collect / collect_counter
  
  # fix assymmetry
  x_new_pop = data$demography_respicast$population_pyramid %>% 
    group_by(age_group) %>% summarise(sum=sum(population)) %>% deframe()
  x_new_pop = x_new_pop[c("0-4","5-14","15-64","65+")]
  contacts_orig = EU_contacts
  contacts_new = NA*contacts_orig
  for (ii in 1:nrow(contacts_orig)){
    for (jj in 1:nrow(contacts_orig)){
      contacts_new[ii,jj] = (contacts_orig[ii,jj]*x_new_pop[ii] + contacts_orig[jj,ii]*x_new_pop[jj]) / (2*x_new_pop[ii])
    }
  }
  
  contacts_normalized_all[["EU"]] = contacts_new
  return(contacts_normalized_all)
}


get_contact_matrix <- function( country_in, options ){
  
  if (length( country_in )!=1 ){
    stop("country_in must be a single country")
  }
  
  if ( options$contact_data == "prem_polymod_2023"){
    
    file_contact_data <- paste0( path_core_functions, 
                                 "data/prem_extended_polymod/", country_in, "_2023.rds" )
    contact_data <- readRDS( file_contact_data )
    
    A_symmetric <- diag( contact_data$x_pop ) %*% contact_data$A 
    
    x_pop_model <- rep( NA, 10 )
    mat_transform <-  array( 0, c(length( contact_data$x_pop ), 10 ) )
    
    x_pop_model[1:3] <- contact_data$x_pop[1:3] 
    mat_transform[ 1:3, 1:3 ] <- diag( rep( 1, 3 ))
    
    #15-17yrs = 3/5 * 15-19yrs
    x_pop_model[ 4 ] <- 3/5*contact_data$x_pop[4] 
    mat_transform[ 4, 4 ] <- 3/5
    
    #18-24yrs = 2/5 * 15-19yrs + 20-24yrs
    x_pop_model[ 5 ] <- 2/5*contact_data$x_pop[4] + contact_data$x_pop[5]  
    mat_transform[ 4:5 , 5 ] <- c( 2/5, 1 )
    
    #25-49yrs = 25-29yrs +  30-34yrs +  35-39yrs +  40-44yrs  + 45-49yrs 
    x_pop_model[ 6 ] <- sum( contact_data$x_pop[6:10] ) 
    mat_transform[ 6:10, 6 ] <- 1
    
    #50-59yrs = 50-54yrs +  55-59yrs 
    x_pop_model[ 7 ] <- sum( contact_data$x_pop[11:12] )
    mat_transform[ 11:12, 7 ] <- 1
    
    #60-69yrs = 60-64yrs +  65-69yrs 
    x_pop_model[ 8 ] <- sum( contact_data$x_pop[13:14] )
    mat_transform[ 13:14, 8 ] <- 1
    
    #
    ratio_75to79yrs_over_75plus <- contact_data$x_pop_long[16]/contact_data$x_pop[16]
    ratio_80plus_over_75plus <- contact_data$x_pop_long[17]/contact_data$x_pop[16]
    
    #70-79yrs =  70-74yrs + 75-79yrs 
    x_pop_model[ 9 ] <- contact_data$x_pop[15] + ratio_75to79yrs_over_75plus * contact_data$x_pop[16]
    mat_transform[ 15:16, 9 ] <- c( 1, ratio_75to79yrs_over_75plus )
    ####
    # x_pop_model[ 9 ] <- contact_data$x_pop_long[15] + contact_data$x_pop_long[16]
    # mat_transform[ 15:16, 9 ] <- 1
    
    #80+yrs = 80+yrs
    x_pop_model[ 10 ] <- ratio_80plus_over_75plus * contact_data$x_pop[16]
    mat_transform[ 16, 10 ] <- ratio_80plus_over_75plus
    ####
    # x_pop_model[ 10 ] <- contact_data$x_pop_long[17]
    # mat_transform[ 17, 10 ] <- 1
    
    #normalise
    x_pop_model <- x_pop_model/sum( x_pop_model )
    
    A_sym_model <- t( mat_transform ) %*% A_symmetric %*% mat_transform
    
    mout <- list( A  = diag( 1/x_pop_model ) %*% A_sym_model, 
                  pi_vec = x_pop_model )
    
    # names( mout ) <- country_in
    
  }else{
    warning("Only 1 source for contact data implemented: prem_polymod_2023")
  }
  
  return( mout )
}
# res_matrix <- get_contact_matrix( "Norway", tibble( contact_data="prem_polymod_2023") )


squash_axis <- function(from, to, factor) { 
  # A transformation function that squashes the range of [from, to] by factor on a given axis 
  
  # Args:
  #   from: left end of the axis
  #   to: right end of the axis
  #   factor: the compression factor of the range [from, to]
  #
  # Returns:
  #   A transformation called "squash_axis", which is capsulated by trans_new() function
  
  trans <- function(x) {    
    # get indices for the relevant regions
    isq <- x > from & x < to
    ito <- x >= to
    
    # apply transformation
    x[isq] <- from + (x[isq] - from)/factor
    x[ito] <- from + (to - from)/factor + (x[ito] - to)
    
    return(x)
  }
  
  inv <- function(x) {
    
    # get indices for the relevant regions
    isq <- x > from & x < from + (to - from)/factor
    ito <- x >= from + (to - from)/factor
    
    # apply transformation
    x[isq] <- from + (x[isq] - from) * factor
    x[ito] <- to + (x[ito] - (from + (to - from)/factor))
    
    return(x)
  }
  
  # return the transformation
  return(scales::trans_new("squash_axis", trans, inv, domain = c(from, to)))
}
