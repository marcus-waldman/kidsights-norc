# Kidsights-NORC

Sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Overview

This repository provides standalone R scripts that connect to REDCap via API to monitor:

- **Eligibility form** - Raw variables from the Eligibility Form NORC instrument
- **Survey completion** - Module-by-module tracking with completion percentages
- **Demographics** - Child and parent characteristics for sample monitoring

## Current Status

✅ **SMOKE TEST PASSING** — The monitoring script runs end-to-end against the **4 production REDCap projects** (Kidsights Survey NORC 1–4), combining **10,200 records** into a single set of monitoring data frames.

### Smoke Test Results

| Component | Result |
|---|---|
| REDCap API connection | ✅ 10,200 records across 4 projects (NORC 1/2/3 = 2,500 each, NORC 4 = 2,700) |
| Cross-project dictionary validation | ✅ 865 fields, identical across all 4 projects |
| Data transforms | ✅ All demographic derivations succeed |
| Eligibility form | ✅ 15 raw variables extracted from `eligibility_form_norc` instrument |
| Survey completion | ✅ Per-participant denominator (7–11) |
| Child demographics | ✅ 10,200 records (child 1 + child 2 columns) |
| Parent demographics | ✅ 10,200 records |
| Compensation info | ✅ 10,200 records |
| `redcap_project_name` tag | ✅ Present on all 5 output frames for per-project traceability |

### MN26 Migration Status

Variables updated for MN26 NORC field names and value codes (see `CLAUDE.md` for full mapping):

- ✅ Race/ethnicity (parent, child 1, child 2) — `sq002b___*`, `cqr010b___*`
- ✅ Child sex — swapped codes, `sex_norc`
- ✅ Parent gender — `mn2` replaces `cqr002`, includes Non-binary
- ✅ Education — codes 0-8, `educ_a1_norc`
- ✅ Marital status — codes 0-5, `marital_status_label_norc`
- ✅ Age — `age_in_days_n` / `age_in_days_c2_n`
- ✅ State eligibility — `mn_eqstate`
- ✅ Compensation — `store_choice_label`
- ✅ Data dictionary utility — `get_data_dictionary()`
- ✅ Survey completion — per-participant denominator with conditional child 2 and NSCH logic

### Running the Smoke Test

Run `progress-monitoring/mn26/smoke-test.R`. **You must update the `csv_path` in `smoke-test.R` to point to your local copy of the API credentials CSV.**

## Quick Start

### 1. Install R Dependencies

```r
install.packages(c("dplyr", "tidyr", "REDCapR", "httr"))
```

### 2. Create API Credentials File

Create a CSV file with your REDCap API credentials (use `progress-monitoring/mn26/mn26_redcap_api_template.csv` as template). Include **one row per REDCap project** — the MN26 production setup uses 4 projects:

```csv
project,pid,api_code
Kidsights Survey NORC 1,8609,YOUR_API_TOKEN_HERE
Kidsights Survey NORC 2,8729,YOUR_API_TOKEN_HERE
Kidsights Survey NORC 3,8841,YOUR_API_TOKEN_HERE
Kidsights Survey NORC 4,8952,YOUR_API_TOKEN_HERE
```

| Column | Description |
|--------|-------------|
| `project` | Descriptive name for the REDCap project (also flows into the output as `redcap_project_name`) |
| `pid` | REDCap project ID |
| `api_code` | REDCap API token for that project |

All projects must share the same data dictionary (field names, types, and choices). The pipeline validates this automatically and errors if any project's dictionary is inconsistent. The pipeline iterates over all rows in the CSV — adding or removing projects requires no code changes.

**Security Note**: Store this file outside the repository (e.g., `C:/Users/YOUR_USERNAME/my-APIs/` or `C:/my_auths/`) and **never commit it to git**.

### 3. Run the Monitoring Report

```r
# Load the script
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/my_auths/kidsights_redcap_norc_MN_2026.csv"
)

# View results
View(monitoring_data$eligibility_form)
table(monitoring_data$survey_completion$modules_complete == monitoring_data$survey_completion$n_required)
View(monitoring_data$child_demographics)
View(monitoring_data$parent_demographics)

# Per-project record counts (any of the 5 frames will work)
table(monitoring_data$child_demographics$redcap_project_name)
```

## Repository Structure

