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
read -p "Enter the new application name: " RAW_APP_NAME # RAW_APP_NAME is user input

# cleanse APP_NAME: replace spaces with dashes, remove special characters (preserves capitalisation)
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
mkdir -p "${APP_NAME}/api"
mkdir -p "${APP_NAME}/ui"
mkdir -p "${APP_NAME}/db"

# create base files, empty for now, will populate later
touch "${APP_NAME}/.gitignore"
touch "${APP_NAME}/Dockerfile"
touch "${APP_NAME}/README.md"
touch "${APP_NAME}/requirements.txt"

# populate codeowners file per gds standards
echo "* @gds-aidr-maintainers" > "${APP_NAME}/.github/CODEOWNERS"

# touch/mk core files
# Generate dynamic Makefile
echo "APP_NAME = ${APP_NAME}" > "${APP_NAME}/Makefile"

cat << 'EOF' >> "${APP_NAME}/Makefile"
# Makefile
#
# Wraps terraform commands for all three aws accounts
# Usage:
#   make tf_plan                          # Development
#   make tf_plan env=staging              # Staging
#   make tf_apply env=production          # Production
#   make tf_auto_apply env=development    # CI auto-approve
#
# Prerequisites:
#   - terraform installed
#   - AWS credentials exported for the target account
##  - requires AWS STS SESSION
#   - TF_VAR_team_token (while we have CloudFront dist versus domain-based)
#   - For deploys: TF_VAR_api_image_tag and TF_VAR_ui_image_tag exported
#  	- Each app will have its own state file to allow complete autonomy
#   - from infrastructure

# NOTE: LT plan is that development work can be asynchronous to infra

-include .env
export

# deployment follows pattern <environment>-<app_name>-<domain>

# --------------------------------------------------------------------------
# environment
# --------------------------------------------------------------------------

ifndef env
override env = development
endif

# Maps env shorthand to terraform variable values
ENV_MAP_development = Development
ENV_MAP_staging     = Staging
ENV_MAP_production  = Production

STATE_BUCKET = gds-aidr-terraform-state-$(env)
STATE_KEY    = apps/$(APP_NAME)/terraform.tfstate

TF_BACKEND_ARGS = \
	-backend-config=backend.hcl \
	-backend-config="bucket=$(STATE_BUCKET)" \
	-backend-config="key=$(STATE_KEY)"

TF_VAR_ARGS = \
	-var="environment=$(ENV_MAP_$(env))" \
	-var="account_id=$(ACCOUNT_MAP_$(env))"

# --------------------------------------------------------------------------
# terraform (app-specific)
# --------------------------------------------------------------------------

.PHONY: tf_init
tf_init:
	terraform -chdir=./infrastructure/ init \
		$(TF_BACKEND_ARGS) \
		-reconfigure

.PHONY: tf_plan
tf_plan: tf_init
	terraform -chdir=./infrastructure/ plan $(TF_VAR_ARGS) $(args)

.PHONY: tf_apply
tf_apply: tf_init
	terraform -chdir=./infrastructure/ apply $(TF_VAR_ARGS) $(args)

.PHONY: tf_auto_apply
tf_auto_apply: tf_init
	terraform -chdir=./infrastructure/ apply $(TF_VAR_ARGS) -auto-approve -input=false

# --------------------------------------------------------------------------
# docker
# --------------------------------------------------------------------------

ECR_URL = $(AWS_ACCOUNT_ID).dkr.ecr.eu-west-2.amazonaws.com # must always be eu-west-2
IMAGE_TAG = $$(git rev-parse --short HEAD)-$$(date +%s)

.PHONY: docker_login
docker_login:
	aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $(ECR_URL)

.PHONY: docker_build_api
docker_build_api:
	docker buildx build --platform linux/amd64 \
		-t $(ECR_URL)/$(APP_NAME):api-$(IMAGE_TAG) \
		api/

.PHONY: docker_build_ui
docker_build_ui:
	docker buildx build --platform linux/amd64 \
		-f ui/Dockerfile \
		-t $(ECR_URL)/$(APP_NAME):ui-$(IMAGE_TAG) \
		ui/

# --------------------------------------------------------------------------
# adhoc
# --------------------------------------------------------------------------

.PHONY: install
install:
	uv lock && uv sync

.PHONY: run
run:
	docker compose up -d --wait

.PHONY: stop
stop:
	docker compose down
EOF
cp "${TEMPLATE_DIR}/.env.example" "${APP_NAME}/" 2>/dev/null || true

# touch/corw infrastructure directory
if [ -d "${TEMPLATE_DIR}/infrastructure" ]; then
  cp -r "${TEMPLATE_DIR}/infrastructure" "${APP_NAME}/"
fi

# add deployment workflows
cp "${TEMPLATE_DIR}/.github/workflows/"*.yml "${APP_NAME}/.github/workflows/" 2>/dev/null || true

# scaffold basic deployment workflows for newly created directories
cat << 'EOF' > "${APP_NAME}/.github/workflows/deploy_api.yml"
name: deploy api
on:
  push:
    paths:
      - 'api/**'
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: build api image
        run: make docker_build_api
EOF

cat << 'EOF' > "${APP_NAME}/.github/workflows/deploy_ui.yml"
name: deploy ui
on:
  push:
    paths:
      - 'ui/**'
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: build ui image
        run: make docker_build_ui
EOF

cat << 'EOF' > "${APP_NAME}/.github/workflows/deploy_db.yml"
name: deploy db
on:
  push:
    paths:
      - 'db/**'
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: build db image
        run: make docker_build_db
EOF

# find and replace template name with new app name
# using a backup extension (.bak) ensures compatibility with both gnu and macos sed
# find "${APP_NAME}" -type f -exec sed -i.bak "s/${TEMPLATE_DIR}${APP_NAME}/g" {} +

# 1. Dynamically grab the name of the template folder (e.g., synthetic-email-generation)
TEMPLATE_APP_NAME=$(basename "$(cd "${TEMPLATE_DIR}" && pwd)")

# 2. Find and replace that exact name with the new app name in the copied files
find "${APP_NAME}" -type f -exec sed -i.bak "s/${TEMPLATE_APP_NAME}/${APP_NAME}/g" {} +
find "${APP_NAME}" -name "*.bak" -type f -delete

echo "Successfully created project_directory for ${APP_NAME}."
echo "Configured for development, staging, and production AWS accounts."