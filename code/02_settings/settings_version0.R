settings = function() {
  params = list()
  
  # ---- |-Run modes ----
  params$save_submission = F # T: saves the file ready for respicompass, F; will be faster
  
  # debug/fast modes
  params$rapid_stan_fit = T # T: runs scripts with settings that reduce run-time
  
  # ---- |-Resport setting ----
  params$send_report = T
  params$report_recipients = c('rene.niehus@ecdc.europa.eu')
  
  # ---- |-Names/identifiers ----
  params$four_age_groups = c("0-4","5-14","15-64","65+") # the order is important
  
  # ---- |-Disease parameters ----
  params$Rnull = 1.5 # 
  
  # immunity parameters
  params$ve_spread = 0.20 # vaccine effect on onward spread when vaccinated individual is infected
  
  # ---- |-Data ----
  params$latest_start_year = 2024 # if the last partly/fully observed season is 2024/25, put 2024
  
  # ---- |-Simulations ----
  params$simulation_seed = 12
  
  # ---- |-Countries ----
  params$run_countries = "IT"
  
  # ---- |-Model-specific  settings ----
  
  # ---- |-Fitting and uncertainty ----
  
  # ---- |-Flu scenarios ----
  
  # ---- |-Folder paths ----
  
  return(params)
}

 



