#' Run all NORC daily summary functions on a Redcap API data list
#'
#' @param monitoring_data
#' @param id_xwalk A crosswalk from P_SUID to record_id (exported by NORC
#' to `data/`)
#' @param child_demos A summary table of child demographics from the sampling
#' frame (exported by NORC  to `data/`)
#' @param mom_demos A summary table of mother demographics from the sampling
#' frame (exported by NORC  to `data/`)
#'
#' @returns A list of summary tables suited for export to Excel
#'
#' @export
norc_summarise <- function(monitoring_data, id_xwalk, child_demos, mom_demos) {
  monitoring_data <- monitoring_data %>%
    norc_replace_records(id_xwalk) %>%
    norc_sample()

  monitoring_data$eligibility_form <- monitoring_data$eligibility_form %>%
    norc_elig_screen()

  monitoring_data$survey_completion <- monitoring_data$survey_completion %>%
    norc_survey_complete(monitoring_data$eligibility_form)

  list(
    summary_rates = monitoring_data %>% norc_rates,
    complete_ids = monitoring_data %>% norc_complete_ids,
    summary_breakoffs = monitoring_data %>% norc_breakoffs,
    breakoff_ids = monitoring_data %>% norc_breakoff_ids,
    summary_child_demographics = monitoring_data %>%
      norc_child_demographics(child_demos),
    summary_mother_demographics = monitoring_data %>%
      norc_mother_demographics(mom_demos),
    summary_compensation = monitoring_data %>% norc_compensation,
    monitoring_data = monitoring_data
  )
}

#' Define survey complete
#'
#' Modify the `monitoring_data$survey_completion` to identify survey completes,
#' which are eligible cases who reached the Follow-up or Compensation module
#'
#' @param survey_completion
#' @param eligibility_form
norc_survey_complete <- function(survey_completion, eligibility_form) {
  survey_completion %>%
    left_join(
      eligibility_form %>% select(record_id, elig),
      by = "record_id"
    ) %>%
    mutate(
      survey_complete = elig &
        last_module_complete %in% c("Follow-up", "Compensation")
    )
}


