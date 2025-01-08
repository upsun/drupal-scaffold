#!/bin/bash
set -e

# A sequence of steps to build a brand new Drupal site and get it running on Upsun.
#
# Requirements
# A working Upsun account with permission to create projects

# DRUPAL PROJECT CREATION

PROJECT_NAME="${1:-upsun-drupal}"

composer create-project drupal/recommended-project:10 "$PROJECT_NAME"
cd "$PROJECT_NAME"

git init
git add composer.json
git commit -m "Created drupal/recommended-project"
# Don't add everything  yet, need to tune the .gitignore

# SCAFFOLDING ADDITION

composer config repositories.upsun-drupal-scaffold vcs https://github.com/upsun/drupal-scaffold
composer config --json --merge extra.drupal-scaffold.allowed-packages '["upsun/drupal-scaffold"]'
composer require upsun/drupal-scaffold dev-main

git add .
git commit -m "Built Drupal site with Upsun scaffolding additions"

# CREATE UPSUN PROJECT AND PUSH TO IT

# Verify that we have an active account.
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

# After project creation, still have to allocate resources etc.
upsun resources:get
upsun resources:set --disk drupal:1024,db:614

git push --set-upstream upsun main

