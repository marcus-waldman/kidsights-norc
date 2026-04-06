# Kidsights-NORC

Sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Overview

This repository provides standalone R scripts that connect to REDCap via API to monitor:

- **Eligibility form** - Raw variables from the Eligibility Form NORC instrument
- **Survey completion** - Module-by-module tracking with completion percentages
- **Demographics** - Child and parent characteristics for sample monitoring

## Current Status

✅ **SMOKE TEST PASSING** — The monitoring script runs end-to-end against the NORC MN test REDCap project (2,654 records, 976 columns).

### Smoke Test Results

| Component | Result |
|---|---|
| REDCap API connection | ✅ 2,654 records retrieved |
| Data dictionary | ✅ 865 fields (648 after @HIDDEN filtering) |
| Data transforms | ✅ All demographic derivations succeed |
| Eligibility form | ✅ Raw variables extracted from data dictionary |
| Survey completion | ✅ 7 complete, per-participant denominator (7-11) |
| Child demographics | ✅ 2,654 records (child 1 + child 2 columns) |
| Parent demographics | ✅ 2,654 records |
| Compensation info | ✅ 2,654 records |

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

Create a CSV file with your REDCap API credentials (use `progress-monitoring/mn26/mn26_redcap_api_template.csv` as template). Include one row per REDCap project:

```csv
project,pid,api_code
mn26_project_1,8609,YOUR_API_TOKEN_HERE
mn26_project_2,8729,YOUR_API_TOKEN_HERE
```

| Column | Description |
|--------|-------------|
| `project` | Descriptive name for the REDCap project |
| `pid` | REDCap project ID |
| `api_code` | REDCap API token for that project |

All projects must share the same data dictionary (field names, types, and choices). The pipeline validates this automatically and errors if any project's dictionary is inconsistent.

**Security Note**: Store this file outside the repository (e.g., `C:/Users/YOUR_USERNAME/my-APIs/`) and **never commit it to git**.

### 3. Run the Monitoring Report

```r
# Load the script
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/Users/YOUR_USERNAME/my-APIs/mn26_redcap_api.csv"
)

# View results
View(monitoring_data$eligibility_form)
table(monitoring_data$survey_completion$modules_complete == monitoring_data$survey_completion$n_required)
View(monitoring_data$child_demographics)
View(monitoring_data$parent_demographics)
```

## Repository Structure

```
kidsights-norc/
├── progress-monitoring/
│   └── mn26/
│       ├── monitoring_report.R          # Main monitoring script
│       ├── synthetic-test.R             # Offline tests (102 assertions)
│       ├── smoke-test.R                 # Live smoke test (requires API)
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

The script returns 5 data frames:

1. **Eligibility Form** - All raw variables from the Eligibility Form NORC instrument
2. **Survey Completion** - Module-by-module completion tracking
3. **Child Demographics** - Age and sex distribution
4. **Parent Demographics** - Age, sex, race/ethnicity, education, marital status
5. **Compensation Information** - Gift card store choice and contact details

## Required REDCap Variables

The monitoring script requires access to raw REDCap variables through the API:

- **Identifiers**: `pid`, `record_id`
- **Eligibility screening**: `eq001`, `eq002`, `eq003`, `mn_eqstate`, `age_in_days_n`
- **Survey completion**: `module_2_complete` through `module_9_complete`
- **Child 1 demographics**: `age_in_days_n`, `cqr009`, `cqr010b___*` (race checkboxes), `cqr011`
- **Child 2 demographics**: `age_in_days_c2_n`, `cqr009_c2`, `cqr010_c2b___*` (race checkboxes), `cqr011_c2`
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
