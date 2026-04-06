# Synthetic Data Test Suite for MN26 Monitoring Pipeline
#
# Runs entirely offline — no REDCap API access needed.
# Generates synthetic raw data covering all valid codebook values and edge cases,
# then feeds it through each pipeline function to catch silent failures.
#
# Usage:
#   Rscript progress-monitoring/mn26/synthetic-test.R
#   # or in R console:
#   source("progress-monitoring/mn26/synthetic-test.R")

# ============================================================================
# SETUP
# ============================================================================

required_packages <- c("dplyr", "tidyr")
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

# Source pipeline (loads all utils)
source("progress-monitoring/mn26/monitoring_report.R")

# Track test counts
tests_passed <- 0L
tests_total <- 0L

assert_true <- function(expr, msg = "") {
  tests_total <<- tests_total + 1L
  if (!isTRUE(expr)) stop("[FAIL] ", msg)
  tests_passed <<- tests_passed + 1L
}

assert_equal <- function(actual, expected, msg = "") {
  tests_total <<- tests_total + 1L
  if (!identical(actual, expected)) {
    stop("[FAIL] ", msg, "\n  Expected: ", deparse(expected), "\n  Actual:   ", deparse(actual))
  }
  tests_passed <<- tests_passed + 1L
}

assert_na <- function(x, msg = "") {
  tests_total <<- tests_total + 1L
  if (!is.na(x)) {
    stop("[FAIL] ", msg, "\n  Expected NA, got: ", deparse(x))
  }
  tests_passed <<- tests_passed + 1L
}

# ============================================================================
# SYNTHETIC DATA BUILDER
# ============================================================================

#' Build a synthetic raw data frame mimicking REDCap output
#'
#' @param n Number of rows
#' @param overrides Named list; each element replaces the default column
#' @return Data frame with all columns the pipeline consumes
build_synthetic_raw <- function(n = 1, overrides = list()) {

  df <- data.frame(
    # --- Identifiers ---
    pid = seq_len(n),
    record_id = seq_len(n),
    source_project = rep("synthetic_test", n),

    # --- Eligibility ---
    eq003 = rep(1, n),
    age_in_days_n = rep(1500, n),      # outside NSCH range (365-1065)
    eq002 = rep(1, n),
    mn_eqstate = rep(1, n),

    # --- Child 1 demographics ---
    cqr009 = rep(0, n),            # 0=Male

    # --- Parent demographics ---
    mn2 = rep(0, n),               # 0=Female
    cqr003 = rep(30, n),           # parent age
    cqr004 = rep(6, n),            # education (Bachelor's)
    cqfa001 = rep(0, n),           # marital (Married)

    # --- Parent race checkboxes ---
    sq002b___100 = rep(0, n),
    sq002b___101 = rep(0, n),
    sq002b___102 = rep(0, n),
    sq002b___103 = rep(0, n),
    sq002b___104 = rep(1, n),      # White
    sq002b___105 = rep(0, n),
    sq003 = rep(0, n),             # non-Hispanic

    # --- Child 1 race checkboxes ---
    cqr010b___100 = rep(0, n),
    cqr010b___101 = rep(0, n),
    cqr010b___102 = rep(0, n),
    cqr010b___103 = rep(0, n),
    cqr010b___104 = rep(1, n),     # White
    cqr010b___105 = rep(0, n),
    cqr011 = rep(0, n),            # non-Hispanic

    # --- Child 2 ---
    dob_c2_n = rep("", n),
    age_in_days_c2_n = rep(NA_real_, n),
    cqr009_c2 = rep(NA_real_, n),
    cqr010_c2b___100 = rep(NA_real_, n),
    cqr010_c2b___101 = rep(NA_real_, n),
    cqr010_c2b___102 = rep(NA_real_, n),
    cqr010_c2b___103 = rep(NA_real_, n),
    cqr010_c2b___104 = rep(NA_real_, n),
    cqr010_c2b___105 = rep(NA_real_, n),
    cqr011_c2 = rep(NA_real_, n),

    # --- Compensation ---
    store_choice = rep(1, n),
    q1394 = rep(NA_character_, n),
    q1394a = rep(NA_character_, n),
    email_incentive = rep(NA_character_, n),

    # --- Always-required survey instruments (2 = complete) ---
    consent_doc_complete = rep(2, n),
    eligibility_form_norc_complete = rep(2, n),
    module_2_family_information_complete = rep(2, n),
    module_3_child_information_complete = rep(2, n),
    module_9_compensation_information_complete = rep(2, n),
    module_8_followup_information_complete = rep(2, n),

    # --- Module 6 child 1 (one age-band column) ---
    module_6_0to3_complete = rep(2, n),

    # --- Conditional instruments ---
    nsch_questions_complete = rep(NA_real_, n),
    child_information_2_954c_complete = rep(NA_real_, n),
    nsch_questions_2_complete = rep(NA_real_, n),
    module_6_0to3_2_complete = rep(NA_real_, n),

    stringsAsFactors = FALSE
  )

  # Apply overrides
  for (col_name in names(overrides)) {
    val <- overrides[[col_name]]
    if (length(val) == 1) val <- rep(val, n)
    if (length(val) != n) stop("Override '", col_name, "' must have length 1 or ", n)
    df[[col_name]] <- val
  }

  return(df)
}

