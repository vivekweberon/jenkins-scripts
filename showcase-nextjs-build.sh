#!/bin/bash

# Print the repository URLs to verify they are passed correctly
echo "Cloning repositories..."
echo "Code repository: $WEBSITE_CODE_REPO"
echo "Input data repository: $WEBSITE_DATA_REPO"

# Change to the Jenkins workspace directory
cd "$WORKSPACE" || { echo "Error: Couldn't access workspace directory"; exit 1; }

# Clone the code repository
echo "Cloning code repository..."
git clone "$WEBSITE_CODE_REPO" code_repo || { echo "Error: Cloning code repository failed"; exit 1; }

# Clone the input data repository using credentials
echo "Cloning input data repository..."
git clone "https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/weberon/$WEBSITE_DATA_REPO.git" input_data_repo || { echo "Failed to clone input data repository"; exit 1; }

echo "Cloning Mautic tracker repository..."
git clone "https://$GITHUB_USERNAME:$GITHUB_TOKEN@$MAUTIC_TRACKER"

echo "Repositories cloned successfully."

# Change directory to the code_repo
cd code_repo || { echo "Error: Couldn't change directory to code_repo"; exit 1; }

# Print out the contents of the code repository
echo "Listing contents of the code repository:"
ls -l

# Update basePath value in next.config.js based on Jenkins parameter
sed -i "s|basePath: \"/lp-showcase\"|basePath: \"/$WEBSITE_DIRECTORY_NAME\"|g" next.config.js

# Print out the contents of next.config.js to verify the changes
echo "Updated next.config.js:"
cat next.config.js

# Function to echo start message
echoStart() {
    echo "Starting $1"
}

# Function to echo end message
echoEnd() {
    echo "Finished $1"
}

# Function to check if command was successful
chkCMD() {
    if [ $? -ne 0 ]; then
        echo "Error: Command failed"
        exit 1
    fi
}

# Function to set up NodeJS
setUPNodeJS() {
    processInfo="Setting up NodeJS - Specific Version"
    echoStart "$processInfo"
    source $JENKINS_HOME/.bashrc
    # Check if nvm is installed
    if ! command -v nvm &> /dev/null; then
        echo "nvm is not installed. Please install nvm first."
        return 1
    fi
    nvm --version
    # Install and use the specific Node.js version
    NODE_VERSION="v22.4.1"
    npm_VERSION="v10.8.1"
    nvm install $NODE_VERSION; chkCMD
    nvm use $NODE_VERSION; chkCMD
    # Check if the desired npm version is installed
    current_npm_version=$(npm -v)
    if [ "$current_npm_version" != "$npm_VERSION" ]; then
        npm install -g npm@$npm_VERSION; chkCMD
    fi
    echo "Node version: $(node -v)"
    echo "npm version: $(npm -v)"
    echoEnd "$processInfo"
}

# Function to install dependencies
installDependencies() {
    processInfo="Installing Dependencies"
    echoStart "$processInfo"
    npm install || { echo "Error: Dependency installation failed"; exit 1; }
    echoEnd "$processInfo"
}

# Function to create the data and public folders if they don't exist
createFolders() {
    mkdir -p data public
}

