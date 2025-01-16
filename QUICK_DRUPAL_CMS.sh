#!/bin/bash
# Build & Deploy Drupal CMS on a new Upsun project.
set -e
# Requirements: A working Upsun account with permission to create projects.
composer create-project --ignore-platform-reqs --no-install drupal/cms:^1 "drupal-cms"
cd "drupal-cms"
# SCAFFOLDING ADDITION
composer config repositories.upsun-drupal-scaffold vcs https://github.com/upsun/drupal-scaffold
composer config --json --merge extra.drupal-scaffold.allowed-packages '["upsun/drupal-scaffold"]'
composer require --no-interaction --ignore-platform-reqs upsun/drupal-scaffold
git init
git add .
git commit -m "Built Drupal site with Upsun scaffolding additions"
# CREATE UPSUN PROJECT AND PUSH TO IT
upsun --version || curl -fsSL https://raw.githubusercontent.com/platformsh/cli/main/installer.sh | VENDOR=upsun bash
# Running auth should trigger an interactive login. If pulling this auth info fails, crash out now.
upsun auth:info
upsun project:create -y \
  --org="$(upsun  organization:list --my --columns=id --format=plain --no-header | head -1)" \
  --title="drupal-cms" --plan="upsun/flexible" --region="eu-5.platform.sh" \
  --default-branch=main --set-remote
git push --set-upstream upsun main