# ============================================================================
# TEST SECTION 1: ELIGIBILITY
# ============================================================================
cat("\n=== 1. ELIGIBILITY ===\n")

elig_df <- build_synthetic_raw(n = 7, overrides = list(
  # Row 1: happy path (all eligible)
  # Row 2: all NA
  eq003         = c(1, NA, 0, 1, 1, 1, 1),
  age_in_days_n = c(500, NA, 500, 0, 1825, 1826, 500),
  eq002         = c(1, NA, 1, 1, 1, 1, 0),
  mn_eqstate    = c(1, NA, 1, 1, 1, 1, 1)
))

elig_result <- calculate_eligibility(elig_df)
assert_equal(nrow(elig_result), 7L, "eligibility row count")

# Row 1: all eligible
assert_equal(elig_result$eligible[1], TRUE, "happy path eligible")

# Row 2: all NA → eligible should be NA (screener incomplete)
assert_na(elig_result$eligible[2], "all-NA → eligible is NA")

# Row 3: parent age ineligible (eq003=0)
assert_equal(elig_result$parent_age_eligible[3], FALSE, "eq003=0 → ineligible")
assert_equal(elig_result$eligible[3], FALSE, "one criterion FALSE → ineligible")

# Row 4: child age = 0 days (boundary, eligible)
assert_equal(elig_result$child_age_eligible[4], TRUE, "age=0 days → eligible")

# Row 5: child age = 1825 days (boundary, eligible)
assert_equal(elig_result$child_age_eligible[5], TRUE, "age=1825 → eligible")

# Row 6: child age = 1826 days (boundary, ineligible)
assert_equal(elig_result$child_age_eligible[6], FALSE, "age=1826 → ineligible")

# Row 7: not primary caregiver
assert_equal(elig_result$primary_caregiver_eligible[7], FALSE, "eq002=0 → ineligible")

cat("[OK] Eligibility tests passed\n")

# ============================================================================
# TEST SECTION 2: SEX TRANSFORMS
# ============================================================================
cat("\n=== 2. SEX TRANSFORMS ===\n")

sex_df <- build_synthetic_raw(n = 5, overrides = list(
  cqr009    = c(0, 1, NA, 99, 0),
  cqr009_c2 = c(0, 1, NA_real_, NA_real_, NA_real_),
  mn2       = c(0, 1, 97, NA, 99)
))

sex_result <- transform_raw_data(sex_df)

# Child 1 sex
assert_equal(sex_result$sex_norc[1], "Male", "cqr009=0 → Male")
assert_equal(sex_result$sex_norc[2], "Female", "cqr009=1 → Female")
assert_na(sex_result$sex_norc[3], "cqr009=NA → NA")
assert_na(sex_result$sex_norc[4], "cqr009=99 → NA (invalid code)")