# Function to copy numbered, global, and home folders from input_data_repo to the data directory in code_repo
copyDataFolders() {
    echo "Copying numbered, global, and home folders from input_data_repo to data directory in code_repo"
    for folder in ../input_data_repo/*; do
        if [[ -d "$folder" ]]; then
            folder_name=$(basename "$folder")
            cp -r "$folder" data/ || { echo "Error: Failed to copy $folder_name to data directory"; exit 1; }
        fi
    done
}

# Function to copy the Mautic tracker JS files
copyMauticTrackerJSFiles() {
    echo "Copying Mautic tracker JS files to public/js folder..."
    mkdir -p public/js || { echo "Error: Couldn't create public/js directory"; exit 1; }
    cp -r ../mautic_tracker/js/*.js public/js/ || { echo "Error: Failed to copy Mautic tracker JS files"; exit 1; }
}

# Function to print out the contents of the data folder
listDataFolderContents() {
    echo "Listing contents of the data folder:"
    ls -l data
}

# Function to copy data and global directories to public and remove data.yaml files
copyFoldersToPublic() {
    processInfo="Copying data and global directories to public, then removing data.yaml files"
    echoStart "$processInfo"
    
    # Create the data directory inside public if it doesn't exist
    mkdir -p public/data || { echo "Error: Failed to create data directory inside public"; exit 1; }

    # Copy everything from data to public/data directory
    cp -r data/* public/data/ || { echo "Error: Failed to copy data to public/data directory"; exit 1; }

    # Navigate to the public/data directory
    cd public/data || { echo "Error: Failed to navigate to the public/data directory"; exit 1; }

    # Remove data.yaml files from public/data directory and its subdirectories
    find . -name "data.yaml" -type f -delete || { echo "Error: Failed to remove data.yaml files"; exit 1; }

    # Navigate back to the previous directory
    cd ../../ || { echo "Error: Failed to navigate back to the previous directory"; exit 1; }

    # Copy images from global/images to public/images directory
    mkdir -p public/images || { echo "Error: Failed to create images directory inside public"; exit 1; }
    cp -r data/global/images/* public/images/ || { echo "Error: Failed to copy images to public/images directory"; exit 1; }

    echoEnd "$processInfo"
}

# Function to rename folders based on renameUtils.mjs
renameFolders() {
    local dir="$1"
    echo "Renaming folders in $dir"
    for folder in "$dir"/*; do
        if [ -d "$folder" ]; then
            folder_name=$(basename "$folder")
            # Skip the global directory
            if [ "$folder_name" == "global" ]; then
                continue
            fi
            # Check if folder_name consists of only digits and dashes
            if [[ $folder_name =~ ^[0-9-]+$ ]]; then
                # Get the new folder name using the JavaScript script
                new_folder_name=$(node -e "
                    import('/var/jenkins_home/workspace/LANDING_PAGES/LANDING_PAGES-BLUE/lp-showcase-nextjs/code_repo/utils/renameUtils.mjs')
                        .then(({ getPropertyOutputDirectoryName }) => {
                            console.log(getPropertyOutputDirectoryName('$folder_name'));
                        })
                        .catch((error) => {
                            console.error('Error:', error);
                            process.exit(1);
                        });
                ")
                if [ $? -ne 0 ]; then
                    echo "Error: JavaScript execution failed for $folder_name"
                    exit 1
                fi

                new_folder_name=$(echo "$new_folder_name" | tr -d '\r') # Remove any carriage return characters

                if [ -n "$new_folder_name" ]; then
                    mv "$folder" "$dir/$new_folder_name"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to rename $folder_name to $new_folder_name"
                        exit 1
                    fi
                    echo "Renamed $folder_name to $new_folder_name"
                else
                    echo "Error: New folder name is empty for $folder_name"
                fi
            else
                echo "Skipping $folder_name as it does not match the pattern"
            fi
        fi
    done
}

# Function to rename folders in the data directory inside the public directory
renamingPublicDataDirectories() {
    # Navigate to the data directory inside public
    cd public/data
    # Call the renameFolders function
    renameFolders .
    # Navigate back to the original directory
    cd ../../ || { echo "Error: Failed to navigate back to the previous directory"; exit 1; }
}

# Function to build the project
buildProject() {
    processInfo="Building lp-showcase-nextjs"
    echoStart "$processInfo"
    npm run build
    if [ $? -ne 0 ]; then
        echo "Error: Build failed"
        exit 1
    fi
    echoEnd "$processInfo"
}

# Function to check for the website type and set up the final repository
checkForWebsiteType() {
    cd $WORKSPACE
    mkdir final-repo
    cd final-repo || { echo "Error: final-repo folder does not exist"; exit 1; }
    git init
    git config user.name "vivekWeberon"
    git config user.email "vivek@weberon.net"
    git remote add origin https://$GITHUB_TOKEN@$FINAL_REPO
    git checkout -B $DCS_FINAL_REPO || { echo "Error: $DCS_FINAL_REPO branch does not exist"; exit 1; }

    if git ls-remote origin | grep -sw $DCS_FINAL_REPO 2>&1>/dev/null
    then
        echo "$DCS_FINAL_REPO BRANCH EXISTS ON REMOTE REPO"
        git pull origin $DCS_FINAL_REPO

        if [ "$WEBSITE_TYPE" = "UNBRANDED" ]; then
            echo "Website is Unbranded"
            git rm -r *
        elif [ "$WEBSITE_TYPE" = "BRANDED" ]; then
            echo "Website is Branded"
            rm -rf -- components configs modules pages public .gitignore next.config.js package.json package-lock.json README.md
        else
            echo "Website is a sub-directory"
            rm -rf $WEBSITE_DIRECTORY_NAME
        fi

        echo "Removed the existing files"
    else
        echo "$DCS_FINAL_REPO BRANCH NOT FOUND ON REMOTE REPO"
    fi

    # Read commit hash from git_log.txt
    commit_hash=$(awk '{print $2}' "$WORKSPACE/lp-showcase-nextjs/code_repo/.git/logs/HEAD")
    # Read Git repository URL
    git_repo=$(grep -oP '(?<=clone: from ).*' "$WORKSPACE/lp-showcase-nextjs/code_repo/.git/logs/HEAD")
    # Output file
    output_file="$WORKSPACE/final-repo/git_log.txt"
    # Write to the output file
    echo "Commit hash: $commit_hash" > "$output_file"
    echo "Git repository: $git_repo" >> "$output_file"
    echo "Data has been saved to $output_file"
}

# Function to copy website content to the GitHub repository
copyWebsiteToGithubRepo() {
    # Create the WEBSITE_DIRECTORY_NAME directory if it does not exist
    if [ ! -d "$WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME" ]; then
        mkdir -p "$WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME" || { echo "Error: Could not create $WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME"; exit 1; }
        echo "Created $WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME directory"
    else
        echo "$WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME already exists"
    fi

    # Copy contents of the out directory to the final repo inside the WEBSITE_DIRECTORY_NAME folder
    cp -r "$WORKSPACE/code_repo/out/." "$WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME/"
    echo "Files copied into the $WORKSPACE/final-repo/$WEBSITE_DIRECTORY_NAME folder"

    # Navigate to the final-repo directory
    cd "$WORKSPACE/final-repo/" || { echo "Error: Could not access $WORKSPACE/final-repo/"; exit 1; }

    # List the files in the directory
    ls

    # Stage all changes for commit
    git add .

    # Check if there are any changes to commit
    if git diff-index --quiet HEAD; then
        echo "No changes to commit."
    else
        # Commit the changes
        git commit -m "Automated Commit from the Jenkins build: $(date)" || { echo "Error: Commit failed"; exit 1; }
        echo "Commit to github.com/vivekweberon/lp-showcase-final-repo.git repo is done"
    fi

    echo "Trying to push to $DCS_FINAL_REPO branch on https://github.com/vivekweberon/lp-showcase-final-repo.git repo"

    # Check if the branch exists on the remote repository
    if git ls-remote --heads origin "$DCS_FINAL_REPO" | grep "$DCS_FINAL_REPO" >/dev/null 2>&1; then
        # Push the changes to the specified branch
        git push -u origin "$DCS_FINAL_REPO" -v || { echo "Error: Push failed"; exit 1; }
        echo "Code pushed to github.com/vivekweberon/lp-showcase-final-repo.git repo on branch $DCS_FINAL_REPO"
    else
        echo "Error: Branch $DCS_FINAL_REPO does not exist on the remote repository."
        exit 1
    fi
}

# Call functions in the correct order
setUPNodeJS
installDependencies
createFolders
copyDataFolders
copyMauticTrackerJSFiles
listDataFolderContents
copyFoldersToPublic
renamingPublicDataDirectories
buildProject
checkForWebsiteType
copyWebsiteToGithubRepo