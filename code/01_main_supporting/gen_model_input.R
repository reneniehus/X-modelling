gen_model_input = function( params=NULL , data=NULL ){
  t1 <- Sys.time()
  # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  ### Initiating output list ##########
  # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  df_out = list(
    time_of_execution = now(),    # time-stamp
    duration = NULL              # execution duration
  )
  
  # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  ### Generate model input ##########
  # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  ## ---- |-Data for each season ----
  df_out$data_all_season = data_into_all_season( data,params,withforce=F )
  ## ---- |-Contacts ----
  df_out$contacts = transform_contracts(data,params) # transform the contact matrixes for model requirements
  
  #### output
  t2 <- Sys.time()
  df_out$duration = get_in_hms(t2, t1)
  return(df_out)
}
