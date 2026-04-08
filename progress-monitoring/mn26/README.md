# MN26 Sample Monitoring Scripts

Scripts for NORC researchers to monitor Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Current Status

**SMOKE TEST PASSING** — The monitoring script runs end-to-end against the **4 production REDCap projects** (Kidsights Survey NORC 1–4), combining **10,200 records** into a single set of monitoring data frames. Per-project record breakdown: NORC 1/2/3 = 2,500 each, NORC 4 = 2,700. Every output frame includes a `redcap_project_name` column for per-project traceability. Remaining `[MN26 TODO]` items (multi-child eligibility, geography/geocoding) will be updated as needed.

## Required REDCap API Access

**For Security/Data Governance:** The monitoring script requires access to the following **raw REDCap variables** through the API. These are the minimum variables needed for sample monitoring.

### Identifiers (Required)
- `pid` - Participant ID
- `record_id` - REDCap record ID

### Eligibility Screening (Required)
- `eq001` - Informed consent (in `consent_doc` instrument)
- `eq002` - Primary caregiver status (in legacy `eligibility_form` instrument)
- `eq003` - Parent/caregiver age (19+ years) (in legacy `eligibility_form` instrument)
- `mn_eqstate` - Minnesota residence (in legacy `eligibility_form` instrument)
- `age_in_days_n` - Child 1 age in days (in `eligibility_form_norc` instrument; calculated from DOB by REDCap)
- `age_in_days_c2_n` - Child 2 age in days (in `eligibility_form_norc` instrument; if applicable)

> **Note:** `eq002`/`eq003`/`mn_eqstate` live in the *legacy* `eligibility_form` REDCap instrument (a holdover from NE25), not in the newer `eligibility_form_norc` instrument. They are still pulled into raw data and remain available for downstream eligibility logic, but they do **not** appear in the `$eligibility_form` output frame, which is filtered to `form_name == "eligibility_form_norc"` only.

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
- `project`: Descriptive project name (e.g., `"Kidsights Survey NORC 1"`). This value is also propagated into every output data frame as the `redcap_project_name` column for per-project traceability.
- `pid`: REDCap project ID number (e.g., 8609)
- `api_code`: REDCap API token (long alphanumeric string)

**Example CSV (MN26 production = 4 projects):**
```csv
project,pid,api_code
Kidsights Survey NORC 1,8609,ABC123XYZ...
Kidsights Survey NORC 2,8729,DEF456ABC...
Kidsights Survey NORC 3,8841,GHI789DEF...
Kidsights Survey NORC 4,8952,JKL012GHI...
```

**Security Notes:**
- ⚠️ **NEVER commit this CSV file to git** (it contains sensitive API tokens)
- Store in a secure location outside the repository (e.g., `C:/Users/YOUR_USERNAME/my-APIs/`)
- The `.gitignore` is configured to exclude all CSV files with "api" in the name
- Each collaborator maintains their own local CSV file

### Multiple Projects

The MN26 production setup uses **4 REDCap projects** (one per recruitment site), and the script handles any number of projects automatically — it iterates over every row in the credentials CSV. The pipeline:

1. Pulls raw data from each project via the REDCap API
2. Tags each row with `redcap_project_name` (from the `project` column)
3. Validates that the data dictionaries match across all projects (errors with a descriptive message if any field name, type, or choice list differs)
4. `bind_rows()` everything into a single combined data frame before transformation

Adding or removing projects requires no code changes — just edit the credentials CSV.

### Simple Function Call

Just pass the CSV path directly to the function - no environment variables or config files needed:

```r
monitoring_data <- generate_monitoring_report(csv_path = "C:/path/to/your/credentials.csv")
```

That's it!

## Files

- `monitoring_report.R` - Main standalone script for generating monitoring reports
- `smoke-test.R` - Smoke test against live REDCap (requires API access; configured for the 4 production projects)
- `synthetic-test.R` - Offline synthetic data tests (no API needed, **133 assertions** including a multi-project bind_rows test section)
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

**CSV Format (4-project production setup):**
```csv
project,pid,api_code
Kidsights Survey NORC 1,8609,ABC123XYZ456...
Kidsights Survey NORC 2,8729,DEF456ABC789...
Kidsights Survey NORC 3,8841,GHI789DEF012...
Kidsights Survey NORC 4,8952,JKL012GHI345...
```

**Columns:**
- `project`: Project name (descriptive identifier; also exposed in outputs as `redcap_project_name`)
- `pid`: REDCap project ID number
- `api_code`: REDCap API token for that project

**Save securely** (NOT in git repository):
```
C:/my_auths/kidsights_redcap_norc_MN_2026.csv
```

### 2. Run the Monitoring Report

```r
# Load the script
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report (pass CSV path)
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/my_auths/kidsights_redcap_norc_MN_2026.csv"
)

# Explore the results
View(monitoring_data$eligibility_form)
View(monitoring_data$survey_completion)
View(monitoring_data$child_demographics)
View(monitoring_data$parent_demographics)

# Per-project record counts
table(monitoring_data$child_demographics$redcap_project_name)
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

The `generate_monitoring_report()` function returns a list with 5 data frames. Every frame includes `pid`, `record_id`, and **`redcap_project_name`** (the source REDCap project name from the credentials CSV) so each row can be traced back to one of the 4 production projects.

### 1. Eligibility Form
All raw variables from the "Eligibility Form NORC" REDCap instrument, identified via the data dictionary's `form_name` field. Includes checkbox expansions and the instrument completion flag. In the 4 production projects this resolves to **15 fields + 1 completion flag**.

**Columns:**
- `pid`, `record_id`, `redcap_project_name`: Identifiers / source project tag
- All fields where `form_name == "eligibility_form_norc"` in the data dictionary — e.g., `consent_date_n`, `age_under_6_n`, `kids_u6_n`, `dob_n`, `age_in_days_n`, `parent_guardian_c1_n`, `dob_c2_n`, `age_in_days_c2_n`, etc.
- `eligibility_form_norc_complete`: REDCap completion status (2 = complete)

> **Important:** The legacy `eq002`/`eq003`/`mn_eqstate` fields live in the *old* `eligibility_form` instrument and are **not** part of this output. They remain in `raw_data` for downstream eligibility logic but are intentionally excluded from `$eligibility_form`.

**Example:**
```r
View(monitoring_data$eligibility_form)
```

### 2. Survey Completion
Tracks module-by-module completion with per-participant denominator.

**Columns:**
- `pid`, `record_id`, `redcap_project_name`: Identifiers / source project tag
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
- `pid`, `record_id`, `redcap_project_name`: Identifiers / source project tag
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
- `pid`, `record_id`, `redcap_project_name`: Identifiers / source project tag
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
- `pid`, `record_id`, `redcap_project_name`: Identifiers / source project tag
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
