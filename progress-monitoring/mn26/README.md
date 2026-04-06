# MN26 Sample Monitoring Scripts

Scripts for NORC researchers to monitor Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Current Status

**SMOKE TEST PASSING** — The monitoring script runs end-to-end against the NORC MN test REDCap project. Remaining `[MN26 TODO]` items (multi-child eligibility, geography/geocoding) will be updated as needed.

## Required REDCap API Access

**For Security/Data Governance:** The monitoring script requires access to the following **raw REDCap variables** through the API. These are the minimum variables needed for sample monitoring.

### Identifiers (Required)
- `pid` - Participant ID
- `record_id` - REDCap record ID

### Eligibility Screening (Required)
- `eq001` - Informed consent
- `eq002` - Primary caregiver status
- `eq003` - Parent/caregiver age (19+ years)
- `mn_eqstate` - Minnesota residence
- `age_in_days_n` - Child 1 age in days (calculated from DOB by REDCap)
- `age_in_days_c2_n` - Child 2 age in days (if applicable)

### Survey Completion Status (Required)
- `module_2_complete` - Module 2 completion status
- `module_3_complete` - Module 3 completion status
- `module_4_complete` - Module 4 completion status
- `module_5_complete` - Module 5 completion status
- `module_6_complete` - Module 6 completion status
- `module_7_complete` - Module 7 completion status
- `module_9_complete` - Module 9 completion status

**Note:** Module list may change for MN26 depending on final questionnaire structure.

### Child 1 Demographics (Required)
- `age_in_days_n` - Child age (already listed above)
- `cqr009` - Child sex (1=Female, 0=Male — same as NE25)
- `cqr010b` - Child race (checkbox, check all that apply):
  - `cqr010b___100` (American Indian or Alaska Native), `___101` (Asian), `___102` (Black or African American), `___103` (Native Hawaiian or Other Pacific Islander), `___104` (White), `___105` (Other)
- `cqr011` - Child Hispanic/Latino ethnicity (0=No, 1=Yes)

### Child 2 Demographics (if applicable)
- `age_in_days_c2_n` - Child 2 age (already listed above)
- `cqr009_c2` - Child 2 sex (1=Female, 0=Male)
- `cqr010_c2b` - Child 2 race (checkbox, same codes as child 1):
  - `cqr010_c2b___100` through `___105`
- `cqr011_c2` - Child 2 Hispanic/Latino ethnicity (0=No, 1=Yes)

### Parent/Caregiver Demographics (Required)
- `mn2` - Respondent gender (0=Female, 1=Male, 97=Non-binary) — replaces `cqr002`
- `cqr003` - Respondent age in years
- `cqr004` - Respondent education level (codes 0-8)
- `sq002b` - Respondent race (checkbox, check all that apply):
  - `sq002b___100` (American Indian or Alaska Native), `___101` (Asian), `___102` (Black or African American), `___103` (Native Hawaiian or Other Pacific Islander), `___104` (White), `___105` (Other)
- `sq003` - Respondent Hispanic/Latino ethnicity (0=No, 1=Yes)
- `cqfa001` - Marital status

