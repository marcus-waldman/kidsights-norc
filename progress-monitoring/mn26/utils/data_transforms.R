#' Data Transformation Utilities
#'
#' Functions for transforming raw REDCap data into monitoring variables.
#' Updated for MN26 NORC field names and value codes.
#' Variables use _norc suffix where codes differ from NE25 pipeline.

#' Transform raw REDCap data into monitoring variables
#'
#' Performs inline transformations on raw data to create derived variables
#' needed for monitoring (age, sex, race/ethnicity, education, marital status).
#'
#' @param raw_data Raw REDCap data
#' @param dictionary REDCap data dictionary (optional, for value labels)
#' @return Data frame with transformed variables
transform_raw_data <- function(raw_data, dictionary = NULL) {

  message("Transforming raw data...")

  transformed <- raw_data %>%
    dplyr::mutate(
      # --- Child 1 age ---
      # MN26: age_in_days_n (calc field, exports with data)
      years_old = age_in_days_n / 365.25,

      # --- Child 1 sex ---
      # MN26: cqr009 = 1 (Female), 0 (Male) — SWAPPED from NE25
      sex_norc = dplyr::case_when(
        cqr009 == 1 ~ "Female",
        cqr009 == 0 ~ "Male",
        .default = NA_character_
      ),

      # --- Parent gender ---
      # MN26: mn2 = 0 (Female), 1 (Male), 97 (Non-binary) — replaces cqr002
      a1_gender_norc = dplyr::case_when(
        mn2 == 0 ~ "Female",
        mn2 == 1 ~ "Male",
        mn2 == 97 ~ "Non-binary",
        .default = NA_character_
      ),

      # --- Parent age ---
      a1_years_old = as.numeric(cqr003),

      # --- Parent education ---
      # MN26: cqr004 codes 0-8 (shifted from NE25's 1-8, different labels)
      educ_a1_norc = dplyr::case_when(
        cqr004 == 0 ~ "8th grade or less",
        cqr004 == 1 ~ "9th-12th grade, No diploma",
        cqr004 == 2 ~ "High School Graduate or GED",
        cqr004 == 3 ~ "Vocational/Trade/Business school",
        cqr004 == 4 ~ "Some College, no degree",
        cqr004 == 5 ~ "Associate Degree",
        cqr004 == 6 ~ "Bachelor's Degree",
        cqr004 == 7 ~ "Master's Degree",
        cqr004 == 8 ~ "Doctorate or Professional Degree",
        .default = NA_character_
      ),

      # --- Marital status ---
      # MN26: cqfa001 codes 0-5 (shifted from NE25's 1-6)
      marital_status_label_norc = dplyr::case_when(
        cqfa001 == 0 ~ "Married",
        cqfa001 == 1 ~ "Not married, but living with a partner",
        cqfa001 == 2 ~ "Never Married",
        cqfa001 == 3 ~ "Divorced",
        cqfa001 == 4 ~ "Separated",
        cqfa001 == 5 ~ "Widowed",
        .default = NA_character_
      )
    )

  # --- Child 2 age ---
  # MN26: age_in_days_c2_n (calc field, exports with data)
  if ("age_in_days_c2_n" %in% names(raw_data)) {
    transformed$years_old_c2 <- raw_data$age_in_days_c2_n / 365.25
  } else {
    transformed$years_old_c2 <- NA_real_
  }

  # --- Child 2 sex ---
  # MN26: cqr009_c2 = 1 (Female), 0 (Male)
  if ("cqr009_c2" %in% names(raw_data)) {
    transformed$sex_c2_norc <- dplyr::case_when(
      raw_data$cqr009_c2 == 1 ~ "Female",
      raw_data$cqr009_c2 == 0 ~ "Male",
      .default = NA_character_
    )
  } else {
    transformed$sex_c2_norc <- NA_character_
  }

  # --- Parent race/ethnicity ---
  # MN26: sq002b___100 (AIAN), ___101 (Asian), ___102 (Black), ___103 (NHPI), ___104 (White), ___105 (Other)
  # MN26: sq003 = 0 (non-Hispanic), 1 (Hispanic)
  race_cols <- grep("^sq002b___", names(raw_data), value = TRUE)

  if (length(race_cols) > 0) {
    # Count how many race categories selected per person
    race_count <- rowSums(raw_data[, race_cols, drop = FALSE], na.rm = TRUE)

    transformed <- transformed %>%
      dplyr::mutate(
        a1_race_norc_count = race_count,
        a1_hisp = ifelse(sq003 == 1, "Hispanic", "non-Hisp."),
        a1_race_norc = dplyr::case_when(
          a1_race_norc_count > 1 ~ "Two or More",
          sq002b___104 == 1 ~ "White",
          sq002b___102 == 1 ~ "Black or African American",
          sq002b___100 == 1 ~ "American Indian or Alaska Native",
          sq002b___101 == 1 ~ "Asian",
          sq002b___103 == 1 ~ "Native Hawaiian or Other Pacific Islander",
          sq002b___105 == 1 ~ "Other",
          .default = NA_character_
        ),
        a1_raceG_norc = ifelse(a1_hisp == "Hispanic", "Hispanic", paste0(a1_race_norc, ", non-Hisp."))
      )
  } else {
    transformed <- transformed %>%
      dplyr::mutate(
        a1_hisp = NA_character_,
        a1_race_norc = NA_character_,
        a1_raceG_norc = NA_character_
      )
    warning("No race checkbox columns (sq002b___*) found in data")
  }

  # --- Child 1 race/ethnicity ---
  # MN26: cqr010b___100 (AIAN), ___101 (Asian), ___102 (Black), ___103 (NHPI), ___104 (White), ___105 (Other)
  # MN26: cqr011 = 0 (non-Hispanic), 1 (Hispanic)
  c1_race_cols <- grep("^cqr010b___", names(raw_data), value = TRUE)

  if (length(c1_race_cols) > 0) {
    c1_race_count <- rowSums(raw_data[, c1_race_cols, drop = FALSE], na.rm = TRUE)

    transformed <- transformed %>%
      dplyr::mutate(
        race_norc_count = c1_race_count,
        hisp = ifelse(cqr011 == 1, "Hispanic", "non-Hisp."),
        race_norc = dplyr::case_when(
          race_norc_count > 1 ~ "Two or More",
          cqr010b___104 == 1 ~ "White",
          cqr010b___102 == 1 ~ "Black or African American",
          cqr010b___100 == 1 ~ "American Indian or Alaska Native",
          cqr010b___101 == 1 ~ "Asian",
          cqr010b___103 == 1 ~ "Native Hawaiian or Other Pacific Islander",
          cqr010b___105 == 1 ~ "Other",
          .default = NA_character_
        ),
        raceG_norc = ifelse(hisp == "Hispanic", "Hispanic", paste0(race_norc, ", non-Hisp."))
      )
  } else {
    transformed <- transformed %>%
      dplyr::mutate(
        hisp = NA_character_,
        race_norc = NA_character_,
        raceG_norc = NA_character_
      )
    warning("No child 1 race checkbox columns (cqr010b___*) found in data")
  }

  # --- Child 2 race/ethnicity ---
  # MN26: cqr010_c2b___100 (AIAN), ___101 (Asian), ___102 (Black), ___103 (NHPI), ___104 (White), ___105 (Other)
  # MN26: cqr011_c2 = 0 (non-Hispanic), 1 (Hispanic)
  c2_race_cols <- grep("^cqr010_c2b___", names(raw_data), value = TRUE)

  if (length(c2_race_cols) > 0) {
    c2_race_count <- rowSums(raw_data[, c2_race_cols, drop = FALSE], na.rm = TRUE)

    transformed <- transformed %>%
      dplyr::mutate(
        race_c2_norc_count = c2_race_count,
        hisp_c2 = ifelse(cqr011_c2 == 1, "Hispanic", "non-Hisp."),
        race_c2_norc = dplyr::case_when(
          race_c2_norc_count > 1 ~ "Two or More",
          cqr010_c2b___104 == 1 ~ "White",
          cqr010_c2b___102 == 1 ~ "Black or African American",
          cqr010_c2b___100 == 1 ~ "American Indian or Alaska Native",
          cqr010_c2b___101 == 1 ~ "Asian",
          cqr010_c2b___103 == 1 ~ "Native Hawaiian or Other Pacific Islander",
          cqr010_c2b___105 == 1 ~ "Other",
          .default = NA_character_
        ),
        raceG_c2_norc = ifelse(hisp_c2 == "Hispanic", "Hispanic", paste0(race_c2_norc, ", non-Hisp."))
      )
  } else {
    transformed <- transformed %>%
      dplyr::mutate(
        hisp_c2 = NA_character_,
        race_c2_norc = NA_character_,
        raceG_c2_norc = NA_character_
      )
    warning("No child 2 race checkbox columns (cqr010_c2b___*) found in data")
  }

  # --- Compensation: gift card store choice ---
  # MN26: store_choice = 1 (Lowe's), 2 (Amazon), 3 (Walmart), 4 (Target)
  if ("store_choice" %in% names(transformed)) {
    transformed <- transformed %>%
      dplyr::mutate(
        store_choice_label = dplyr::case_when(
          store_choice == 1 ~ "Lowe's",
          store_choice == 2 ~ "Amazon",
          store_choice == 3 ~ "Walmart",
          store_choice == 4 ~ "Target",
          .default = NA_character_
        )
      )
  }

  message("[OK] Transformed ", nrow(transformed), " records")
  return(transformed)
}
