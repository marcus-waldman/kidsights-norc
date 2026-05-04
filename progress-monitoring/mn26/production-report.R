#' ---
#' title: "Kidsights Survey Monitoring Report"
#' ---

# Use renv for project-level package management
# if (interactive() || Sys.getenv("RSTUDIO_CONNECT") == "") {
#   renv::restore()
# }
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(labelled)
library(REDCapR)
library(httr)
library(here)
library(openxlsx)

# --- UPDATE THIS PATH to your local credentials file ---
# csv_path <- "local/api_keys/api_keys.csv"
redcap_url <- "https://unmcredcap.unmc.edu/redcap/api/"

# Source the monitoring script (also sources utils)
here::here("progress-monitoring/mn26/monitoring_report.R") %>% source()
here::here("progress-monitoring/mn26/utils/norc_summarise.R") %>% source()


# ============================================================================
# 1. Data Dictionary
# ============================================================================
cat("\n=== DATA DICTIONARY SMOKE TEST ===\n\n")

creds <- tribble(
  ~project                                                       , ~pid   ,
  "Kidsights Survey NORC 1"                                      , "8723" ,
  "Kidsights Survey NORC 2"                                      , "8724" ,
  "Kidsights Survey NORC 3"                                      , "8725" ,
  "Kidsights Survey NORC 4"                                      , "8726" ,
  "Incomplete REDCap Responses (Record Numbers &URLs) 21Apr2026" , "8792" ,
)

creds <- creds %>% mutate(api_code = Sys.getenv(pid))

# Expect exactly 4 projects in the MN 2026 credentials file
stopifnot(nrow(creds) == 5)
cat("[OK] Credentials file has ", nrow(creds), " projects\n", sep = "")

# MN-only dictionary (excludes @HIDDEN)
dict_mn <- get_data_dictionary(
  redcap_url,
  creds$api_code[2],
  exclude_hidden = TRUE
)

# Full dictionary (includes @HIDDEN)
dict_all <- get_data_dictionary(
  redcap_url,
  creds$api_code[2],
  exclude_hidden = FALSE
)

cat("Full dictionary fields: ", length(dict_all), "\n")
cat("MN dictionary fields:   ", length(dict_mn), "\n")
cat("Hidden fields excluded:  ", length(dict_all) - length(dict_mn), "\n")

# Spot-check a known field
stopifnot("cqr009" %in% names(dict_mn))
cat("\ncqr009 label: ", dict_mn[["cqr009"]]$field_label, "\n")
cat("cqr009 type:  ", dict_mn[["cqr009"]]$field_type, "\n")

# Verify @HIDDEN fields are excluded
stopifnot(!"age_in_days" %in% names(dict_mn))
stopifnot("age_in_days" %in% names(dict_all))
cat("\n[OK] @HIDDEN filtering verified\n")

# ============================================================================
# 2. Monitoring Report
# ============================================================================
cat("\n=== MONITORING REPORT SMOKE TEST ===\n\n")

monitoring_data <- generate_monitoring_report(creds = creds)

# Verify all 5 data frames are present
expected <- c(
  "eligibility_form",
  "survey_completion",
  "child_demographics",
  "parent_demographics",
  "compensation_information"
)
missing <- setdiff(expected, names(monitoring_data))
if (length(missing) > 0) {
  stop("Missing data frames: ", paste(missing, collapse = ", "))
}
cat("[OK] All 5 data frames present\n")

# Verify record counts match
n_records <- nrow(monitoring_data$eligibility_form)
for (df_name in expected) {
  n <- nrow(monitoring_data[[df_name]])
  if (n != n_records) {
    warning(df_name, " has ", n, " rows, expected ", n_records)
  }
}
cat("[OK] All data frames have ", n_records, " records\n")

# Verify redcap_project_name column is present in all 5 frames
for (df_name in expected) {
  if (!"redcap_project_name" %in% names(monitoring_data[[df_name]])) {
    stop(df_name, " is missing redcap_project_name column")
  }
}
cat("[OK] redcap_project_name present in all 5 data frames\n")

