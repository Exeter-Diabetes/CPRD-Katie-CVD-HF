
# Produce survival variables for all endpoints (including for sensitivity analysis)
## All censored at 5 years post drug start (3 years for 'ckd_egfr40') / end of GP records / death / starting a different diabetes med which affects CV risk (TZD/GLP1/SGLT2), and also drug stop date + 6 months for per-protocol analysis

# Main analysis:
## 'mace': stroke, MI, CV death
## 'expanded_mace': stroke, MI, CV death, revasc, HES unstable angina
## 'hf'
## 'hosp': all-cause hospitalisation
## 'death': all-cause mortality

# Sensitivity analysis:
## 'narrow_mace': hospitalisation for incident MI (subset of HES codes), incident stroke (subset of HES codes, includes ischaemic only), CV death - all as primary cause for hospitalisation/death only
## 'narrow_hf': hospitalisation or death with HF as primary cause
## '{outcome}_pp': all of main analysis but per-protocol rather than intention to treat


add_surv_vars <- function(cohort_dataset, main_only=FALSE) {
  
  # Add survival variables for outcomes for main analysis
  main_outcomes <- c("mace", "expanded_mace", "hf", "hosp", "death")
  
  cohort <- cohort_dataset %>%
    
    mutate(cens_itt=pmin(dstartdate+(365.25*5),
                         gp_record_end,
                         death_date,
                         next_tzd_start,
                         next_glp1_start,
                         if_else(studydrug!="SGLT2", next_sglt2_start, as.Date("2050-01-01")),
                         na.rm=TRUE),
           
           cens_pp=pmin(dstartdate+(365.25*5),
                        gp_record_end,
                        death_date,
                        next_tzd_start,
                        next_glp1_start,
                        if_else(studydrug!="SGLT2", next_sglt2_start, as.Date("2050-01-01")),
                        dstopdate+183,
                        na.rm=TRUE),
           
           mace_outcome=pmin(postdrug_first_myocardialinfarction,
                             postdrug_first_stroke,
                             cv_death_date_any_cause,
                             na.rm=TRUE),
          
           expanded_mace_outcome=pmin(postdrug_first_myocardialinfarction,
                                      postdrug_first_stroke,
                                      cv_death_date_any_cause,
                                      postdrug_first_revasc,
                                      postdrug_first_unstableangina,
                                      na.rm=TRUE),
             
           hf_outcome=pmin(postdrug_first_heartfailure,
                           hf_death_date_any_cause,
                           na.rm=TRUE),
           
           hosp_outcome=postdrug_first_all_cause_hosp,
           
           death_outcome=death_date)
  
  
  for (i in main_outcomes) {

    outcome_var=paste0(i, "_outcome")
    censdate_var=paste0(i, "_censdate")
    censvar_var=paste0(i, "_censvar")
    censtime_var=paste0(i, "_censtime_yrs")

    cohort <- cohort %>%
      mutate({{censdate_var}}:=pmin(!!sym(outcome_var), cens_itt, na.rm=TRUE),
             {{censvar_var}}:=ifelse(!is.na(!!sym(outcome_var)) & !!sym(censdate_var)==!!sym(outcome_var), 1, 0),
             {{censtime_var}}:=as.numeric(difftime(!!sym(censdate_var), dstartdate, unit="days"))/365.25)
    
    
  }
  
  if (main_only==TRUE) {
    message(paste("survival variables for", paste(main_outcomes, collapse=", "), "added"))
    }
  
  
  # Add survival variables for outcomes for sensitivity analyses
 
  else {
    
    # Split by whether ITT or PP
    sensitivity_outcomes <- list(c("narrow_mace", "narrow_hf"), c("mace_pp", "expanded_mace_pp", "hf_pp", "hosp_pp", "death_pp"))
    
    cohort <- cohort %>%
      
      mutate(narrow_mace_outcome=pmin(postdrug_first_incident_mi,
                                      postdrug_first_incident_stroke,
                                      cv_death_date_primary_cause,
                                      na.rm=TRUE),
             
             narrow_hf_outcome=pmin(postdrug_first_primary_hhf,
                                    hf_death_date_primary_cause,
                                    na.rm=TRUE))
    
    
    for (i in unlist(sensitivity_outcomes)) {

      censdate_var=paste0(i, "_censdate")
      censvar_var=paste0(i, "_censvar")
      censtime_var=paste0(i, "_censtime_yrs")


      if (i %in% sensitivity_outcomes[[1]]==TRUE) {
        
        outcome_var=paste0(i, "_outcome")
        
        cohort <- cohort %>%
          mutate({{censdate_var}}:=pmin(!!sym(outcome_var), cens_itt, na.rm=TRUE))
        }

      if (i %in% sensitivity_outcomes[[2]]==TRUE) {
        
        outcome_var=paste0(substr(i, 1,  nchar(i)-3), "_outcome")
        
        cohort <- cohort %>%
            mutate({{censdate_var}}:=pmin(!!sym(outcome_var), cens_pp, na.rm=TRUE))
        
                 
      }

      cohort <- cohort %>%
        mutate({{censvar_var}}:=ifelse(!is.na(!!sym(outcome_var)) & !!sym(censdate_var)==!!sym(outcome_var), 1, 0),
               {{censtime_var}}:=as.numeric(difftime(!!sym(censdate_var), dstartdate, unit="days"))/365.25)

      }

    if (main_only==FALSE) {
      message(paste("survival variables for", paste(main_outcomes, collapse=", "), ",", paste(unlist(sensitivity_outcomes), collapse=", "), "added"))
      }
    
    }
   
return(cohort) 
  
  }
  