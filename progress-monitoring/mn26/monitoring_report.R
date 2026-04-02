#' MN26 Sample Monitoring Report
#'
#' Standalone script for NORC researchers to monitor MN26 recruitment progress
#' and demographic distribution during data collection.
#'
#' Updated for MN26 NORC field names and value codes.
#' Variables with _norc suffix indicate MN26-specific coding that differs from NE25.
#'
#' [MN26 TODO] MULTI-CHILD HOUSEHOLDS: MN26 allows up to 2 children per household.
#' The current code assumes 1 child per record (NE25 structure). When MN26 data is
#' available, the child demographics and eligibility logic must be updated to handle
#' multiple children per record. This may require pivoting to long format (1 row per
#' child) or adding child-specific columns (e.g., age_in_days_child1, age_in_days_child2).
#' The REDCap structure (repeating instruments vs. separate fields) will determine approach.
#'
#' [MN26 TODO] GEOGRAPHY: Participant mailing addresses (where invitations were sent)
#' can be linked via pid + record_id from a separate address dataset. Future versions
#' may add geocoding (tidygeocoder + Census Bureau geocoder) to derive lat/long, county,
#' census tract, PUMA, and urban/rural classifications for geographic monitoring.
#'
#' Usage:
#'   source("scripts/mn26/monitoring_report.R")
#'   monitoring_data <- generate_monitoring_report(csv_path = "C:/path/to/mn26_api.csv")
#'
#' Returns:
#'   List with 6 data frames:
#'     - screener_status: Screener completion (eligibility known/unknown)
#'     - eligibility: Eligibility determination (4 criteria)
#'     - survey_completion: Survey module completion status
#'     - child_demographics: Child age and sex
#'     - parent_demographics: Parent age, sex, race/ethnicity, education, marital status

# ============================================================================
# SETUP
# ============================================================================

# Load required packages
library(dplyr)
library(tidyr)
library(REDCapR)
library(httr)

# ============================================================================
# LOAD UTILITY FUNCTIONS
# ============================================================================

# Get the directory where this script is located
script_dir <- if (sys.nframe() == 0) {
  # Running interactively or via source()
  dirname(sys.frame(1)$ofile)
} else {
  # Running via Rscript
  dirname(normalizePath(sys.frame(1)$ofile))
}

# Source utility files (self-contained, no external dependencies)
source(file.path(script_dir, "utils", "safe_joins.R"))
source(file.path(script_dir, "utils", "redcap_utils.R"))
source(file.path(script_dir, "utils", "data_transforms.R"))

# ============================================================================
# STUDY-SPECIFIC FUNCTIONS
# ============================================================================

#' Calculate eligibility status
#'
#' Determines eligibility based on 4 criteria:
#' 1. Parent age >= 19
#' 2. Child age 0-5 years
#' 3. Primary caregiver = Yes
#' 4. Lives in Minnesota
#'
#' [MN26 TODO] Update variable names once MN26 data dictionary is available
#'
#' @param data Raw or transformed REDCap data
#' @return Data frame with eligibility columns
calculate_eligibility <- function(data) {

  message("Calculating eligibility...")

  eligibility_df <- data %>%
    dplyr::mutate(
      # Criterion 1: Parent age >= 19
      parent_age_eligible = (eq003 == 1) & !is.na(eq003),

      # Criterion 2: Child age 0-5 years (1825 days)
      # [MN26 TODO] MULTI-CHILD: Check age eligibility per child (up to 2 per household)
      child_age_eligible = (age_in_days_n <= 1825) & !is.na(age_in_days_n),

      # Criterion 3: Primary caregiver = Yes
      primary_caregiver_eligible = (eq002 == 1) & !is.na(eq002),

      # Criterion 4: Lives in Minnesota
      state_eligible = (mn_eqstate == 1) & !is.na(mn_eqstate),

      # Overall eligibility
      eligible = parent_age_eligible & child_age_eligible &
                 primary_caregiver_eligible & state_eligible
    ) %>%
    dplyr::select(
      pid, record_id,
      parent_age_eligible, child_age_eligible,
      primary_caregiver_eligible, state_eligible,
      eligible
    )

  message("[OK] Eligibility: ",
          sum(eligibility_df$eligible, na.rm = TRUE), " eligible, ",
          sum(!eligibility_df$eligible, na.rm = TRUE), " not eligible")

  return(eligibility_df)
}

#' Calculate screener completion status
#'
#' Screener is "complete" if eligibility is known (not missing)
#'
#' @param eligibility_data Data frame from calculate_eligibility()
#' @return Data frame with screener completion status
calculate_screener_status <- function(eligibility_data) {

  message("Calculating screener completion status...")

  screener_df <- eligibility_data %>%
    dplyr::mutate(
      screener_complete = !is.na(eligible),
      screener_status = ifelse(screener_complete, "Complete", "Incomplete")
    ) %>%
    dplyr::select(pid, record_id, screener_complete, screener_status)

  message("[OK] Screener: ",
          sum(screener_df$screener_complete, na.rm = TRUE), " complete, ",
          sum(!screener_df$screener_complete, na.rm = TRUE), " incomplete")

  return(screener_df)
}

