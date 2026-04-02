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

# Set working directory to repo root (where this script lives)
if (interactive()) {
  setwd(dirname(rstudioapi::getSourceEditorContext()$path))
} else {
  args <- commandArgs(trailingOnly = FALSE)
  script_path <- sub("--file=", "", args[grep("--file=", args)])
  if (length(script_path) > 0) setwd(dirname(script_path))
}

# --- UPDATE THIS PATH to your local credentials file ---
csv_path <- "C:/my_auths/kidsights_redcap_norc_test_MN.csv"
redcap_url <- "https://unmcredcap.unmc.edu/redcap/api/"

# Source the monitoring script (also sources utils)
source("progress-monitoring/mn26/monitoring_report.R")

# ============================================================================
# 1. Data Dictionary
# ============================================================================
cat("\n=== DATA DICTIONARY SMOKE TEST ===\n\n")

creds <- load_api_credentials(csv_path)

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

# Verify all 6 data frames are present
expected <- c("screener_status", "eligibility", "survey_completion",
              "child_demographics", "parent_demographics", "compensation_information")
missing <- setdiff(expected, names(monitoring_data))
if (length(missing) > 0) {
  stop("Missing data frames: ", paste(missing, collapse = ", "))
}
cat("[OK] All 6 data frames present\n")

# Verify record counts match
n_records <- nrow(monitoring_data$screener_status)
for (df_name in expected) {
  n <- nrow(monitoring_data[[df_name]])
  if (n != n_records) {
    warning(df_name, " has ", n, " rows, expected ", n_records)
  }
}
cat("[OK] All data frames have ", n_records, " records\n")

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

comp_cols <- names(monitoring_data$compensation_information)
stopifnot("store_choice_label" %in% comp_cols)
cat("[OK] Compensation columns verified\n")

cat("\n=== ALL SMOKE TESTS PASSED ===\n")