#' Define eligibility and screener complete
#'
#' Modifying the `monitoring_data$eligibility_form` to identify eligible
#' cases, number of eligible children, and completion of the screener
#'
#' @details Eligibility Scenarios:
#'
#' A respondent is eligible under any of the following scenarios:
#'
#' **Scenario 1** — Exactly one child under 6 in household:
#' \enumerate{
#'   \item How many children under age six live in your household? `= 1`
#'   \item Was this child born in the state of Minnesota? `= Yes`
#'   \item What is the birthdate of the youngest child in your household
#'     who was born in Minnesota? `= under 6`
#'   \item Are you a parent or guardian for this child? `= Yes`
#' }
#'
#' **Scenario 2** — Multiple children under 6, exactly one born in Minnesota:
#' \enumerate{
#'   \item How many children under age six live in your household? `> 1`
#'   \item How many of these children were born in the state of
#'     Minnesota? `= 1`
#'   \item What is the birthdate of the youngest child in your household
#'     who was born in Minnesota? `= under 6`
#'   \item Are you a parent or guardian for this child? `= Yes`
#' }
#'
#' **Scenario 3** — Multiple children under 6, more than one born in
#' Minnesota:
#' \enumerate{
#'   \item How many children under age six live in your household? `> 1`
#'   \item How many of these children were born in the state of
#'     Minnesota? `> 1`
#'   \item At least one of the two Minnesota-born children must be under
#'     6 and the respondent must be a parent or guardian, satisfied by
#'     either:
#'   \itemize{
#'     \item What is the birthdate of the \strong{youngest} child in your
#'       household who was born in Minnesota? `= under 6` \strong{AND}
#'       Are you a parent or guardian for this child? `= Yes`
#'     \item \strong{Or:} What is the birthdate of the
#'       \strong{next youngest} child in your household who was born in
#'       Minnesota? `= under 6` \strong{AND} Are you a parent or guardian
#'       for this child? `= Yes`
#'   }
#' }
#'
#' @param eligibility_form
#'
norc_elig_screen <- function(eligibility_form) {
  eligibility_form %>%
    mutate(
      age_in_days_n = case_when(
        dob_n <= consent_date_n ~ age_in_days_n
      ),
      age_in_days_c2_n = case_when(
        dob_c2_n <= consent_date_n ~ age_in_days_c2_n
      ),
      mn_kids = case_when(
        kids_u6_n == 0 ~ 0,
        kids_u6_n == 1 & mn_birth_c1_n == 0 ~ 0,
        kids_u6_n == 1 & mn_birth_c1_n == 1 ~ 1,
        kids_u6_n > 1 ~ mn_birth_c2_n
      ),
      solo_kid_elig = case_when(
        mn_kids == 1 ~ age_in_days_n <= 2191 & parent_guardian_c1_n == 1
      ),
      youngest_kid_elig = case_when(
        mn_kids > 1 ~ age_in_days_n <= 2191 & parent_guardian_c1_n == 1
      ),
      oldest_kid_elig = case_when(
        mn_kids > 1 ~ age_in_days_c2_n <= 2191 & parent_guardian_c2_n == 1
      ),
      elig_kids = case_when(
        solo_kid_elig ~ 1,
        youngest_kid_elig & !oldest_kid_elig ~ 1,
        oldest_kid_elig & !youngest_kid_elig ~ 1,
        youngest_kid_elig & oldest_kid_elig ~ 2,
        .default = 0
      ),
      elig_type = case_when(
        kids_u6_n == 1 &
          mn_birth_c1_n == 1 &
          age_in_days_n <= 2191 &
          parent_guardian_c1_n == 1 ~ "1",
        kids_u6_n > 1 &
          mn_birth_c2_n == 1 &
          age_in_days_n <= 2191 &
          parent_guardian_c1_n == 1 ~ "2",
        kids_u6_n > 1 &
          mn_birth_c2_n > 1 &
          age_in_days_n <= 2191 &
          parent_guardian_c1_n == 1 ~ "3a",
        kids_u6_n > 1 &
          mn_birth_c2_n > 1 &
          age_in_days_c2_n <= 2191 &
          parent_guardian_c2_n == 1 ~ "3b"
      ),
      elig = !is.na(elig_type),
      screener_complete = eligibility_form_norc_complete != 0,
      elig = elig & screener_complete
    )
}


#' Replace records moved to a new PID
#'
#' When a user closes the survey application without saving, they must be
#' given a new URL and record ID for the next time they visit. This assignment
#' is performed in the Kidsights frame cleaning folder: the new URL and
#' record ID are timestamped and added to a nested data frame `redcap_info`
#' associated with that user's P_SUID. This function makes sure that, when
#' a user returns via their new URL, their prevoius record is expunged from
#' the API monitoring dataset; this ensures that we will not double-count the
#' old and new record assciated with the same persion.
#'
#' The return of a user is signalled by a fresh `consent_date_n` associated
#' with their record on the new PID (8792).
#'
#' @param monitoring_data A list returned by the Redcap API
#' @param frame The NORC sampling frame that includes a crosswalk from P_SUID
#' to all of the Record IDs and URLs associated with that person.
#'
#' @returns A version of `monitoring_data` with only one record per P_SUID
#'
#' @export
norc_replace_records <- function(monitoring_data, id_xwalk) {
  new_pid_members <- monitoring_data$eligibility_form %>%
    filter(pid == 8792) %>%
    filter(!consent_date_n %>% is.na) %>%
    left_join(id_xwalk, by = "record_id")

  # If someone has consented with their third set of credentials, keep only
  # the third one in `new_pid_members`
  new_pid_members <- new_pid_members %>%
    filter(.by = P_SUID, consent_date_n == max(consent_date_n)) %>%
    select(P_SUID, record_id, everything())

  monitoring_data %>%
    map(
      ~ {
        # Join `id_xwalk` to each data frame in `montoring_data`
        .x <- .x %>%
          select(-any_of("survey_link")) %>%
          left_join(id_xwalk, by = "record_id") %>%
          select(all_of(names(id_xwalk)), everything())

        # drop expired /unused record id(s) for cases in `new_pid_members`
        .x <- .x %>%
          filter(
            !when_all(
              P_SUID %in% new_pid_members$P_SUID,
              !record_id %in% new_pid_members$record_id
            )
          ) %>%
          arrange(P_SUID)

        # drop record IDs in 8792 that have not yet been used
        .x <- .x %>%
          filter(!when_all(pid == 8792, !P_SUID %in% new_pid_members$P_SUID))

        return(.x)
      }
    )
}