```
kidsights-norc/
├── progress-monitoring/
│   └── mn26/
│       ├── monitoring_report.R          # Main monitoring script
│       ├── synthetic-test.R             # Offline tests (133 assertions, multi-project coverage)
│       ├── smoke-test.R                 # Live smoke test (requires API; 4 production projects)
│       ├── mn26_redcap_api_template.csv # API credentials template
│       ├── README.md                     # Detailed documentation
│       ├── docs/
│       │   ├── monitoring_data_dictionary.qmd  # Data dictionary source
│       │   └── monitoring_data_dictionary.html  # Rendered data dictionary
│       └── utils/
│           ├── redcap_utils.R           # REDCap API functions
│           ├── data_transforms.R        # Data transformation functions
│           └── safe_joins.R             # Safe join utilities
├── docs/
│   └── index.html                        # GitHub Pages data dictionary
├── CLAUDE.md                             # Development guide for AI assistants
└── README.md                             # This file
```

## Features

### Self-Contained Design
- No external pipeline dependencies
- No database connections required
- Simple function call with CSV path
- Standalone utility functions

### Secure API Management
- CSV-based credentials (not environment variables)
- Multiple REDCap projects supported
- Each collaborator maintains their own local credentials file
- `.gitignore` configured to exclude sensitive files

### Comprehensive Monitoring Output

The script returns 5 data frames. Every frame includes `pid`, `record_id`, and **`redcap_project_name`** (the source project tag) so each row can be traced back to one of the 4 production REDCap projects.

1. **Eligibility Form** - Raw variables from the `eligibility_form_norc` instrument (15 fields + completion flag). Note: legacy `eq002`/`eq003`/`mn_eqstate` live in the old `eligibility_form` instrument and are *not* in this output.
2. **Survey Completion** - Module-by-module completion tracking
3. **Child Demographics** - Age and sex distribution
4. **Parent Demographics** - Age, sex, race/ethnicity, education, marital status
5. **Compensation Information** - Gift card store choice and contact details

## Required REDCap Variables

The monitoring script requires access to raw REDCap variables through the API:

- **Identifiers**: `pid`, `record_id` (the source project name is added automatically as `redcap_project_name`)
- **Eligibility screening**: `eq001`, `eq002`, `eq003`, `mn_eqstate`, `age_in_days_n` *(eq*/mn_eqstate live in the legacy `eligibility_form` instrument and are pulled into raw_data but are not exposed in `$eligibility_form`)*
- **Eligibility form (NORC)**: `consent_date_n`, `age_under_6_n`, `kids_u6_n`, `dob_n`, `parent_guardian_c1_n`, etc. — all fields whose `form_name == "eligibility_form_norc"`
- **Survey completion**: `consent_doc_complete`, `eligibility_form_norc_complete`, `module_2_family_information_complete`, `module_3_child_information_complete`, `module_6_*_complete` (8 age bands × 2 children), `nsch_questions_complete`, `child_information_2_954c_complete`, `module_8_followup_information_complete`, `module_9_compensation_information_complete`
- **Child 1 demographics**: `age_in_days_n`, `cqr009`, `cqr010b___*` (race checkboxes), `cqr011`
- **Child 2 demographics**: `age_in_days_c2_n`, `cqr009_c2`, `cqr010_c2b___*` (race checkboxes), `cqr011_c2`, `dob_c2_n`
- **Parent demographics**: `mn2` (gender), `cqr003`, `cqr004`, `sq002b___*` (race checkboxes), `sq003`, `cqfa001`
- **Compensation**: `store_choice`, `q1394`, `q1394a`, `email_incentive`

See `progress-monitoring/mn26/README.md` for complete variable list and data governance details.

## Remaining Migration Items

Search for `[MN26 TODO]` comments for items still needing updates:

1. **Multi-child eligibility** - Per-child age eligibility checking
2. **Geography** - Geocoding integration for geographic monitoring

## Documentation

- **`progress-monitoring/mn26/README.md`** - Detailed documentation including variable requirements, API setup, output descriptions, and adaptation guide
- **`CLAUDE.md`** - Development guide for Claude Code with architecture overview and key commands

## Security Notes

⚠️ **NEVER commit the following to git:**
- API credentials CSV files
- Any files containing REDCap API tokens
- Protected health information (PHI)

The repository `.gitignore` is configured to exclude sensitive files automatically.

## Contact

For questions about adapting this script for MN26 data, contact Marcus Waldman.

## License

Internal NORC research tool. Not for public distribution.
