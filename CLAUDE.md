# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution. The codebase has been updated for MN26 NORC field names and value codes. Variables with `_norc` suffix indicate MN26-specific derived variables. Note: programmatic dictionary comparison (2026-04-04) confirmed that many codes (sex, education) are identical between NE25 and MN26 — earlier documentation incorrectly claimed these were changed.

## Key Commands

### Running the Monitoring Script

The main monitoring script is standalone and requires only R with necessary packages:

```r
# In R console
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report (production = 4-project credentials file)
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/my_auths/kidsights_redcap_norc_MN_2026.csv"
)
```

### Running Tests

```bash
# Synthetic tests (offline, no API needed)
Rscript progress-monitoring/mn26/synthetic-test.R

# Smoke test (requires REDCap API access)
Rscript progress-monitoring/mn26/smoke-test.R
```

### Required R Packages

```r
# Install dependencies
install.packages(c("dplyr", "tidyr", "REDCapR", "httr"))
```

## Architecture

### Module Structure

The monitoring system is organized into modular utility functions:

- **`progress-monitoring/mn26/monitoring_report.R`** - Main orchestration script that coordinates all monitoring components
- **`progress-monitoring/mn26/utils/redcap_utils.R`** - REDCap API credential loading and data extraction
- **`progress-monitoring/mn26/utils/data_transforms.R`** - Raw REDCap data transformations (age, sex, race/ethnicity, education, marital status)
- **`progress-monitoring/mn26/utils/safe_joins.R`** - Safe left join with collision detection and cardinality validation
- **`progress-monitoring/mn26/synthetic-test.R`** - Offline synthetic data tests (133 assertions, including a multi-project bind_rows test section, no API needed)
- **`progress-monitoring/mn26/smoke-test.R`** - Live smoke test against REDCap API

### Data Flow

1. **API Credentials** → Load from CSV file (columns: `project`, `pid`, `api_code`); one row per REDCap project (MN26 production = 4 projects)
2. **REDCap API** → Pull raw data from each project using `REDCapR::redcap_read()`, tag each row with `redcap_project_name`, validate data dictionaries are consistent across projects, then `bind_rows()` into a single data frame
3. **Transform** → Convert raw variables into monitoring-ready derived variables
4. **Calculate** → Compute survey completion
5. **Extract** → Pull eligibility form variables, child and parent demographics; `redcap_project_name` is preserved through every extractor
6. **Return** → List with 5 data frames (eligibility_form, survey_completion, child_demographics, parent_demographics, compensation_information); every frame includes `redcap_project_name` for per-project traceability

### Eligibility Logic

The `calculate_eligibility()` function implements 4 eligibility criteria:
1. Parent age ≥19 (`eq003 == 1`)
2. Child age 0-5 years (`age_in_days_n ≤ 1825`)
3. Primary caregiver status (`eq002 == 1`)
4. Minnesota residence (`mn_eqstate == 1`)

Screener is "complete" when eligibility is known (non-missing).

> **Note (production reality):** `eq002`/`eq003`/`mn_eqstate` live in the *legacy* `eligibility_form` REDCap instrument in the 4 production projects, while `age_in_days_n` lives in `eligibility_form_norc`. All four columns are still present in `raw_data` (regardless of form_name) so the function works as written. However, `calculate_eligibility()` is currently **not called by `generate_monitoring_report()`** — it's a standalone utility, not part of the production output.

### Survey Completion

Survey completion is tracked via `n_required`, `modules_complete`, `pct_complete`, and `last_module_complete`. Uses per-participant denominator (7-11) because child 2 modules and NSCH questions are conditionally required. Instruments 26-29 (old NE25: eligibility form, home learning environment, module 7, birthdate confirmation) are ignored.

## MN26 Variable Mapping (from NE25)

### Changed Variable Names
| Purpose | NE25 | MN26 |
|---------|------|------|
| Child 1 age | `age_in_days` | `age_in_days_n` |
| Child 2 age | N/A | `age_in_days_c2_n` |
| Parent gender | `cqr002` | `mn2` |
| State eligibility | `eqstate` | `mn_eqstate` |
| Parent race | `sq002___*` | `sq002b___*` (codes 100-105) |
| Child race | `cqr010___*` | `cqr010b___*` (codes 100-105) |

### Changed Value Codes
| Variable | NE25 | MN26 | Status |
|----------|------|------|--------|
| Child sex (`cqr009`) | 1=Female, 0=Male | 1=Female, 0=Male | **Identical** (no swap) |
| Education (`cqr004`) | 0-8 | 0-8 | **Identical** |
| Marital status (`cqfa001`) | 0-5 | 0-5 | Verify (may be identical) |
| Parent gender (`mn2`) | N/A | 0=Female, 1=Male, 97=Non-binary | New variable |

### Derived Variables (_norc suffix)
- `sex_norc`, `sex_c2_norc` — Child sex with MN26 codes
- `a1_gender_norc` — Parent gender (replaces `female_a1`)
- `educ_a1_norc` — Education with MN26 codes
- `marital_status_label_norc` — Marital status with MN26 codes
- `a1_race_norc`, `a1_raceG_norc` — Parent race/ethnicity
- `race_norc`, `raceG_norc` — Child 1 race/ethnicity
- `race_c2_norc`, `raceG_c2_norc` — Child 2 race/ethnicity
- `store_choice_label` — Gift card store (Lowe's/Amazon/Walmart/Target)

### Remaining [MN26 TODO] Items
- Multi-child eligibility checking (per-child age check)
- Geography/geocoding integration

### Multi-Child Households

MN26 allows up to 2 children per household (unlike NE25's 1 child). Child 2 variables use separate columns with `_c2` suffix. REDCap uses separate fields (not repeating instruments).

### Security and Data Management

- **API credentials CSV** - Store securely outside repository (e.g., `C:/Users/USERNAME/my-APIs/`)
- **Never commit API tokens** - `.gitignore` excludes files with "api" in name
- **No PHI in git** - Repository contains no protected health information

### Self-Contained Design

The monitoring script is standalone with no external pipeline dependencies:
- Utility functions are self-contained in `utils/` directory
- No database connections required
- No environment variables needed
- Simple function call with CSV path

## Output Data Frames

The `generate_monitoring_report()` function returns a list with 5 data frames. Every frame includes `pid`, `record_id`, and **`redcap_project_name`** (added during the multi-project pull) so each row can be traced back to its source REDCap project.

1. **`$eligibility_form`** - All raw variables from the "Eligibility Form NORC" REDCap instrument (form_name `eligibility_form_norc`). Note: `eq002`/`eq003`/`mn_eqstate` are NOT in this frame — those legacy fields live in the old `eligibility_form` instrument and are intentionally excluded. They remain in raw_data for `calculate_eligibility()`.
2. **`$survey_completion`** - Module completion tracking (n_required, modules_complete, pct_complete, last_module_complete)
3. **`$child_demographics`** - Age, sex, race/ethnicity for child 1 (and child 2 if present)
4. **`$parent_demographics`** - Age, gender, race/ethnicity, education, marital status
5. **`$compensation_information`** - Gift card store choice and contact details

## Contact

For questions about adapting this script for MN26 data, contact Marcus Waldman.