#' Drop cases outside of the NORC sample defintition
#'
#' The data from `monotiring_report` includes "smoke cases" (i.e. test cases) and
#' a handful of "out-of-scope" cases (i.e. cases that were included on the
#' original sample frame, but were determined to be undeliveriable by NCOA
#' in a subsequent mailing effort). We exclude "smoke cases" from the sample
#' definition, but retain "out-of-scope cases"; the latter will have no P_SUID.
#'
#' Why retain "out-of-scope cases"? This ensures that our sample size stays the
#' same as it was at the start of fielding.
#'
#' @inheritParams norc_replace_records
norc_sample <- function(monitoring_data) {
  monitoring_data %>% map(~ .x %>% filter(!smoke_case | !in_scope))
}


norc_rates <- function(monitoring_data) {
  tbl <- monitoring_data$eligibility_form %>%
    left_join(
      monitoring_data$survey_completion %>%
        select(pid, record_id, survey_complete),
      by = join_by(pid, record_id)
    )

  out <- tbl %>%
    summarise(
      sampled = n_distinct(record_id),
      screener_completes = sum(screener_complete),
      pct_screener_completes = scales::percent(
        screener_completes / sampled,
        0.1
      ),
      elig_kids = "1 or 2",
      eligibles = sum(elig),
      pct_eligible = scales::percent(eligibles / screener_completes, 0.1),
      survey_completes = sum(survey_complete),
      pct_survey_completes = scales::percent(
        survey_completes / eligibles,
        0.1
      )
    )

  tbl %>%
    filter(elig) %>%
    mutate(elig_kids = elig_kids %>% as.character) %>%
    summarise(
      .by = elig_kids,
      screener_completes = sum(screener_complete),
      pct_screener_completes = scales::percent(
        screener_completes / out$sampled,
        0.1
      ),
      eligibles = sum(elig),
      survey_completes = sum(survey_complete),
      pct_survey_completes = scales::percent(
        survey_completes / eligibles,
        0.1
      )
    ) %>%
    bind_rows(out, .) %>%
    rename(
      `Sampled` = sampled,
      `# HH screened` = screener_completes,
      `% HH screened` = pct_screener_completes,
      `# of eligible children in HH` = elig_kids,
      `# eligible HHs` = eligibles,
      `Pct of screened HHs that are eligible` = pct_eligible,
      `# HHs completing the survey` = survey_completes,
      `Pct of eligible HHs completing` = pct_survey_completes
    )
}


#' List survey completes by completion date
norc_complete_ids <- function(monitoring_data) {
  survey_completion <- monitoring_data$survey_completion %>%
    filter(elig, survey_complete) %>%
    select(P_SUID, record_id, pid)

  monitoring_data$all_data %>%
    select(
      record_id,
      pid,
      fu_complete = module_8_followup_information_timestamp,
      compensation_complete = module_9_compensation_information_timestamp
    ) %>%
    mutate(across(matches("complete"), as.Date)) %>%
    right_join(survey_completion, by = c("record_id", "pid")) %>%
    mutate(
      .by = record_id,
      complete_date = c_across(ends_with("complete")) %>% min(na.rm = TRUE)
    ) %>%
    select(-ends_with("complete")) %>%
    relocate(P_SUID, .before = everything()) %>%
    left_join(
      by = "P_SUID",
      monitoring_data$eligibility_form %>%
        select(P_SUID, elig_kids)
    )
}

#' List breakoffs by completion date
norc_breakoff_ids <- function(monitoring_data) {
  tbl <- monitoring_data$eligibility_form %>%
    left_join(
      monitoring_data$survey_completion,
      by = c("record_id", "elig", "P_SUID", "pid")
    ) %>%
    filter(elig)

  tbl %>%
    select(P_SUID, record_id, pid, elig_kids, last_module_complete) %>%
    filter(!last_module_complete %in% c("Follow-up", "Compensation"))
}