# Child 2 sex
assert_equal(sex_result$sex_c2_norc[1], "Male", "cqr009_c2=0 → Male")
assert_equal(sex_result$sex_c2_norc[2], "Female", "cqr009_c2=1 → Female")
assert_na(sex_result$sex_c2_norc[3], "cqr009_c2=NA → NA")

# Parent gender
assert_equal(sex_result$a1_gender_norc[1], "Female", "mn2=0 → Female")
assert_equal(sex_result$a1_gender_norc[2], "Male", "mn2=1 → Male")
assert_equal(sex_result$a1_gender_norc[3], "Non-binary", "mn2=97 → Non-binary")
assert_na(sex_result$a1_gender_norc[4], "mn2=NA → NA")
assert_na(sex_result$a1_gender_norc[5], "mn2=99 → NA (invalid code)")

cat("[OK] Sex transform tests passed\n")

# ============================================================================
# TEST SECTION 4: EDUCATION & MARITAL STATUS
# ============================================================================
cat("\n=== 3. EDUCATION & MARITAL STATUS ===\n")

educ_labels <- c(
  "8th grade or less", "9th-12th grade, No diploma",
  "High School Graduate or GED", "Vocational/Trade/Business school",
  "Some College, no degree", "Associate Degree",
  "Bachelor's Degree", "Master's Degree", "Doctorate or Professional Degree"
)

marital_labels <- c(
  "Married", "Not married, but living with a partner",
  "Never Married", "Divorced", "Separated", "Widowed"
)

# Education: codes 0-8, plus NA and out-of-range
educ_df <- build_synthetic_raw(n = 11, overrides = list(
  cqr004 = c(0, 1, 2, 3, 4, 5, 6, 7, 8, NA, 99)
))
educ_result <- transform_raw_data(educ_df)

for (i in 1:9) {
  assert_equal(educ_result$educ_a1_norc[i], educ_labels[i],
               paste0("cqr004=", i - 1, " → ", educ_labels[i]))
}
assert_na(educ_result$educ_a1_norc[10], "cqr004=NA → NA")
assert_na(educ_result$educ_a1_norc[11], "cqr004=99 → NA (invalid)")

# Marital status: codes 0-5, plus NA and out-of-range
marital_df <- build_synthetic_raw(n = 8, overrides = list(
  cqfa001 = c(0, 1, 2, 3, 4, 5, NA, 99)
))
marital_result <- transform_raw_data(marital_df)

for (i in 1:6) {
  assert_equal(marital_result$marital_status_label_norc[i], marital_labels[i],
               paste0("cqfa001=", i - 1, " → ", marital_labels[i]))
}
assert_na(marital_result$marital_status_label_norc[7], "cqfa001=NA → NA")
assert_na(marital_result$marital_status_label_norc[8], "cqfa001=99 → NA (invalid)")

cat("[OK] Education & marital status tests passed\n")

# ============================================================================
# TEST SECTION 5: RACE CHECKBOXES
# ============================================================================
cat("\n=== 4. RACE CHECKBOXES ===\n")

race_df <- build_synthetic_raw(n = 6, overrides = list(
  # Row 1: No race selected, non-Hispanic → NA
  sq002b___100 = c(0, 0, 1, 0, 1, 0),
  sq002b___101 = c(0, 0, 0, 0, 1, 0),
  sq002b___102 = c(0, 1, 0, 0, 0, 0),
  sq002b___103 = c(0, 0, 0, 0, 0, 0),
  sq002b___104 = c(0, 0, 0, 1, 0, 0),
  sq002b___105 = c(0, 0, 0, 0, 0, 1),
  sq003         = c(0, 0, 0, 0, 0, 1),  # Row 6: Hispanic

  # Mirror for child 1
  cqr010b___100 = c(0, 0, 1, 0, 1, 0),
  cqr010b___101 = c(0, 0, 0, 0, 1, 0),
  cqr010b___102 = c(0, 1, 0, 0, 0, 0),
  cqr010b___103 = c(0, 0, 0, 0, 0, 0),
  cqr010b___104 = c(0, 0, 0, 1, 0, 0),
  cqr010b___105 = c(0, 0, 0, 0, 0, 1),
  cqr011         = c(0, 0, 0, 0, 0, 1)
))

