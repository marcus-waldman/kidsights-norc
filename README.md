# Kidsights-NORC

Sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution during data collection.

## Overview

This repository provides standalone R scripts that connect to REDCap via API to monitor:

- **Screener completion** - Has eligibility been determined?
- **Eligibility status** - 4 criteria: parent age ≥19, child age 0-5 years, primary caregiver, Minnesota residence
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
| Eligibility | ✅ Calculated (0 eligible in test data — most fields unpopulated) |
| Screener status | ✅ 2,654 records |
| Survey completion | ⚠️ Runs but module list needs verification ([#1](https://github.com/marcus-waldman/kidsights-norc/issues/1)) |
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
- ⚠️ Survey completion module list — needs verification ([#1](https://github.com/marcus-waldman/kidsights-norc/issues/1))

### Running the Smoke Test

Run `progress-monitoring/mn26/smoke-test.R`. **You must update the `csv_path` in `smoke-test.R` to point to your local copy of the API credentials CSV.**

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

1. **Module list** - Verify survey completion modules match MN26 structure ([#1](https://github.com/marcus-waldman/kidsights-norc/issues/1))
2. **Multi-child eligibility** - Per-child age eligibility checking
3. **Geography** - Geocoding integration for geographic monitoring

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