#' Summarize breakoffs by last_module_complete and number of eligible kids
norc_breakoffs <- function(monitoring_data) {
  tbl <- monitoring_data$eligibility_form %>%
    left_join(
      monitoring_data$survey_completion,
      by = c("record_id", "elig")
    ) %>%
    filter(elig)

  out <- tbl %>%
    count(
      survey_complete,
      last_module_complete
    ) %>%
    mutate(
      .before = everything(),
      elig_kids = "1 or 2"
    ) %>%
    mutate(
      pct = scales::percent(prop.table(n), 0.1)
    )

  tbl %>%
    mutate(elig_kids = elig_kids %>% as.character) %>%
    count(
      elig_kids,
      survey_complete,
      last_module_complete
    ) %>%
    mutate(
      .by = elig_kids,
      pct = scales::percent(prop.table(n), 0.1)
    ) %>%
    bind_rows(out, .)
}

#' Summarise sampled child demographics vs frame child demographics
norc_child_demographics <- function(monitoring_data, frame) {
  monitoring_data$survey_completion %>%
    mutate(
      .keep = "none",
      record_id,
      in_survey = !is.na(last_module_complete)
    ) %>%
    full_join(
      monitoring_data$child_demographics,
      by = "record_id"
    ) %>%
    rename_with(
      ~ .x %>% paste0("_c1"),
      c(age_years, sex_norc, race_norc, hisp)
    ) %>%
    rename(
      age_years_c2 = years_old_c2,
      sex_norc_c2 = sex_c2_norc,
      race_norc_c2 = race_c2_norc
    ) %>%
    select(!starts_with("raceG")) %>%
    pivot_longer(
      cols = matches("_c[12]$"),
      names_to = c(".value", "child_num"),
      names_pattern = "^(.+)_(c\\d)$"
    ) %>%
    filter(
      in_survey,
      !if_all(c(age_years, sex_norc, race_norc, hisp), is.na)
    ) %>%
    mutate(
      .keep = "none",
      sex = sex_norc,
      age_months = 12 * floor(age_years),
      age_months = age_months %>%
        recode_values(
          0 ~ "0 - 12 months",
          12 ~ "> 12 mo & <= 24",
          24 ~ "> 24 mo & <= 36",
          36 ~ "> 36 mo & <= 48",
          48 ~ "> 48 mo & <= 60",
          60 ~ "> 60 mo & <= 72",
          72 ~ "> 72 mo & <= 84",
          84 ~ "> 84 mo & <= 96"
        ) %>%
        labelled::to_character()
    ) %>%
    imap(
      ~ tibble(variable = .y, level = .x) %>%
        count(variable, level) %>%
        mutate(pct = prop.table(n * 100))
    ) %>%
    list_rbind() %>%
    left_join(
      by = "level",
      frame %>%
        count(age_months, wt = n) %>%
        mutate(p = prop.table(n)) %>%
        select(level = age_months, frame_pct = p)
    ) %>%
    rows_update(
      by = c("level", "variable"),
      frame %>%
        count(chld_sex, wt = n) %>%
        mutate(p = prop.table(n), variable = "sex") %>%
        select(variable, level = chld_sex, frame_pct = p),
    ) %>%
    mutate(frame_diff = pct - frame_pct) %>%
    mutate(
      across(ends_with("pct"), ~ scales::percent(.x, 0.1)),
      frame_diff = frame_diff %>% scales::percent(0.1, suffix = "")
    )
}