### Compensation (Module 9)
- `store_choice` - Gift card store choice (1=Lowe's, 2=Amazon, 3=Walmart, 4=Target)
- `q1394` - First name
- `q1394a` - Last name
- `email_incentive` - Email address

### Data Transformations

The monitoring script includes built-in transforms in `utils/data_transforms.R` that convert raw REDCap variables to labeled/derived variables:

1. **Child 1 age** (`age_in_days_n` → `years_old`)
2. **Child 2 age** (`age_in_days_c2_n` → `years_old_c2`)
3. **Child 1 sex** (`cqr009` → `sex_norc`: 1=Female, 0=Male — same as NE25)
4. **Child 2 sex** (`cqr009_c2` → `sex_c2_norc`)
5. **Child 1 race/ethnicity** (`cqr010b___*` + `cqr011` → `race_norc`, `hisp`, `raceG_norc`)
6. **Child 2 race/ethnicity** (`cqr010_c2b___*` + `cqr011_c2` → `race_c2_norc`, `hisp_c2`, `raceG_c2_norc`)
7. **Parent gender** (`mn2` → `a1_gender_norc`: 0=Female, 1=Male, 97=Non-binary — replaces `cqr002`)
8. **Parent age** (`cqr003` → `a1_years_old`)
9. **Parent race/ethnicity** (`sq002b___*` + `sq003` → `a1_race_norc`, `a1_hisp`, `a1_raceG_norc`)
10. **Parent education** (`cqr004` → `educ_a1_norc` with codes 0-8, same as NE25)
11. **Marital status** (`cqfa001` → `marital_status_label_norc` with codes 0-5)
12. **Gift card store** (`store_choice` → `store_choice_label`: Lowe's/Amazon/Walmart/Target)

Variables use the `_norc` suffix where MN26 value codes differ from the NE25 pipeline.

## API Credentials Management

### CSV File Structure

The monitoring script uses a **CSV file** to manage REDCap API credentials, following the same pattern as the NE25 pipeline.

**Template:** `mn26_redcap_api_template.csv`

**Required Columns:**
- `project`: Descriptive project name (e.g., "mn26_main_survey")
- `pid`: REDCap project ID number (e.g., 7679)
- `api_code`: REDCap API token (long alphanumeric string)

**Example CSV:**
```csv
project,pid,api_code
mn26_main_survey,7679,ABC123XYZ456DEF789...
mn26_follow_up,8014,GHI012JKL345MNO678...
```

**Security Notes:**
- ⚠️ **NEVER commit this CSV file to git** (it contains sensitive API tokens)
- Store in a secure location outside the repository (e.g., `C:/Users/YOUR_USERNAME/my-APIs/`)
- The `.gitignore` is configured to exclude all CSV files with "api" in the name
- Each collaborator maintains their own local CSV file

### Multiple Projects

If MN26 has multiple REDCap projects (e.g., main survey, follow-up, email registration), add them as separate rows in the CSV:

```csv
project,pid,api_code
mn26_main_survey,7679,TOKEN_1_HERE
mn26_email_registration,7943,TOKEN_2_HERE
mn26_follow_up,8014,TOKEN_3_HERE
```

The monitoring script will automatically combine data from all projects.

### Simple Function Call

Just pass the CSV path directly to the function - no environment variables or config files needed:

```r
monitoring_data <- generate_monitoring_report(csv_path = "C:/path/to/your/credentials.csv")
```

That's it!

## Files

- `monitoring_report.R` - Main standalone script for generating monitoring reports
- `smoke-test.R` - Smoke test against live REDCap (requires API access)
- `synthetic-test.R` - Offline synthetic data tests (no API needed, 102 assertions)
- `mn26_redcap_api_template.csv` - Template for API credentials CSV file
- `utils/redcap_utils.R` - REDCap API functions including `get_data_dictionary()`
- `utils/data_transforms.R` - Data transformation functions (value labeling)
- `utils/safe_joins.R` - Safe join utilities
- `docs/monitoring_data_dictionary.qmd` - Data dictionary source (Quarto)
- `docs/monitoring_data_dictionary.html` - Data dictionary (rendered HTML)

### Data Dictionary on GitHub Pages

The data dictionary is published at **https://marcus-waldman.github.io/kidsights-norc/**.

After editing and re-rendering the `.qmd` source, update the GitHub Pages site:

```bash
cd progress-monitoring/mn26/docs
quarto render monitoring_data_dictionary.qmd
cp monitoring_data_dictionary.html ../../../docs/index.html
```

Then commit and push both files.

## Quick Start

### 1. Create API Credentials CSV

Create a CSV file with your REDCap API credentials (use `mn26_redcap_api_template.csv` as a template):

**CSV Format:**
```csv
project,pid,api_code
mn26_main_survey,7679,ABC123XYZ456...
```

**Columns:**
- `project`: Project name (descriptive identifier)
- `pid`: REDCap project ID number
- `api_code`: REDCap API token for that project

**Save securely** (NOT in git repository):
```
C:/Users/YOUR_USERNAME/my-APIs/mn26_redcap_api.csv
```

### 2. Run the Monitoring Report

```r
# Load the script
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report (pass CSV path)
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/Users/YOUR_USERNAME/my-APIs/mn26_redcap_api.csv"
)

# Explore the results
View(monitoring_data$eligibility_form)
View(monitoring_data$survey_completion)
View(monitoring_data$child_demographics)
View(monitoring_data$parent_demographics)
```

### 3. Pull the REDCap Data Dictionary

The `get_data_dictionary()` utility function returns the REDCap data dictionary as a named list, keyed by field name. By default it excludes fields marked `@HIDDEN` (fields not administered in MN26).

```r
# Load the utilities
source("progress-monitoring/mn26/utils/redcap_utils.R")

# Load credentials
creds <- load_api_credentials("C:/Users/YOUR_USERNAME/my-APIs/mn26_redcap_api.csv")

# MN26 dictionary only (excludes @HIDDEN fields)
dict_mn <- get_data_dictionary(
  redcap_url = "https://unmcredcap.unmc.edu/redcap/api/",
  token = creds$api_code[1]
)

# Full dictionary (includes @HIDDEN fields)
dict_all <- get_data_dictionary(
  redcap_url = "https://unmcredcap.unmc.edu/redcap/api/",
  token = creds$api_code[1],
  exclude_hidden = FALSE
)

# Access a specific field's metadata
dict_mn[["cqr009"]]$field_label
dict_mn[["cqr009"]]$select_choices_or_calculations

# List all field names
names(dict_mn)
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `redcap_url` | Yes | -- | REDCap API endpoint URL |
| `token` | Yes | -- | REDCap API token (from credentials CSV) |
| `exclude_hidden` | No | `TRUE` | Exclude fields with `@HIDDEN` annotation |

## Output Data Frames

The `generate_monitoring_report()` function returns a list with 5 data frames:

### 1. Eligibility Form
All raw variables from the "Eligibility Form NORC" REDCap instrument, identified via the data dictionary's `form_name` field. Includes checkbox expansions and the instrument completion flag.

**Columns:**
- `pid`, `record_id`: Identifiers
- All fields where `form_name == "eligibility_form_norc"` in the data dictionary (e.g., `eq002`, `eq003`, `mn_eqstate`, `age_in_days_n`)
- `eligibility_form_norc_complete`: REDCap completion status (2 = complete)

**Example:**
```r
View(monitoring_data$eligibility_form)
```

### 2. Survey Completion
Tracks module-by-module completion with per-participant denominator.

**Columns:**
- `pid`, `record_id`: Identifiers
- `n_required`: Per-participant required module count (7-11)
- `modules_complete`: Count of completed modules
- `pct_complete`: Percentage complete
- `last_module_complete`: Name of last completed instrument in order

**Example:**
```r
# Completion summary
table(monitoring_data$survey_completion$modules_complete == monitoring_data$survey_completion$n_required)
```

### 3. Child Demographics
Age, sex, and race/ethnicity for each child participant.

**Columns:**
- `pid`, `record_id`: Identifiers
- `age_years`: Child's age in years (0-5)
- `sex`: Child's sex (Female/Male)
- `race_norc`: Child 1 race (White, Black or African American, American Indian or Alaska Native, Asian, Native Hawaiian or Other Pacific Islander, Other, Two or More)
- `hisp`: Child 1 Hispanic/Latino ethnicity (Hispanic/non-Hisp.)
- `raceG_norc`: Child 1 combined race/ethnicity
- `race_c2_norc`, `hisp_c2`, `raceG_c2_norc`: Same variables for child 2 (NA if no second child)

**Example:**
```r
# Age distribution
summary(monitoring_data$child_demographics$age_years)

# Sex distribution
table(monitoring_data$child_demographics$sex_norc)

# Race/ethnicity distribution
table(monitoring_data$child_demographics$raceG_norc)
```

### 4. Parent Demographics
Demographics for the primary caregiver (respondent).

**Columns:**
- `pid`, `record_id`: Identifiers
- `age_years`: Primary caregiver age in years
- `gender`: Parent gender ("Female", "Male", "Non-binary")
- `race_ethnicity`: Race/ethnicity combined (`a1_raceG_norc`)
- `education`: Education level (`educ_a1_norc`, codes 0-8)
- `marital_status_label_norc`: Marital status label ("Married", "Divorced", etc.)

**Example:**
```r
# Age distribution
summary(monitoring_data$parent_demographics$age_years)

# Gender distribution
table(monitoring_data$parent_demographics$gender)

# Race/ethnicity distribution
table(monitoring_data$parent_demographics$race_ethnicity)

# Education distribution
table(monitoring_data$parent_demographics$education)

# Marital status distribution
table(monitoring_data$parent_demographics$marital_status_label_norc)
```

### 5. Compensation Information
Gift card and contact information from Module 9.

**Columns:**
- `pid`, `record_id`: Identifiers
- `store_choice_label`: Gift card store ("Lowe's", "Amazon", "Walmart", "Target")
- `q1394`: First name
- `q1394a`: Last name
- `email_incentive`: Email address

**Example:**
```r
table(monitoring_data$compensation_information$store_choice_label)
```

## Eligibility Criteria

The script implements the 4 eligibility criteria identified by Kanru:

1. **Parent Age**: Respondent must be 19 years of age or older
2. **Child Age**: Child must be 0-5 years old (calculated from date of birth)
3. **Primary Caregiver**: Respondent must be a primary caregiver for the child
4. **State Residence**: Respondent and child must currently live in Minnesota

## Survey Completion

Survey completion uses MN26 instrument order (1-25), confirmed by Vinod (2026-04-02). Instruments 26-29 are ignored (old NE25 instruments, disconnected).

**Always required** (instruments 1-4, 24-25):
- Consent, Eligibility (NORC), Family Info, Child Info, Compensation, Follow-up

**Module 6 (child 1)**: One age-band sub-instrument per child (instruments 5-12)

**Conditionally required**:
- NSCH Questions (child 1): only if `age_in_days_n` between 365-1065 days
- Child 2 instruments (14-23): only if `dob_c2_n` is not empty
- NSCH Questions (child 2): only if child 2 exists AND age 365-1065 days

The denominator (`n_required`) is per-participant, ranging from 7 to 11 depending on number of children and NSCH eligibility.

## Remaining [MN26 TODO] Items

1. **Multi-child eligibility** — Per-child age eligibility checking
2. **Geography** — Geocoding integration for geographic monitoring

## Contact

For questions about adapting this script for MN26 data, contact Marcus Waldman.
