#!/bin/bash

# Define repositories
CODE_REPO="https://github.com/weberon/flexibleflyer"
DATA_REPO="http://vcs.weberon.net/hg/FlexibleFlyer/"
CODE_REPO_DIR="flexibleflyer"
DATA_REPO_DIR="FlexibleFlyer-Data"

# Ensure datasetname is provided
if [ -z "$datasetname" ]; then
    echo "Error: datasetname parameter is not set."
    exit 1
fi

# Clone the repositories
echo "Cloning code repository..."
git clone "$CODE_REPO" "$CODE_REPO_DIR"

echo "Cloning data repository..."
hg clone "$DATA_REPO" "$DATA_REPO_DIR"

# Get absolute path of the data repo
DATA_REPO_PATH="$(pwd)/$DATA_REPO_DIR"

echo "Data repo path (gitfolder): $DATA_REPO_PATH"
echo "Dataset name: $datasetname"

# Navigate to the code repo directory
cd "$CODE_REPO_DIR" || exit 1

# Run the node command
echo "Running builder.js..."
node builder.js \
  --targetdomain="" \
  --gitfolder="$DATA_REPO_PATH" \
  --datasetname="$datasetname" \
  --basepath="" \
  --enableMauticTracking="no" \
  --enableMauticForm="no" \
  --mauticurl=""

echo "Script execution completed."