#' Summarise sampled mother demographics vs frame mother demographics
norc_mother_demographics <- function(monitoring_data, frame) {
  monitoring_data$survey_completion %>%
    mutate(
      .keep = "none",
      record_id,
      in_survey = !is.na(last_module_complete)
    ) %>%
    full_join(
      monitoring_data$parent_demographics,
      by = "record_id"
    ) %>%
    filter(in_survey, gender == "Female") %>%
    mutate(
      .keep = "none",
      age = case_when(
        age_years %>% between(19, 25) ~ "19-25",
        age_years <= 35 ~ "26-35",
        age_years <= 45 ~ "36-45",
        age_years > 46 ~ "46+"
      ),
      race = race_ethnicity %>%
        recode_values(
          "Hispanic" ~ "Hispanic",
          "White, non-Hisp." ~ "White",
          "Black or African American, non-Hisp." ~ "Black",
          "Asian, non-Hisp." ~ "Asian",
          "NA, non-Hisp." ~ NA_character_,
          default = "Other"
        ),
      married = as.character(marital_status_label_norc == "Married")
    ) %>%
    imap(
      ~ tibble(variable = .y, level = .x) %>%
        count(variable, level) %>%
        mutate(pct = prop.table(n * 100))
    ) %>%
    list_rbind() %>%
    full_join(
      by = c("variable", "level"),
      frame %>%
        count(married = as.character(married), wt = n) %>%
        mutate(p = prop.table(n), variable = "married") %>%
        select(level = married, frame_pct = p, variable)
    ) %>%
    rows_upsert(
      by = c("variable", "level"),
      frame %>%
        count(age, wt = n) %>%
        mutate(p = prop.table(n), variable = "age") %>%
        select(level = age, frame_pct = p, variable)
    ) %>%
    rows_upsert(
      by = c("variable", "level"),
      frame %>%
        count(race, wt = n) %>%
        mutate(p = prop.table(n), variable = "race") %>%
        select(level = race, frame_pct = p, variable)
    ) %>%
    arrange(variable, level) %>%
    mutate(frame_diff = pct - frame_pct) %>%
    mutate(
      across(ends_with("pct"), ~ scales::percent(.x, 0.1)),
      frame_diff = frame_diff %>% scales::percent(0.1, suffix = "")
    )
}

#' Summarise compensation
norc_compensation <- function(monitoring_data) {
  monitoring_data$survey_completion %>%
    filter(
      last_module_complete %in% c("Follow-up", "Compensation")
    ) %>%
    select(record_id) %>%
    left_join(monitoring_data$compensation_information, by = "record_id") %>%
    count(store_choice_label) %>%
    mutate(pct = scales::percent(prop.table(n), 0.1))
}

#' System-agnostic path to P-drive (NORC network drive)
#'
#' This function constructs a file path to the P-drive that can be used across
#' commonly used R environments at NORC, including Windows machines where the
#' P-drive is mounted at `P://`, Linux systems (e.g. Posit Workbench) where it
#' is mounted at `~/P-drive`, and on Posit Connect (internal and
#' internal-staging only) where it is mounted at `/mnt`.
#'
#' A warning will be issued if the active user does not have access to the
#' constructed path. If you are unsure whether a particular folder has been
#' mounted on RSConnect, for example, you may wish to check logs for this
#' warning.
#'
#' @param ... Path components, can be empty. Each argument must be a string
#' containing one or more path components
#' separated by a forward slash `"/"` or a double-backslash `"\\"`.
#' @param os a character vector of length 1 specifying the operating system.
#' Must be either "Windows" or "Linux".
#' By default, the current OS is detected and plugged into the function.
#' @return a character vector of length 1
#' @examples
#' p_drive("my", "file", "location.txt")
#' p_drive("my/file/location.txt")
#' p_drive("my\\file\\location.txt")
#' p_drive("my", "file", "location.txt", os = "Windows")
#' p_drive("my", "file", "location.txt", os = "Linux")
#' @export
p_drive <- function(..., os = Sys.info()["sysname"]) {
  stopifnot(
    "Inputs cannot be logical or NA" = all(sapply(list(...), function(x) {
      !is.logical(x) & !is.na(x)
    }))
  )

  stopifnot(
    "All inputs must have length 1." = all(sapply(list(...), length) == 1)
  )

  # List known internal RSconnect serveers
  rsconnects <- c(
    internal = "slxzapwb04380.norc.org",
    internal_stg = "slxzatwb03749.norc.org"
  )

  on_rsconnect <- Sys.info()["nodename"] %in% rsconnects

  p_prefix <- if (on_rsconnect) {
    "/mnt"
  } else if (os == "Windows") {
    "P:/"
  } else if (os == "Linux") {
    "~/P-drive"
  } else {
    stop("Operating system must be 'Windows' or 'Linux'.")
  }

  path_out <- file.path(p_prefix, ...)

  path_out <- stringr::str_replace_all(path_out, "\\\\", "/")

  if (!dir.exists(dirname(path_out))) {
    warning(
      dirname(path_out),
      " is not reachable.\n",
      "It may not exist, or the active user may not have access permissions."
    )
  }

  return(path_out)
}
