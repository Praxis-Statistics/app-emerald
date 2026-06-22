#!/bin/bash

# Quick start script for the Emerald EDC Data Explorer app.

echo "============================================"
echo "Emerald — EDC Data Explorer"
echo "============================================"
echo ""

# Check if R is installed
if ! command -v Rscript &> /dev/null; then
    echo "Error: R is not installed or not in PATH"
    echo "Please install R from https://www.r-project.org/"
    exit 1
fi

echo "Step 1: Installing required packages..."
echo ""
Rscript install_packages.R

if [ $? -ne 0 ]; then
    echo "Error: Package installation failed"
    exit 1
fi

echo ""
echo "Step 2: Launching the Shiny app..."
echo ""
echo "The app will open in your browser. If not, visit: http://localhost:3838"
echo ""

# Run the app
Rscript -e "shiny::runApp()"
