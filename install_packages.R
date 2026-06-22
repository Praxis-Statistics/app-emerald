#!/usr/bin/env Rscript
# Install all required packages for the Emerald EDC Data Explorer app.

# Set CRAN mirror
options(repos = list(CRAN = "https://cloud.r-project.org"))

packages <- c(
  # Core Teal framework
  "shiny",
  "teal",
  "teal.data",
  "teal.modules.general",

  # DataBricks data access
  "brickster",
  "DBI",

  # Data manipulation
  "dplyr"
)

# Install packages not already installed
new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]

if (length(new_packages) > 0) {
  cat("Installing packages:", paste(new_packages, collapse = ", "), "\n\n")
  install.packages(new_packages)
  cat("\n✓ Installation complete!\n")
} else {
  cat("✓ All packages are already installed.\n")
}

cat("\nYou can now run the app with:\n")
cat("  R -e \"shiny::runApp()\"\n")
cat("or:\n")
cat("  bash run_app.sh\n")