#' Calculate survey completion status
#'
#' Survey is "complete" if all required instruments (1-25) are marked complete
#' (status = 2). The denominator is per-participant because child 2 modules and
#' NSCH questions are conditionally required.
#'
#' MN26 instrument order (per Vinod, 2026-04-02):
#'   1. Consent Doc
#'   2. Eligibility Form NORC
#'   3. Family Information
#'   4. Child Information
#'   5-12. Module 6 age bands (child 1) — one per child's age
#'   13. NSCH Questions (child 1) — only if age 365-1065 days
#'   14. Child Information 2 — only if dob_c2_n not empty
#'   15-22. Module 6 age bands (child 2) — only if child 2 exists
#'   23. NSCH Questions 2 — only if child 2 + age 365-1065 days
#'   24. Compensation
#'   25. Follow-up
#'   26-29. IGNORED (old NE25 instruments, disconnected)
#'
#' @param data Raw REDCap data
#' @return Data frame with survey completion status
calculate_survey_completion <- function(data) {

  message("Calculating survey completion status...")

  # Helper: check if a column == 2 (complete), NA-safe
  is_complete <- function(x) !is.na(x) & x == 2

  # --- Always-required instruments ---
  always_required <- c(
    "consent_doc_complete",
    "eligibility_form_norc_complete",
    "module_2_family_information_complete",
    "module_3_child_information_complete",
    "module_9_compensation_information_complete",
    "module_8_followup_information_complete"
  )
  always_available <- intersect(always_required, names(data))

  # --- Module 6 child 1: collapse age-band sub-instruments ---
  # Match module_6_*_complete but NOT module_6_*_2_complete (child 2)
  m6_c1_cols <- grep("^module_6_(?!.*_2_complete).*_complete$", names(data),
                     value = TRUE, perl = TRUE)

  # --- Module 6 child 2: collapse age-band sub-instruments ---
  m6_c2_cols <- grep("^module_6_.*_2_complete$", names(data), value = TRUE)

  # --- Build completion data frame ---
  # Grab all columns we might need
  all_cols <- unique(c(always_available, m6_c1_cols, m6_c2_cols,
                       "nsch_questions_complete", "child_information_2_954c_complete",
                       "nsch_questions_2_complete",
                       "age_in_days_n", "age_in_days_c2_n", "dob_c2_n"))
  avail_cols <- intersect(all_cols, names(data))

  completion_df <- data %>%
    dplyr::select(pid, record_id, dplyr::any_of(avail_cols))

  n <- nrow(completion_df)

  # Collapse module 6 child 1: complete if any age-band sub-instrument == 2
  if (length(m6_c1_cols) > 0) {
    completion_df$m6_c1_complete <- apply(
      completion_df[, intersect(m6_c1_cols, names(completion_df)), drop = FALSE], 1,
      function(x) ifelse(any(x == 2, na.rm = TRUE), 2, NA_real_)
    )
  } else {
    completion_df$m6_c1_complete <- NA_real_
  }

  # Collapse module 6 child 2: complete if any age-band sub-instrument == 2
  if (length(m6_c2_cols) > 0) {
    completion_df$m6_c2_complete <- apply(
      completion_df[, intersect(m6_c2_cols, names(completion_df)), drop = FALSE], 1,
      function(x) ifelse(any(x == 2, na.rm = TRUE), 2, NA_real_)
    )
  } else {
    completion_df$m6_c2_complete <- NA_real_
  }

  # --- Per-participant conditional flags ---
  # Child 2 exists if dob_c2_n is non-empty
  has_c2 <- if ("dob_c2_n" %in% names(completion_df)) {
    !is.na(completion_df$dob_c2_n) & completion_df$dob_c2_n != ""
  } else {
    rep(FALSE, n)
  }

  # NSCH child 1 required if age 365-1065 days
  nsch_c1_req <- if ("age_in_days_n" %in% names(completion_df)) {
    !is.na(completion_df$age_in_days_n) &
      completion_df$age_in_days_n >= 365 &
      completion_df$age_in_days_n <= 1065
  } else {
    rep(FALSE, n)
  }

  # NSCH child 2 required if child 2 exists AND age 365-1065 days
  nsch_c2_req <- if ("age_in_days_c2_n" %in% names(completion_df)) {
    has_c2 &
      !is.na(completion_df$age_in_days_c2_n) &
      completion_df$age_in_days_c2_n >= 365 &
      completion_df$age_in_days_c2_n <= 1065
  } else {
    rep(FALSE, n)
  }

  # --- Count completed modules per participant ---
  # Always-required (non-module-6)
  n_always_done <- rowSums(
    sapply(always_available, function(col) is_complete(completion_df[[col]])),
    na.rm = TRUE
  )

  # Module 6 child 1
  m6_c1_done <- is_complete(completion_df$m6_c1_complete)

  # NSCH child 1 (only counts if required)
  nsch_c1_col <- if ("nsch_questions_complete" %in% names(completion_df)) {
    completion_df$nsch_questions_complete
  } else {
    rep(NA_real_, n)
  }
  nsch_c1_done <- nsch_c1_req & is_complete(nsch_c1_col)

  # Child 2 info
  c2_info_col <- if ("child_information_2_954c_complete" %in% names(completion_df)) {
    completion_df$child_information_2_954c_complete
  } else {
    rep(NA_real_, n)
  }
  c2_info_done <- has_c2 & is_complete(c2_info_col)

  # Module 6 child 2
  m6_c2_done <- has_c2 & is_complete(completion_df$m6_c2_complete)

  # NSCH child 2 (only counts if required)
  nsch_c2_col <- if ("nsch_questions_2_complete" %in% names(completion_df)) {
    completion_df$nsch_questions_2_complete
  } else {
    rep(NA_real_, n)
  }
  nsch_c2_done <- nsch_c2_req & is_complete(nsch_c2_col)

  # --- Per-participant denominator ---
  n_required <- length(always_available) + 1L  # always-required + module 6 child 1
  n_required <- n_required + as.integer(nsch_c1_req)
  n_required <- n_required + as.integer(has_c2) * 2L  # child info 2 + module 6 child 2
  n_required <- n_required + as.integer(nsch_c2_req)

  # --- Total completed ---
  modules_complete <- as.integer(n_always_done) + as.integer(m6_c1_done) +
    as.integer(nsch_c1_done) + as.integer(c2_info_done) +
    as.integer(m6_c2_done) + as.integer(nsch_c2_done)

  # --- Build result ---
  completion_df$n_required <- n_required
  completion_df$modules_complete <- modules_complete
  completion_df$pct_complete <- round(modules_complete / n_required * 100, 1)
  completion_df$survey_complete <- (modules_complete == n_required)
  completion_df$survey_status <- ifelse(completion_df$survey_complete, "Complete", "Incomplete")

  # --- Last completed module (in instrument order) ---
  ordered <- list(
    list(col = "consent_doc_complete",                    label = "Consent"),
    list(col = "eligibility_form_norc_complete",          label = "Eligibility"),
    list(col = "module_2_family_information_complete",    label = "Family Info"),
    list(col = "module_3_child_information_complete",     label = "Child Info"),
    list(col = "m6_c1_complete",                          label = "Module 6 (C1)"),
    list(col = "nsch_questions_complete",                 label = "NSCH (C1)"),
    list(col = "child_information_2_954c_complete",       label = "Child Info 2"),
    list(col = "m6_c2_complete",                          label = "Module 6 (C2)"),
    list(col = "nsch_questions_2_complete",               label = "NSCH (C2)"),
    list(col = "module_9_compensation_information_complete", label = "Compensation"),
    list(col = "module_8_followup_information_complete",  label = "Follow-up")
  )

  last_module <- rep(NA_character_, n)
  for (item in ordered) {
    if (item$col %in% names(completion_df)) {
      done <- is_complete(completion_df[[item$col]])
      last_module[done] <- item$label
    }
  }
  completion_df$last_module_complete <- last_module

  result <- completion_df %>%
    dplyr::select(pid, record_id, n_required, modules_complete, pct_complete,
                  last_module_complete, survey_complete, survey_status)

  message("[OK] Survey: ",
          sum(result$survey_complete, na.rm = TRUE), " complete, ",
          sum(!result$survey_complete, na.rm = TRUE), " incomplete")

  return(result)
}

