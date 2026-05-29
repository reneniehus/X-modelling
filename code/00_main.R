# ---- |-Clear ----
gc() # clear environment & memory

# ---- |-Set up ----
source("code/01_main_supporting/setup.R")

# ---- |-load task specific settings ----
source("code/02_settings/settings_version0.R"); params=settings() # settings_version_X.R script to be changed by high-level user

# ---- |-sourcing support scripts ----
source("code/01_main_supporting/flu_functions.R")
source("code/01_main_supporting/load_flu_data.R")
source("code/01_main_supporting/gen_model_input.R")
source("code/01_main_supporting/run_model.R")
source("code/01_main_supporting/process_and_save.R")
source("code/01_main_supporting/send_report.R")

# ---- |-load flu data ----
data = load_flu_data( params, regenerate = F, new_from_online = F) # loads the data # regenerate=T recreates the data lists, new_from_online=T uses the online versions for recreation

# ---- |-generate model inputs ----
models_in = gen_model_input( params, data )
# ---- |-run flu models----
models_out = run_model( params, data , models_in ) # runs the model scripts

# ---- |-process and save model output ----

# ---- |-report ----

# ---- |-Run special analyses ("code/04_special_analyses/")

# ---- |-The end
# (temporary code for any quick checking)
models_in$data_timeseries_long 
models_in$data_season_summary

eyeballing(models_in, params, data, countries=NULL, seasons=NULL, interactive=F)
