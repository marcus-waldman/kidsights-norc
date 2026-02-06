# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains sample monitoring tools for NORC researchers tracking the Minnesota 2026 (MN26) study recruitment progress and demographic distribution. The codebase is currently using Nebraska 2025 (NE25) data as a template and will need to be adapted once MN26 data collection begins.

## Key Commands

### Running the Monitoring Script

The main monitoring script is standalone and requires only R with necessary packages:

```r
# In R console
source("progress-monitoring/mn26/monitoring_report.R")

# Generate monitoring report
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/path/to/your/mn26_redcap_api.csv"
)

# Optional: specify Minnesota REDCap URL
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/path/to/your/mn26_api.csv",
  redcap_url = "https://redcap.umn.edu/api/"
)
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

### Data Flow

1. **API Credentials** → Load from CSV file (columns: `project`, `pid`, `api_code`)
2. **REDCap API** → Pull raw data using `REDCapR::redcap_read()` with consistent parameters
3. **Transform** → Convert raw variables into monitoring-ready derived variables
4. **Calculate** → Compute eligibility (4 criteria), screener status, survey completion
5. **Extract** → Pull child and parent demographics
6. **Return** → List with 5 data frames (screener_status, eligibility, survey_completion, child_demographics, parent_demographics)

### Eligibility Logic

The script implements 4 eligibility criteria:
1. Parent age ≥19 (`eq003 == 1`)
2. Child age 0-5 years (`age_in_days ≤ 1825`)
3. Primary caregiver status (`eq002 == 1`)
4. State residence - Minnesota for MN26, Nebraska for NE25 template (`eqstate == 1`)

Screener is "complete" when eligibility is known (non-missing).

### Survey Completion

Survey is "complete" when all required modules have REDCap status = 2. Currently uses NE25 module list: 2, 3, 4, 5, 6, 7, 9 (excludes module 8 follow-up).

## Important Notes for MN26 Migration

### Variable Name Updates Required

Search for `[MN26 TODO]` comments throughout the code. Key areas:

1. **REDCap URL** - Update to Minnesota REDCap instance
2. **Eligibility variables** - Verify `eq001`, `eq002`, `eq003`, `eqstate`, `age_in_days` match MN26 data dictionary
3. **Demographics variables** - Verify `cqr009` (child sex), `cqr002` (parent sex), `cqr003` (parent age), `cqr004` (education), `cqfa001` (marital status), `sq002_*` (race checkboxes), `sq003` (ethnicity)
4. **Module list** - Update survey completion module numbers to match MN26 questionnaire structure
5. **State code** - Change from Nebraska (1) to Minnesota state code in `eqstate` eligibility check
6. **Age cutoff** - MN26 uses 1825 days (5 years) vs NE25's 2191 days (6 years)

### Multi-Child Households

MN26 allows up to 2 children per household (unlike NE25's 1 child). The child demographics and eligibility logic must be updated to:
- Pivot to long format (1 row per child)
- Add `child_number` column (1 or 2)
- Check eligibility per child

REDCap structure (repeating instruments vs. separate fields) will determine implementation approach.

### Security and Data Management

- **API credentials CSV** - Store securely outside repository (e.g., `C:/Users/USERNAME/my-APIs/`)
- **Never commit API tokens** - `.gitignore` excludes files with "api" in name
- **Minimal variable access** - Script requires only 28 raw REDCap variables (see README.md for list)
- **No PHI in git** - Repository contains no protected health information

### Self-Contained Design

The monitoring script is standalone with no external pipeline dependencies:
- Utility functions are self-contained in `utils/` directory
- No database connections required
- No environment variables needed
- Simple function call with CSV path

## Output Data Frames

The `generate_monitoring_report()` function returns a list with 5 data frames:

1. **`$screener_status`** - Eligibility determination status (complete/incomplete)
2. **`$eligibility`** - Four eligibility criteria + overall eligibility boolean
3. **`$survey_completion`** - Module completion tracking with percentage and last completed module
4. **`$child_demographics`** - Age (years) and sex
5. **`$parent_demographics`** - Age, sex, race/ethnicity, education, marital status

## Contact

For questions about adapting this script for MN26 data, contact Marcus Waldman.
