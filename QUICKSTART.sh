#!/bin/bash
set -e

# A sequence of steps to build a brand new Drupal 10.0.0
# site and get it running on Upsun.
#
# Change Drupal version as needed.
# This procedure will create a new project.
# You can adjust to skip creation and use an existing project.
#
# Requirements
# A working Upsun account with permission to create projects.

# DRUPAL PROJECT CREATION

PROJECT_NAME="${1:-upsun-drupal}"
DRUPAL_VERSION=10

composer create-project drupal/recommended-project:$DRUPAL_VERSION "$PROJECT_NAME"
cd "$PROJECT_NAME"

git init
git add composer.json
git commit -m "Created drupal/recommended-project"
# Don't add everything to git yet, need to tune the .gitignore first.

# SCAFFOLDING ADDITION

composer config repositories.upsun-drupal-scaffold vcs https://github.com/upsun/drupal-scaffold
composer config --json --merge extra.drupal-scaffold.allowed-packages '["upsun/drupal-scaffold"]'
composer require upsun/drupal-scaffold dev-main

git add .
git commit -m "Built Drupal site with Upsun scaffolding additions"

# CREATE UPSUN PROJECT AND PUSH TO IT

# Verify that we have an active account.
# If pulling this auth info fails, crash out now.
upsun auth:info

ORG_ID=$(upsun  organization:list --my --columns=id --format=plain --no-header | head -1)
REGION=eu-5.platform.sh
# Greenest in 2025

upsun project:create \
  --org="$ORG_ID" \
  --title="$PROJECT_NAME" \
  --plan="upsun/flexible" \
  --region="$REGION" \
  --default-branch=main \
  --set-remote \
  -y

# Wait here for project creation to complete...

git push --set-upstream upsun main

# New environment for new branch on new project should be ready to go.

# Note, the Drupal install wizard sometimes fails due to a race condition
# with brand new accounts.
# May need to `upsun drush cr` if you get en error at the end of the wizard process.

# OPTIONAL
# To complete a hands-off installation of a demo site:
ACCOUNT_NAME="tester_admin"
ACCOUNT_MAIL="${ACCOUNT_NAME}@example.com"
ACCOUNT_PASS="${ACCOUNT_NAME}"

upsun drush -- --yes \
  site-install demo_umami \
  install_configure_form.enable_update_status_emails=NULL \
  --account-name=${ACCOUNT_NAME} \
  --account-mail=${ACCOUNT_MAIL} \
  --site-mail=${ACCOUNT_MAIL} \
  --account-pass=${ACCOUNT_PASS}
