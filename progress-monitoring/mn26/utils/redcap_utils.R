#' REDCap API Utilities
#'
#' Functions for loading API credentials and extracting data from REDCap projects.

#' Load API credentials from CSV file
#'
#' CSV format: project, pid, api_code
#'
#' @param csv_path Path to API credentials CSV file
#' @return Data frame with credentials
load_api_credentials <- function(csv_path) {

  if (!file.exists(csv_path)) {
    stop(paste("API credentials file not found:", csv_path))
  }

  credentials <- read.csv(csv_path, stringsAsFactors = FALSE)

  required_cols <- c("project", "pid", "api_code")
  missing_cols <- setdiff(required_cols, names(credentials))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in credentials file:", paste(missing_cols, collapse = ", ")))
  }

  message("[OK] Loaded ", nrow(credentials), " API credential(s)")
  return(credentials)
}

#' Get REDCap data dictionary as a named list
#'
#' Pulls the metadata (data dictionary) from a REDCap project via API.
#' Returns a named list keyed by field_name, optionally filtering out
#' fields marked with @HIDDEN in field_annotation.
#'
#' @param redcap_url REDCap API URL
#' @param token API token
#' @param exclude_hidden Logical, whether to exclude @HIDDEN fields (default TRUE)
#' @return Named list where each element is a field's metadata
get_data_dictionary <- function(redcap_url, token, exclude_hidden = TRUE) {

  resp <- httr::POST(
    redcap_url,
    body = list(token = token, content = "metadata",
                format = "json", returnFormat = "json"),
    encode = "form"
  )

  if (httr::status_code(resp) != 200) {
    stop("REDCap metadata API error: ", httr::status_code(resp))
  }

  dict_list <- httr::content(resp)

  if (exclude_hidden) {
    dict_list <- Filter(function(d) {
      ann <- d$field_annotation
      is.null(ann) || !grepl("@HIDDEN", ann)
    }, dict_list)
  }

  dict_named <- list()
  for (d in dict_list) {
    dict_named[[d$field_name]] <- d
  }

  message("[OK] Data dictionary: ", length(dict_named), " fields",
          if (exclude_hidden) " (after excluding @HIDDEN)" else "")
  return(dict_named)
}

#' Compare two data dictionaries for consistency
#'
#' Checks that two dictionaries (named lists from get_data_dictionary()) have
#' the same field names, field types, and select choices.
#'
#' @param dict_a Named list (reference dictionary)
#' @param dict_b Named list (dictionary to compare)
#' @return Character vector of mismatch descriptions (empty if consistent)
validate_dictionaries <- function(dict_a, dict_b) {

  mismatches <- character(0)

  fields_a <- names(dict_a)
  fields_b <- names(dict_b)

  # Check for fields missing in either direction
  only_in_a <- setdiff(fields_a, fields_b)
  only_in_b <- setdiff(fields_b, fields_a)

  if (length(only_in_a) > 0) {
    mismatches <- c(mismatches,
      paste0("Fields in reference but not in comparison: ",
             paste(only_in_a, collapse = ", ")))
  }
  if (length(only_in_b) > 0) {
    mismatches <- c(mismatches,
      paste0("Fields in comparison but not in reference: ",
             paste(only_in_b, collapse = ", ")))
  }

  # Check shared fields for type and choices differences
  shared <- intersect(fields_a, fields_b)
  for (fld in shared) {
    type_a <- dict_a[[fld]]$field_type
    type_b <- dict_b[[fld]]$field_type
    if (!identical(type_a, type_b)) {
      mismatches <- c(mismatches,
        paste0("Field '", fld, "' type differs: '", type_a, "' vs '", type_b, "'"))
    }

    choices_a <- dict_a[[fld]]$select_choices_or_calculations
    choices_b <- dict_b[[fld]]$select_choices_or_calculations
    if (!identical(choices_a, choices_b)) {
      mismatches <- c(mismatches,
        paste0("Field '", fld, "' choices differ"))
    }
  }

  return(mismatches)
}

#' Pull raw data from REDCap API
#'
#' Uses the same API parameters as the NE25 pipeline for reliable extraction.
#' MN26 NORC project is hosted on the same UNMC REDCap instance.
#'
#' @param credentials API credentials data frame
#' @param redcap_url REDCap API URL
#' @return List with $data (combined data frame) and $dictionary (from first project)
pull_redcap_data <- function(credentials, redcap_url) {

  message("Pulling data from REDCap API...")
  message("REDCap URL: ", redcap_url)

  all_data <- list()
  all_dictionaries <- list()

  for (i in 1:nrow(credentials)) {
    project_name <- credentials$project[i]
    api_token <- credentials$api_code[i]

    message("  - Extracting from project: ", project_name)

    # Use redcap_read() with consistent parameters (not redcap_read_oneshot)
    result <- tryCatch({
      REDCapR::redcap_read(
        redcap_uri = redcap_url,
        token = api_token,
        raw_or_label = "raw",
        raw_or_label_headers = "raw",
        export_checkbox_label = FALSE,
        export_survey_fields = TRUE,
        export_data_access_groups = FALSE,
        config_options = list(connecttimeout = 300, timeout = 300)
      )
    }, error = function(e) {
      warning("Failed to pull from ", project_name, ": ", e$message)
      return(NULL)
    })

    if (is.null(result) || !result$success) {
      warning("Skipping project: ", project_name)
      next
    }

    # Add source project metadata
    project_data <- result$data %>%
      dplyr::mutate(redcap_project_name = project_name,
                    pid = credentials$pid[i])

    all_data[[project_name]] <- project_data

    # Pull the data dictionary for every project
    dict_result <- tryCatch(
      get_data_dictionary(redcap_url, api_token, exclude_hidden = FALSE),
      error = function(e) {
        warning("Could not pull data dictionary for ", project_name, ": ", e$message)
        NULL
      }
    )
    if (!is.null(dict_result)) {
      all_dictionaries[[project_name]] <- dict_result
    }

    message("    [OK] Retrieved ", nrow(project_data), " records")

    # Brief pause between projects
    Sys.sleep(1)
  }

  if (length(all_data) == 0) {
    stop("No data retrieved from any REDCap projects")
  }

  # Validate data dictionaries across projects
  if (length(all_dictionaries) >= 2) {
    ref_name <- names(all_dictionaries)[1]
    ref_dict <- all_dictionaries[[ref_name]]
    for (j in 2:length(all_dictionaries)) {
      cmp_name <- names(all_dictionaries)[j]
      issues <- validate_dictionaries(ref_dict, all_dictionaries[[cmp_name]])
      if (length(issues) > 0) {
        stop("Data dictionary mismatch between '", ref_name, "' and '", cmp_name, "':\n",
             paste("  -", issues, collapse = "\n"))
      }
    }
    message("[OK] Data dictionaries consistent across ", length(all_dictionaries), " projects")
  }

  combined_data <- dplyr::bind_rows(all_data)
  message("[OK] Total records across all projects: ", nrow(combined_data))

  # Return the first project's dictionary (validated to match all others)
  reference_dict <- if (length(all_dictionaries) > 0) all_dictionaries[[1]] else list()
  return(list(data = combined_data, dictionary = reference_dict))
}
