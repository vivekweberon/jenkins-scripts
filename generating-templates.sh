#!/bin/bash

DATA_REPO_DIR="flexibleflyer"            # Data repo will be cloned here
CODE_REPO_DIR="FlexibleFlyer-code"       # Code repo will be cloned here
CODE_EXEC_DIR="$CODE_REPO_DIR/flexibleFlyer"  # Directory inside code repo where builder.js is located

# Function to check if the previous command succeeded
chkCMD() {
    if [ $? -ne 0 ]; then
        echo "Error encountered. Exiting..."
        exit 1
    fi
}

# Function to set up Node.js with a specific version using nvm
setUPNodeJS() {
    processInfo="Setting up NodeJS - Specific Version"
    echo "Starting: $processInfo"

    source $JENKINS_HOME/.bashrc

    # Check if nvm is installed
    if ! command -v nvm &> /dev/null; then
        echo "Error: nvm is not installed. Please install nvm first."
        exit 1
    fi

    echo "nvm version: $(nvm --version)"

    NODE_VERSION="v22.4.1"
    NPM_VERSION="10.8.1"

    nvm install $NODE_VERSION; chkCMD
    nvm use $NODE_VERSION; chkCMD

    # Update npm if the current version does not match
    current_npm_version=$(npm -v)
    if [ "$current_npm_version" != "$NPM_VERSION" ]; then
        npm install -g npm@$NPM_VERSION; chkCMD
    fi

    echo "Node version: $(node -v)"
    echo "npm version: $(npm -v)"
    echo "Completed: $processInfo"
}

# Ensure all required parameters are provided
if [ -z "$datasetname" ] || [ -z "$github_username" ] || [ -z "$github_token" ] || [ -z "$vcs_username" ] || [ -z "$vcs_password" ]; then
    echo "Error: One or more required parameters (datasetname, github_username, github_token, vcs_username, vcs_password) are not set."
    exit 1
fi

# Clone the data repository (GitHub) using provided credentials and branch
echo "Cloning data repository from GitHub (branch: $BRANCH)..."
git clone -b "$BRANCH" --single-branch "https://$github_username:$github_token@$DATA_REPO_URL" "$DATA_REPO_DIR"
chkCMD

# Clone the code repository (Mercurial) using provided credentials and branch
echo "Cloning code repository from VCS (branch: $BRANCH)..."
hg clone -b "$BRANCH" "http://$vcs_username:$vcs_password@$CODE_REPO_URL" "$CODE_REPO_DIR"
chkCMD

# Get absolute path of the data repo (to be passed as gitfolder)
DATA_REPO_PATH="$(pwd)/$DATA_REPO_DIR"
echo "Data repo path (to be used as gitfolder): $DATA_REPO_PATH"
echo "Dataset name: $datasetname"

# Update the basePath value in next.config.js (assumed to be in the code repo root)
# nextConfigFile="$CODE_REPO_DIR/next.config.js"
# if [ -f "$nextConfigFile" ]; then
#     echo "Updating basePath in $nextConfigFile to '/$datasetname'"
#     sed -i "s/\(basePath:\s*\)['\"][^'\"]*['\"]/\\1'\/$datasetname'/" "$nextConfigFile"
#     chkCMD
# else
#     echo "Warning: next.config.js not found at $nextConfigFile"
# fi

# Set up Node.js before building
setUPNodeJS

# Navigate to the code repository's execution directory where builder.js is located
cd "$CODE_EXEC_DIR" || exit 1

# Install dependencies before running builder.js with legacy peer dependency resolution
echo "Installing dependencies..."
npm install --legacy-peer-deps
chkCMD

# Run the builder.js script with the provided parameters
echo "Running builder.js..."
node builder.js \
  --targetdomain="" \
  --gitfolder="$DATA_REPO_PATH" \
  --datasetname="$datasetname" \
  --basepath="/$datasetname" \
  --enableMauticTracking="no" \
  --enableMauticForm="no" \
  --mauticurl=""

# After the build, rename the out directory to the datasetname
# if [ -d "out" ]; then
#     echo "Renaming 'out' directory to '$datasetname'"
#     mv out "$datasetname"
#     chkCMD
# else
#     echo "Warning: 'out' directory not found."
# fi

# # Copy the renamed directory to the root level of the workspace for easy download
# if [ -n "$WORKSPACE" ]; then
#     echo "Copying '$datasetname' directory to workspace root ($WORKSPACE)..."
#     cp -r "$datasetname" "$WORKSPACE/"
#     chkCMD
# else
#     echo "WORKSPACE environment variable not set. Skipping copy to workspace root."
# fi

echo "Script execution completed."