# Verify that all 4 projects from credentials show up in the outputs
n_projects_seen <- length(unique(
  monitoring_data$eligibility_form$redcap_project_name
))
if (n_projects_seen != nrow(creds)) {
  warning(
    "Expected ",
    nrow(creds),
    " distinct projects in outputs, found ",
    n_projects_seen
  )
}
cat(
  "[OK] ",
  n_projects_seen,
  " distinct projects represented in outputs\n",
  sep = ""
)

# Verify expected columns
child_cols <- names(monitoring_data$child_demographics)
stopifnot("sex_norc" %in% child_cols)
stopifnot("race_norc" %in% child_cols)
stopifnot("raceG_norc" %in% child_cols)
stopifnot("years_old_c2" %in% child_cols)
stopifnot("sex_c2_norc" %in% child_cols)
cat("[OK] Child demographics columns verified\n")

parent_cols <- names(monitoring_data$parent_demographics)
stopifnot("gender" %in% parent_cols)
stopifnot("race_ethnicity" %in% parent_cols)
stopifnot("education" %in% parent_cols)
stopifnot("marital_status_label_norc" %in% parent_cols)
cat("[OK] Parent demographics columns verified\n")

elig_form_cols <- names(monitoring_data$eligibility_form)
# Note: eq002/eq003/mn_eqstate live in the legacy `eligibility_form` instrument
# in production REDCap, NOT in `eligibility_form_norc`. extract_eligibility_form()
# only pulls fields whose form_name == "eligibility_form_norc", so the eq* fields
# are intentionally excluded from this output. They remain available in raw_data
# for calculate_eligibility() if needed.
stopifnot("age_in_days_n" %in% elig_form_cols)
stopifnot("dob_n" %in% elig_form_cols)
stopifnot("eligibility_form_norc_complete" %in% elig_form_cols)
cat("[OK] Eligibility form columns verified\n")

comp_cols <- names(monitoring_data$compensation_information)
stopifnot("store_choice_label" %in% comp_cols)
cat("[OK] Compensation columns verified\n")

# Per-project breakdown — eyeball that each project contributed sensibly
cat("\nRecords per REDCap project (from eligibility_form):\n")
print(table(
  monitoring_data$eligibility_form$redcap_project_name,
  useNA = "ifany"
))

cat("\n=== ALL SMOKE TESTS PASSED ===\n")


# ============================================================================
# 3. Daily summary output
# ============================================================================

# Inputs for summary function
id_xwalk <- here("progress-monitoring/mn26/data/id_xwalk.rds") %>%
  read_rds()

frame_child_demos <- here(
  "progress-monitoring/mn26/data/frame_child_demographic_summary.rds"
) %>%
  read_rds()

frame_mom_demos <- here(
  "progress-monitoring/mn26/data/frame_mother_demographic_summary.rds"
) %>%
  read_rds()

# A `record_id` will not have a `P_SUID` if it was determined by NCOA
# to be an underliverable address some time after the initial frame was drawn.
# These cases are not `in_scope`
id_xwalk <- monitoring_data$all_data %>%
  left_join(id_xwalk, by = c("record_id", "survey_link")) %>%
  select(all_of(names(id_xwalk)), everything()) %>%
  mutate(.before = everything(), in_scope = !is.na(P_SUID)) %>%
  select(in_scope:record_id)

# Run summary function
norc_summary <- monitoring_data %>%
  norc_summarise(id_xwalk, frame_child_demos, frame_mom_demos)


# # ============================================================================
# # 4. Weekly summary output (run Fridays)
# # ============================================================================