#' Extract child demographics
#'
#' [MN26 TODO] MULTI-CHILD: MN26 allows up to 2 children per household.
#' This function currently returns 1 row per record (1 child). For MN26,
#' pivot to long format so each child gets its own row, with a child_number
#' column (1 or 2) to distinguish them. Child-level eligibility (age 0-5)
#' should also be checked per child.
#'
#' @param data Transformed data
#' @return Data frame with child age and sex
extract_child_demographics <- function(data) {

  message("Extracting child demographics...")

  child_demo <- data %>%
    dplyr::select(pid, record_id,
                  age_years = years_old,
                  sex_norc,
                  race_norc, hisp, raceG_norc,
                  dplyr::any_of(c(
                    "years_old_c2", "sex_c2_norc",
                    "race_c2_norc", "hisp_c2", "raceG_c2_norc"
                  )))

  message("[OK] Child demographics: ", nrow(child_demo), " records")
  return(child_demo)
}

#' Extract parent demographics
#'
#' @param data Transformed data
#' @return Data frame with parent demographics
extract_parent_demographics <- function(data) {

  message("Extracting parent demographics...")

  parent_demo <- data %>%
    dplyr::select(pid, record_id,
                  age_years = a1_years_old,
                  gender = a1_gender_norc,
                  race_ethnicity = a1_raceG_norc,
                  education = educ_a1_norc,
                  marital_status_label_norc)

  message("[OK] Parent demographics: ", nrow(parent_demo), " records")
  return(parent_demo)
}