race_result <- transform_raw_data(race_df)

# Row 1: no race selected, non-Hispanic → race=NA, raceG=NA
assert_na(race_result$a1_race_norc[1], "no race selected → NA")
assert_na(race_result$a1_raceG_norc[1], "no race + non-Hisp → NA (not 'NA, non-Hisp.')")

# Row 2: single race (Black)
assert_equal(race_result$a1_race_norc[2], "Black or African American", "single Black")

# Row 3: single race (AIAN)
assert_equal(race_result$a1_race_norc[3], "American Indian or Alaska Native", "single AIAN")

# Row 4: single race (White)
assert_equal(race_result$a1_race_norc[4], "White", "single White")
assert_equal(race_result$a1_raceG_norc[4], "White, non-Hisp.", "White non-Hisp combined")

# Row 5: multi-race (AIAN + Asian)
assert_equal(race_result$a1_race_norc[5], "Two or More", "multi-race → Two or More")

# Row 6: Hispanic (overrides race in combined variable)
assert_equal(race_result$a1_raceG_norc[6], "Hispanic", "Hispanic → Hispanic regardless of race")

# Verify child 1 mirrors parent logic
assert_na(race_result$race_norc[1], "child 1 no race → NA")
assert_na(race_result$raceG_norc[1], "child 1 no race + non-Hisp → NA")
assert_equal(race_result$race_norc[2], "Black or African American", "child 1 single Black")
assert_equal(race_result$raceG_norc[6], "Hispanic", "child 1 Hispanic")

cat("[OK] Race checkbox tests passed\n")

# ============================================================================
# TEST SECTION 6: PARENT AGE
# ============================================================================
cat("\n=== 5. PARENT AGE ===\n")

age_df <- build_synthetic_raw(n = 3, overrides = list(
  cqr003 = c(25, NA, 45)
))

age_result <- transform_raw_data(age_df)
assert_equal(age_result$a1_years_old[1], 25, "cqr003=25 → 25")
assert_na(age_result$a1_years_old[2], "cqr003=NA → NA")
assert_equal(age_result$a1_years_old[3], 45, "cqr003=45 → 45")

cat("[OK] Parent age tests passed\n")

# ============================================================================
# TEST SECTION 7: CHILD 2 PRESENCE
# ============================================================================
cat("\n=== 6. CHILD 2 PRESENCE ===\n")

c2_df <- build_synthetic_raw(n = 3, overrides = list(
  # Row 1: no child 2 (empty string)
  # Row 2: no child 2 (NA)
  # Row 3: child 2 present
  dob_c2_n         = c("", NA, "2024-01-15"),
  age_in_days_c2_n = c(NA_real_, NA_real_, 400),
  cqr009_c2        = c(NA_real_, NA_real_, 1)
))

c2_result <- transform_raw_data(c2_df)

# Row 1-2: no child 2 → child 2 columns are NA
assert_na(c2_result$years_old_c2[1], "no c2 (empty) → years_old_c2 NA")
assert_na(c2_result$sex_c2_norc[1], "no c2 (empty) → sex_c2_norc NA")
assert_na(c2_result$years_old_c2[2], "no c2 (NA) → years_old_c2 NA")

# Row 3: child 2 present
assert_equal(round(c2_result$years_old_c2[3], 2), round(400 / 365.25, 2), "c2 age computed")
assert_equal(c2_result$sex_c2_norc[3], "Female", "c2 sex = Female")

# Verify extract_child_demographics handles both cases
child_demo <- extract_child_demographics(c2_result)
assert_equal(nrow(child_demo), 3L, "child demo row count")
assert_true("years_old_c2" %in% names(child_demo), "child demo has c2 columns")

cat("[OK] Child 2 presence tests passed\n")

