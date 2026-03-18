# Kidsights-NORC

Sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Overview

This repository provides standalone R scripts that connect to REDCap via API to monitor:

- **Screener completion** - Has eligibility been determined?
- **Eligibility status** - 4 criteria: parent age ≥19, child age 0-5 years, primary caregiver, Minnesota residence
- **Survey completion** - Module-by-module tracking with completion percentages
- **Demographics** - Child and parent characteristics for sample monitoring

## Current Status

🚧 **IN DEVELOPMENT** — The monitoring script has been tested against the NORC NE Smoke Test REDCap project and is not yet fully operational. Below is a summary of what works and what remains to be resolved.

### What Works

- **REDCap API access is confirmed** — successfully connected and retrieved **20 records** and **60 columns** from the NORC NE Smoke Test project using `REDCapR::redcap_read()`
- **Data transforms run successfully** — child age, sex, parent demographics, race/ethnicity derivations all execute without error on the smoke test data

### Variables Present in Smoke Test

| Variable | Used For | Status |
|---|---|---|
| `record_id` | Record identifier | ✅ Present |
| `eqstate` | State residence eligibility | ✅ Present |
| `age_in_days` | Child age eligibility + demographics | ✅ Present |
| `cqr009` | Child sex | ✅ Present |
| `cqr002` | Parent sex | ✅ Present |
| `cqr003` | Parent age | ✅ Present |
| `cqr004` | Parent education | ✅ Present |
| `cqfa001` | Marital status | ✅ Present |
| `sq002___1` – `sq002___16` | Parent race (checkboxes) | ✅ Present |
| `sq003` | Parent ethnicity (Hispanic) | ✅ Present |

### Variables Missing from Smoke Test (IT Request Needed)

| Variable | Used For | Impact |
|---|---|---|
| `pid` | Project identifier used in all output data frames | ❌ Script errors on every `select()` call |
| `eq002` | Primary caregiver status (eligibility criterion 3) | ❌ `calculate_eligibility()` fails |
| `eq003` | Parent age ≥19 check (eligibility criterion 1) | ❌ `calculate_eligibility()` fails |

### Survey Module Column Name Mismatch (Code Fix Needed)

The script expects short column names (`module_X_complete`) but REDCap returns full instrument names. This is a code-side fix, not an IT request.

| Script Expects | Smoke Test Has |
|---|---|
| `module_2_complete` | `module_2_family_information_complete` |
| `module_3_complete` | `module_3_child_information_complete` |
| `module_4_complete` | `module_4_home_learning_environment_complete` |
| `module_5_complete` | `module_5_birthdate_confirmation_complete` |
| `module_6_complete` | 8 age-band variants: `module_6_0_89_complete` through `module_6_1097_2191_complete` |
| `module_7_complete` | `module_7_child_emotions_and_relationships_complete` |
| `module_9_complete` | `module_9_compensation_information_complete` |

### To Resolve

1. **IT request**: Add `pid`, `eq002`, and `eq003` to the API export for the smoke test project
2. **Code fix**: Update survey completion logic to match actual REDCap column names (especially module 6 age-band structure)
3. **Template migration**: Update `[MN26 TODO]` markers once MN26 data dictionary is finalized

## Quick Start

### 1. Install R Dependencies

```r
install.packages(c("dplyr", "tidyr", "REDCapR", "httr"))
```

### 2. Create API Credentials File

Create a CSV file with your REDCap API credentials (use `progress-monitoring/mn26/mn26_redcap_api_template.csv` as template):

```csv
project,pid,api_code
mn26_main_survey,7679,YOUR_API_TOKEN_HERE
```

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
table(monitoring_data$screener_status$screener_status)
table(monitoring_data$eligibility$eligible)
table(monitoring_data$survey_completion$survey_status)
View(monitoring_data$child_demographics)
View(monitoring_data$parent_demographics)
```

## Repository Structure

```
kidsights-norc/
├── progress-monitoring/
│   └── mn26/
│       ├── monitoring_report.R          # Main monitoring script
│       ├── mn26_redcap_api_template.csv # API credentials template
│       ├── README.md                     # Detailed documentation
│       └── utils/
│           ├── redcap_utils.R           # REDCap API functions
│           ├── data_transforms.R        # Data transformation functions
│           └── safe_joins.R             # Safe join utilities
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

1. **Screener Status** - Tracks whether eligibility has been determined
2. **Eligibility** - Four eligibility criteria with overall determination
3. **Survey Completion** - Module-by-module completion tracking
4. **Child Demographics** - Age and sex distribution
5. **Parent Demographics** - Age, sex, race/ethnicity, education, marital status

## Required REDCap Variables

The monitoring script requires access to **28 raw REDCap variables** through the API:

- **Identifiers**: `pid`, `record_id`
- **Eligibility screening**: `eq001`, `eq002`, `eq003`, `eqstate`, `age_in_days`
- **Survey completion**: `module_2_complete` through `module_9_complete`
- **Child demographics**: `age_in_days`, `cqr009`
- **Parent demographics**: `cqr002`, `cqr003`, `cqr004`, `sq002___*` (race checkboxes), `sq003`, `cqfa001`

See `progress-monitoring/mn26/README.md` for complete variable list and data governance details.

## Adapting for MN26 Data

When MN26 data collection begins, search for `[MN26 TODO]` comments to identify areas requiring updates:

1. **REDCap URL** - Update to Minnesota REDCap instance
2. **Variable names** - Verify against MN26 data dictionary
3. **Module list** - Update to match MN26 survey structure
4. **State code** - Change eligibility check from Nebraska to Minnesota
5. **Multi-child handling** - MN26 allows up to 2 children per household

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
