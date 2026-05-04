rsconnect::deployApp(
  server = "rsconnect-internal.norc.org",
  appMode = "quarto-static",
  appFiles = rsconnect::listDeploymentFiles(here::here()),
  appPrimaryDoc = "progress-monitoring/mn26/production-report.R",
  envVars = c("8792", "8723", "8724", "8725", "8726", "RSCONNECT_API_KEY")
)