# ============================================================================
# TEST SECTION 8: SURVEY COMPLETION
# ============================================================================
cat("\n=== 7. SURVEY COMPLETION ===\n")

# Row 1: all complete, no child 2, age outside NSCH range → n_required=7
# Row 2: all incomplete (0) → 0% complete
# Row 3: mixed (some 2, some 0)
# Row 4: child 2 present, both in NSCH range → n_required=11
# Row 5: child 1 in NSCH range (age 500), no child 2 → n_required=8
survey_df <- build_synthetic_raw(n = 5, overrides = list(
  consent_doc_complete                      = c(2, 0, 2, 2, 2),
  eligibility_form_norc_complete            = c(2, 0, 2, 2, 2),
  module_2_family_information_complete      = c(2, 0, 0, 2, 2),
  module_3_child_information_complete       = c(2, 0, 0, 2, 2),
  module_9_compensation_information_complete = c(2, 0, 0, 2, 2),
  module_8_followup_information_complete    = c(2, 0, 0, 2, 2),
  module_6_0to3_complete                    = c(2, 0, 0, 2, 2),

  # NSCH child 1: required if age 365-1065
  age_in_days_n            = c(1500, 1500, 1500, 500, 500),
  nsch_questions_complete  = c(NA, NA, NA, 2, 2),

  # Child 2
  dob_c2_n                           = c("", "", "", "2024-01-15", ""),
  age_in_days_c2_n                   = c(NA, NA, NA, 500, NA),
  child_information_2_954c_complete  = c(NA, NA, NA, 2, NA),
  module_6_0to3_2_complete           = c(NA, NA, NA, 2, NA),
  nsch_questions_2_complete          = c(NA, NA, NA, 2, NA)
))

survey_result <- calculate_survey_completion(survey_df)
assert_equal(nrow(survey_result), 5L, "survey row count")

# Row 1: all complete, no NSCH, no child 2 → 7 required, 7 done
assert_equal(survey_result$n_required[1], 7L, "row 1 n_required=7")
assert_equal(survey_result$modules_complete[1], 7L, "row 1 modules_complete=7")
assert_true(survey_result$modules_complete[1] == survey_result$n_required[1], "row 1 survey complete")

# Row 2: all incomplete
assert_equal(survey_result$modules_complete[2], 0L, "row 2 modules_complete=0")
assert_true(survey_result$modules_complete[2] < survey_result$n_required[2], "row 2 survey incomplete")

# Row 3: mixed
assert_true(survey_result$modules_complete[3] > 0L & survey_result$modules_complete[3] < survey_result$n_required[3],
            "row 3 partial completion")

# Row 4: child 2 + NSCH both → 6 always + 1 m6_c1 + 1 nsch_c1 + 1 c2_info + 1 m6_c2 + 1 nsch_c2 = 11
assert_equal(survey_result$n_required[4], 11L, "row 4 n_required=11 (c2 + NSCH)")
assert_true(survey_result$modules_complete[4] == survey_result$n_required[4], "row 4 fully complete")

# Row 5: NSCH child 1 required (age 500 in 365-1065), no child 2 → 8
assert_equal(survey_result$n_required[5], 8L, "row 5 n_required=8 (NSCH c1)")

cat("[OK] Survey completion tests passed\n")

# ============================================================================
# TEST SECTION 9: COMPENSATION
# ============================================================================
cat("\n=== 8. COMPENSATION ===\n")

comp_df <- build_synthetic_raw(n = 6, overrides = list(
  store_choice = c(1, 2, 3, 4, NA, 99)
))

comp_result <- transform_raw_data(comp_df)

assert_equal(comp_result$store_choice_label[1], "Lowe's", "store_choice=1 → Lowe's")
assert_equal(comp_result$store_choice_label[2], "Amazon", "store_choice=2 → Amazon")
assert_equal(comp_result$store_choice_label[3], "Walmart", "store_choice=3 → Walmart")
assert_equal(comp_result$store_choice_label[4], "Target", "store_choice=4 → Target")
assert_na(comp_result$store_choice_label[5], "store_choice=NA → NA")
assert_na(comp_result$store_choice_label[6], "store_choice=99 → NA (invalid)")

