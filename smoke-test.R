# Smoke Test for MN26 Monitoring Report
# Runs generate_monitoring_report() against the NORC NE Smoke Test project

# Auto-install and load required packages
required_packages <- c("dplyr", "tidyr", "REDCapR", "httr")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

# Source the monitoring script and run
source("progress-monitoring/mn26/monitoring_report.R")
monitoring_data <- generate_monitoring_report(
  csv_path = "C:/my_auths/kidsights_redcap_norc_test.csv"
)
