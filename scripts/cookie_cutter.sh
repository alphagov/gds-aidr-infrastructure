#!/usr/bin/env bash
## use this to create a template app for gds-aidr infrastructure
## usage: copy this script to the path were you want the app repository to be stored
##
## 1. copy the shell file to the directory you want the app to be in
## 2. in terminal run `chmod +x cookie_cutter.sh` to make executable
### ... then run `./cookie_cutter.sh | tee -a cookie_cutter.log`
## 3. choose an app name/repository name
## 4. the script will create the project for you
### NOTE: choose app name wisely: the repository_name will be the app_name and determines 
### ... resource names in aws, ie <ENVIRONMENT>-<APP_NAME><domain> or <ENVIRONMENT><APP_NAME>.tfstate

# chmod +x ./cookie_cutter.sh | tee -a cookie_cutter.log
set -euo pipefail

# prompts user for APP_NAME
read -p "Enter the new application name: " RAW_APP_NAME

# cleanse APP_NAME: replace spaces with dashes, remove special characters
APP_NAME=$(echo "$RAW_APP_NAME" | sed 's/ /-/g' | sed 's/[^A-Za-z0-9_-]//g')

# DERIVE APP_NAME from first argument of current working dir
# APP_NAME=${1:-$(basename "$PWD" | sed 's/^\.//')}
# APP_NAME := $(shell basename "$$PWD" | sed 's/^\.//') # derives the app name from the current directory, stripping any leading dot

# automaticaly set TEMPLATE_DIR to the directory containing this script
# TEMPLATE_DIR=$(dirname "$0")

# set TEMPLATE_DIR to one level up, as the script is inside the /scripts/ folder
TEMPLATE_DIR="$(dirname "$0")/.."

if [ -z "$APP_NAME" ]; then
  echo "Error: APP_NAME is required and cannot be empty after regex transform."
  echo "Usage (from directory you want project to sit in): ./cookie_cutter.sh"
  exit 1
fi

echo "Creating project for new application: ${APP_NAME}..."

# create target directory structure
mkdir -p "${APP_NAME}/.github/workflows"
mkdir -p "${APP_NAME}/infrastructure"
mkdir -p "${APP_NAME}/src"
mkdir -p "${APP_NAME}/tests"

# create base files, empty for now, will populate later
touch "${APP_NAME}/.github/CODEOWNERS"
touch "${APP_NAME}/.gitignore"
touch "${APP_NAME}/Dockerfile"
touch "${APP_NAME}/README.md"
touch "${APP_NAME}/requirements.txt"

# touch/mk core files
cp "${TEMPLATE_DIR}/Makefile" "${APP_NAME}/" 2>/dev/null || true
cp "${TEMPLATE_DIR}/.env.example" "${APP_NAME}/" 2>/dev/null || true

# touch/corw infrastructure directory
if [ -d "${TEMPLATE_DIR}/infrastructure" ]; then
  cp -r "${TEMPLATE_DIR}/infrastructure" "${APP_NAME}/"
fi

# add deployment workflows
cp "${TEMPLATE_DIR}/.github/workflows/"*.yml "${APP_NAME}/.github/workflows/" 2>/dev/null || true

# Find and replace template name with new app name
# Using a backup extension (.bak) ensures compatibility with both GNU and macOS sed
# find "${APP_NAME}" -type f -exec sed -i.bak "s/${TEMPLATE_DIR}${APP_NAME}/g" {} +
# find "${APP_NAME}" -name "*.bak" -type f -delete

echo "Successfully created project_directory for ${APP_NAME}."
echo "Configured for development, staging, and production AWS accounts."