# Verify extract works
comp_extracted <- extract_compensation_information(comp_result)
assert_true("store_choice_label" %in% names(comp_extracted), "extract has store_choice_label")
assert_equal(nrow(comp_extracted), 6L, "extract row count")

cat("[OK] Compensation tests passed\n")

# ============================================================================
# TEST SECTION 10: FULL INTEGRATION
# ============================================================================
cat("\n=== 9. FULL INTEGRATION ===\n")

# Single happy-path row through all pipeline functions
integration_df <- build_synthetic_raw(n = 1)

# Step 1: Transform
transformed <- transform_raw_data(integration_df, dictionary = NULL)
assert_true(is.data.frame(transformed), "transform returns data.frame")
assert_equal(nrow(transformed), 1L, "transform row count")

# Step 2: Eligibility form extraction (uses mock dictionary)
mock_dict <- list(
  eq001 = list(field_name = "eq001", form_name = "eligibility_form_norc", field_type = "yesno"),
  eq002 = list(field_name = "eq002", form_name = "eligibility_form_norc", field_type = "yesno"),
  eq003 = list(field_name = "eq003", form_name = "eligibility_form_norc", field_type = "yesno"),
  mn_eqstate = list(field_name = "mn_eqstate", form_name = "eligibility_form_norc", field_type = "yesno"),
  age_in_days_n = list(field_name = "age_in_days_n", form_name = "eligibility_form_norc", field_type = "calc")
)
elig_form <- extract_eligibility_form(integration_df, mock_dict)
assert_true("eq002" %in% names(elig_form), "integration: elig_form has eq002")
assert_true("eq003" %in% names(elig_form), "integration: elig_form has eq003")
assert_true("mn_eqstate" %in% names(elig_form), "integration: elig_form has mn_eqstate")
assert_true("age_in_days_n" %in% names(elig_form), "integration: elig_form has age_in_days_n")
assert_true("eligibility_form_norc_complete" %in% names(elig_form), "integration: elig_form has completion flag")
assert_equal(nrow(elig_form), 1L, "integration: elig_form 1 row")

# Step 3: Survey completion
survey <- calculate_survey_completion(integration_df)
assert_true(survey$modules_complete[1] == survey$n_required[1], "integration: survey complete")

# Step 5: Child demographics
child_demo <- extract_child_demographics(transformed)
assert_true("sex_norc" %in% names(child_demo), "integration: child has sex_norc")
assert_true("race_norc" %in% names(child_demo), "integration: child has race_norc")
assert_true("raceG_norc" %in% names(child_demo), "integration: child has raceG_norc")

# Step 6: Parent demographics
parent_demo <- extract_parent_demographics(transformed)
assert_true("gender" %in% names(parent_demo), "integration: parent has gender")
assert_true("education" %in% names(parent_demo), "integration: parent has education")
assert_true("race_ethnicity" %in% names(parent_demo), "integration: parent has race_ethnicity")
assert_true("marital_status_label_norc" %in% names(parent_demo), "integration: parent has marital")

# Step 7: Compensation
comp_info <- extract_compensation_information(transformed)
assert_true("store_choice_label" %in% names(comp_info), "integration: comp has store_choice_label")

# Verify all 5 output data frames have 1 row
assert_equal(nrow(elig_form), 1L, "integration: elig_form 1 row")
assert_equal(nrow(survey), 1L, "integration: survey 1 row")
assert_equal(nrow(child_demo), 1L, "integration: child_demo 1 row")
assert_equal(nrow(parent_demo), 1L, "integration: parent_demo 1 row")
assert_equal(nrow(comp_info), 1L, "integration: comp_info 1 row")

cat("[OK] Full integration tests passed\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n=== ALL SYNTHETIC TESTS PASSED ===\n")
cat("Total assertions: ", tests_passed, "/", tests_total, "\n\n")
