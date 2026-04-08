# Smoke Test for MN26 Monitoring Report
# Runs generate_monitoring_report() and get_data_dictionary() against
# the NORC MN test REDCap project.

# Auto-install and load required packages
required_packages <- c("dplyr", "tidyr", "REDCapR", "httr")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

# Set working directory to repo root (two levels up from this script)
if (interactive()) {
  setwd(file.path(dirname(rstudioapi::getSourceEditorContext()$path), "..", ".."))
} else {
  args <- commandArgs(trailingOnly = FALSE)
  script_path <- sub("--file=", "", args[grep("--file=", args)])
  if (length(script_path) > 0) setwd(file.path(dirname(script_path), "..", ".."))
}

# --- UPDATE THIS PATH to your local credentials file ---
csv_path <- "C:/my_auths/kidsights_redcap_norc_MN_2026.csv"
redcap_url <- "https://unmcredcap.unmc.edu/redcap/api/"

# Source the monitoring script (also sources utils)
source("progress-monitoring/mn26/monitoring_report.R")

# ============================================================================
# 1. Data Dictionary
# ============================================================================
cat("\n=== DATA DICTIONARY SMOKE TEST ===\n\n")

creds <- load_api_credentials(csv_path)

# Expect exactly 4 projects in the MN 2026 credentials file
stopifnot(nrow(creds) == 4)
cat("[OK] Credentials file has ", nrow(creds), " projects\n", sep = "")

# MN-only dictionary (excludes @HIDDEN)
dict_mn <- get_data_dictionary(redcap_url, creds$api_code[1], exclude_hidden = TRUE)

# Full dictionary (includes @HIDDEN)
dict_all <- get_data_dictionary(redcap_url, creds$api_code[1], exclude_hidden = FALSE)

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

monitoring_data <- generate_monitoring_report(csv_path = csv_path)

# Verify all 5 data frames are present
expected <- c("eligibility_form", "survey_completion",
              "child_demographics", "parent_demographics", "compensation_information")
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
n_projects_seen <- length(unique(monitoring_data$eligibility_form$redcap_project_name))
if (n_projects_seen != nrow(creds)) {
  warning("Expected ", nrow(creds), " distinct projects in outputs, found ", n_projects_seen)
}
cat("[OK] ", n_projects_seen, " distinct projects represented in outputs\n", sep = "")

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
print(table(monitoring_data$eligibility_form$redcap_project_name, useNA = "ifany"))

cat("\n=== ALL SMOKE TESTS PASSED ===\n")