# UNMC Summary Report
if (weekdays(Sys.Date()) == "Friday") {
  # Projections calculated by Kanru
  proj_tbl <- tribble(
    ~`Week #` , ~`Week Ending` , ~proj ,
            1 , "2026-04-16"   ,   588 ,
            2 , "2026-04-23"   ,   735 ,
            3 , "2026-04-30"   ,   824 ,
            4 , "2026-05-07"   ,  1000 ,
  )

  weekly_comps <- p_drive("A343/Common/Sampling/Monitoring/reports/summary") %>%
    fs::dir_info() %>%
    mutate(date = as.Date(modification_time)) %>%
    filter(.by = date, modification_time == max(modification_time)) %>%
    filter(
      as.Date(modification_time) %in%
        {
          as.Date(proj_tbl$`Week Ending`) + 1
        }
    ) %>%
    mutate(path = path %>% set_names(date - 1)) %>%
    pull(path) %>%
    map(~ .x %>% readxl::read_excel() %>% slice(1) %>% pull(7))

  proj_tbl <- proj_tbl %>%
    mutate(actual = weekly_comps[`Week Ending`]) %>%
    unnest(actual, keep_empty = TRUE) %>%
    mutate(pct = scales::percent(actual / proj, 0.1))

  proj_tbl <- proj_tbl %>%
    rename(
      `Weekly Projected Completes` = proj,
      `Actual Completes` = actual,
      `% of Weekly Projection` = pct
    )

  wb <- createWorkbook()
  wb %>% addWorksheet("Sheet 1")
  wb %>% writeData("Sheet 1", proj_tbl)
  wb %>% addWorksheet("Sheet 2")
  wb %>% writeData("Sheet 2", norc_summary$summary_rates)
  wb %>%
    saveWorkbook(
      p_drive(
        "A343/Common/Sampling/Monitoring/reports/",
        paste0("weekly_summary_", format(Sys.time(), "%m%d%Y"), ".xlsx")
      ),
      overwrite = TRUE
    )
}

# Incentives
if (weekdays(Sys.Date()) == "Friday") {
  comps_all <- norc_summary$monitoring_data$compensation_information %>%
    filter(!is.na(store_choice_label)) %>%
    select(
      caseid = P_SUID,
      record_id,
      pin = P_PIN,
      email = email_incentive,
      type = store_choice_label
    ) %>%
    mutate(
      type = type %>%
        recode_values(
          "Amazon" ~ "AMZN",
          "Lowe's" ~ "LOWE",
          "Target" ~ "TRGT",
          "Walmart" ~ "WMRT",
          default = type
        )
    )

  comps_prior <- p_drive("A343/Common/Sampling/Monitoring/incentives") %>%
    list.files(full.names = TRUE, pattern = "csv") %>%
    discard(~ .x %>% str_detect("~")) %>%
    map(~ .x %>% readr::read_csv()) %>%
    list_rbind() %>%
    pull(caseid)

  enhanced_20 <- p_drive(
    "A343/Common/Sampling/Frame/minority_NR_target.csv"
  ) %>%
    read_csv()

  comps_all %>%
    filter(!caseid %in% comps_prior) %>%
    left_join(
      norc_summary$complete_ids %>%
        select(caseid = P_SUID, complete_date),
      by = "caseid"
    ) %>%
    mutate(
      amount = if_else(
        complete_date >= "2026-04-30" & record_id %in% enhanced_20$Record_ID,
        20,
        10
      )
    ) %>%
    readr::write_csv(
      p_drive(
        "A343/Common/Sampling/Monitoring/incentives",
        paste0(
          "kidsights_",
          format(Sys.time(), format(Sys.Date(), "%Y-%m-%d")),
          ".csv"
        )
      )
    )
}

# ============================================================================
# 5. Daily output
# ============================================================================

wb <- createWorkbook()

norc_summary$monitoring_data %>%
  purrr::iwalk(
    ~ {
      wb %>% addWorksheet(.y)
      wb %>% writeData(.y, .x)
    }
  )

wb %>%
  saveWorkbook(
    p_drive(
      "A343/Common/Sampling/Monitoring/reports/raw",
      paste0("kidsights_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
    ),
    overwrite = TRUE
  )

wb <- createWorkbook()

norc_summary %>%
  discard_at("monitoring_data") %>%
  purrr::iwalk(
    ~ {
      wb %>% addWorksheet(.y)
      wb %>% writeData(.y, .x)
    }
  )

wb %>%
  saveWorkbook(
    p_drive(
      "A343/Common/Sampling/Monitoring/reports/summary",
      paste0("kidsights_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
    ),
    overwrite = TRUE
  )