#' Extract compensation information
#'
#' @param data Transformed data
#' @return Data frame with gift card and contact info
extract_compensation_information <- function(data) {

  message("Extracting compensation information...")

  comp <- data %>%
    dplyr::select(pid, record_id,
                  dplyr::any_of(c("store_choice_label",
                                  "q1394", "q1394a", "email_incentive")))

  message("[OK] Compensation information: ", nrow(comp), " records")
  return(comp)
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

#' Generate monitoring report
#'
#' Main function that orchestrates all monitoring components.
#' Pass the path to your API credentials CSV and it does everything.
#'
#' @param csv_path Path to API credentials CSV file (columns: project, pid, api_code)
#' @param redcap_url REDCap API URL (defaults to UNMC REDCap instance)
#' @return List with 6 data frames
#' @export
generate_monitoring_report <- function(csv_path,
                                      redcap_url = "https://unmcredcap.unmc.edu/redcap/api/") {

  cat("\n=== MN26 SAMPLE MONITORING REPORT ===\n\n")

  # Step 1: Load API credentials
  credentials <- load_api_credentials(csv_path)

  # Step 2: Pull raw data from REDCap
  api_result <- pull_redcap_data(credentials, redcap_url)
  raw_data <- api_result$data
  dictionary <- api_result$dictionary

  # Step 3: Transform raw data into monitoring variables
  transformed_data <- transform_raw_data(raw_data, dictionary)

  # Step 4: Calculate eligibility
  eligibility <- calculate_eligibility(raw_data)

  # Step 5: Calculate screener completion
  screener_status <- calculate_screener_status(eligibility)

  # Step 6: Calculate survey completion
  survey_completion <- calculate_survey_completion(raw_data)

  # Step 7: Extract demographics
  child_demographics <- extract_child_demographics(transformed_data)
  parent_demographics <- extract_parent_demographics(transformed_data)

  # Step 8: Extract compensation information
  compensation_information <- extract_compensation_information(transformed_data)

  # Return organized results
  results <- list(
    screener_status = screener_status,
    eligibility = eligibility,
    survey_completion = survey_completion,
    child_demographics = child_demographics,
    parent_demographics = parent_demographics,
    compensation_information = compensation_information
  )

  cat("\n=== MONITORING REPORT COMPLETE ===\n")
  cat("Access data frames:\n")
  cat("  - $screener_status (", nrow(screener_status), " records)\n", sep = "")
  cat("  - $eligibility (", nrow(eligibility), " records)\n", sep = "")
  cat("  - $survey_completion (", nrow(survey_completion), " records)\n", sep = "")
  cat("  - $child_demographics (", nrow(child_demographics), " records)\n", sep = "")
  cat("  - $parent_demographics (", nrow(parent_demographics), " records)\n", sep = "")
  cat("  - $compensation_information (", nrow(compensation_information), " records)\n\n", sep = "")

  return(results)
}

# ============================================================================
# EXAMPLE USAGE (uncomment to run)
# ============================================================================
#
# # 1. Create API credentials CSV file (see mn26_redcap_api_template.csv)
# #    Format: project,pid,api_code
# #    Example: mn26_main_survey,7679,ABC123XYZ...
#
# csv_file_path = "C:/Users/marcu/my-APIs/kidsights_redcap_api.csv"
#
# # 2. Generate monitoring report
# monitoring_data <- generate_monitoring_report(csv_path = csv_file_path)
#
# # View screener completion summary
# table(monitoring_data$screener_status$screener_status)
#
# # View eligibility summary
# table(monitoring_data$eligibility$eligible)
#
# # View survey completion summary
# table(monitoring_data$survey_completion$survey_status)
#
# # View child demographics
# head(monitoring_data$child_demographics)
# summary(monitoring_data$child_demographics$age_years)
# table(monitoring_data$child_demographics$sex)
#
# # View parent demographics
# head(monitoring_data$parent_demographics)
# summary(monitoring_data$parent_demographics$age_years)
# table(monitoring_data$parent_demographics$race_ethnicity)
# table(monitoring_data$parent_demographics$education)
# table(monitoring_data$parent_demographics$marital_status_label_norc)
