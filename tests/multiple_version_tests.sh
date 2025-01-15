#!/bin/bash
set -e

# This script will create a number of different versions of Drupal 8-11
# and deploy them into a Platform.sh/Upsun project.
# To reduce the admin footprint, 
# Each version will be a branch within a given test project, but effectively entirely independent.

# If this script is called with an existing `$PLATFORM_PROJECT` ID value,
# then the builds will happen there.
# If PLATFORM_PROJECT is undefined, a new one will be created.

# It will be required to activate the environments to see them run,
# so the project should have enough supported environments in the subscription to maintain the m all.

export PLATFORM_PROJECT=${1:-$PLATFORM_PROJECT}

# By default builds will happen in upsun.
# Can switch to `platform` classic by setting this variable.
export PROVIDER_CLI=${PROVIDER_CLE:-upsun}
# Remote repo id. 'upsun' or 'platform' by convention instead of 'origin'
export REPO_ID=$PROVIDER_CLI

# Helpers
print_log() {
  >&2 echo -e "  $@";
}
slugify() {
  echo "$1" | iconv -t ascii//TRANSLIT | sed -E 's/[~\^]+//g' | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+\|-+$//g' | sed -E 's/^-+//g' | sed -E 's/-+$//g' | tr A-Z a-z
}

# Subroutines

prepare_project(){
  # Check destination project.
  # Create a new one if not already defined.
  # Otherwise, build all these test cases in branches in the currently active project.
  # Current project should be defined by setting PLATFORM_PROJECT in the context.

  if [ -z "${PLATFORM_PROJECT}" ]; then
    # Paranoia: Verify that we have an active account.
    # If pulling this auth info fails, crash out now.
    ${PROVIDER_CLI} auth:info
    PROJECT_NAME="Deployment testing"
    ORG_ID=$(${PROVIDER_CLI}  organization:list --my --columns=id --format=plain --no-header | head -1)
    REGION=${REGION:-eu-5.platform.sh}
    print_log "Creating new project '$PROJECT_NAME' to run test deployments, in $REGION"

    printf 'Continue? (Y/n)? '
    old_stty_cfg=$(stty -g)
    stty raw -echo ; answer=$(head -c 1) ; stty $old_stty_cfg
    if [ "$answer" != "${answer#[Yy]}" ];then
        true; # continue
    else
        print_log "We need a project. Please provide a Project ID as arg1, or set PLATFORM_PROJECT in the environment.";
        exit 1
    fi

    PLATFORM_PROJECT=$(${PROVIDER_CLI} project:create \
      --org="$ORG_ID" \
      --title="$PROJECT_NAME" \
      --plan="upsun/flexible" \
      --region="$REGION" \
      --default-branch=main \
      --set-remote \
      -y )
      # Wait here for project creation to complete...
      export PLATFORM_PROJECT;
      if [ -z "${PLATFORM_PROJECT}" ]; then
        print_log "PROJECT_CREATION_FAILED"
        exit 1
      fi
  fi

  PROJECT_TITLE="$(${PROVIDER_CLI} project:info title)"
  export PROJECT_TITLE
  print_log "Ready to build destination environments in project $PLATFORM_PROJECT '$PROJECT_TITLE' "
}


build_project_from_composer() {
  # Run composer create-project,
  # do some housekeeping,
  # and make an initial git commit.
  # Assumes we are in an already-working git repo/branch

  COMPOSER_IDENTIFIER="$1"
  print_log "Creating project $COMPOSER_IDENTIFIER"
  # Ignore platform requirements as the local workspace may not reflect the php etc version requirements.
  composer create-project --ignore-platform-reqs --no-interaction --no-install "$COMPOSER_IDENTIFIER" "extracted"

  # Move extracted stuff up into current working directory
  mv extracted/* .
  mv extracted/.* . || true
  rmdir extracted

  add_starter_gitignore
  git add .
  git commit -m "Created fresh project from $COMPOSER_IDENTIFIER"
}

build_project_from_zip(){
  # Download a zip, unpack it, relocate everything into the current working directory.
  # Add everything to the current git branch.
  # Assumes we are in an already-working git repo/branch

  default_url="https://ftp.drupal.org/files/projects/cms-1.0.0-rc2.zip"
  zip_url="${1:-$default_url}"
  print_log "Creating project Based on zip $default_url"

  result_file=$(curl --remote-name --remote-header-name --write-out '%{filename_effective}\n' $zip_url)
  # Assume that this will unpack into a subdirectory, but need detect what the name of that subdirectory is.
  subdir=$(unzip -q "$result_file" -d extracted && ls -1 extracted | head -n 1)
  # move that all up into the CWD.
  mv extracted/${subdir}/* .
  rmdir extracted/${subdir} extracted
  rm "$result_file"
  print_log "Zip content extracted. Preparing git"

  add_starter_gitignore
  git add .
  git commit -m "Unpacked fresh from $zip_url"
}

build_project_from_git(){
  # Checks out a given branch of a given repo (URL),
  # relocate everything into the current working directory.
  # Add everything to the current git branch.
  # Assumes we are in an already-working git repo/branch
  # so needs to use a temp directory for the checkout,
  # then imports the new content into the existing repo.

  repository_url="$1"
  # git clone but abandon the history
  mkdir temp_checkout
  pushd temp_checkout
  git clone --depth=1 "$repository_url" extracted
  mv extracted/* ..
  rmdir extracted
  popd
  rmdir temp_checkout

  add_starter_gitignore
  git add .
  git commit -m "Cloned fresh from $repository_url"
}

add_starter_gitignore(){
  # Avoid adding vendor etc in the beginning.
  # Good templates already do this, but we have to specify this explicitly in basic cases.
  echo "vendor" >> .gitignore
  echo "web/core" >> .gitignore
  echo "web/modules/contrib" >> .gitignore
  # This starter gitignore should be refined and replaced
  # as the real project parameters are established.
  # It is not comprehensive
}

add_scaffolding(){
  # Add the requirement for the upsun-specific scaffolding & config files.
  print_log "Adding upsun/drupal-scaffold"
  composer config --no-interaction  allow-plugins true
  composer config --no-interaction repositories.upsun-drupal-scaffold vcs https://github.com/upsun/drupal-scaffold
  composer config --no-interaction --json --merge extra.drupal-scaffold.allowed-packages '["upsun/drupal-scaffold"]'

  composer require --no-interaction --ignore-platform-reqs  upsun/drupal-scaffold

  # There will need to be subtle variations in the drupal-scaffold version to match the Drupal version.
  # The composer version resolution should resolve to the correct set of requirments.

  # Drupal 8 requires PHP 7
  # Drupal9 works with PHP 7.3 - 8.1 but not 8.2
  # Drupal 10 works with PHP 8.1
  # Drupal 11 requires at least PHP 8.3
  # Drupal-cms (Drupal core 11) needs an additional cache folder

  # Also, platform.sh configreader of the Drupal8. php7 era had a different api.

  # Error: Call to undefined method Platformsh\ConfigReader\Config::hasRelationship()
  # So that will mean that the Drupal8 settings.platformsh.php will need to be unique.
  # OK, need to support this by having different content in different versions of the scaffold repo.
  # then applying the constraints. Tricky but not too hard.

  git add .
  git commit -m "Built Drupal site with Upsun scaffolding additions"
}

prepare_new_working_branch(){
  # Clear out the current working directory,
  # and prepare a new empty git branch.
  BRANCH="$1"

  if [[ ! -z "$(git ls-remote --heads $REPO_ID ${BRANCH})" ]] ; then
    echo "Branch '$BRANCH' already exists remotely in '$REPO_ID' repository." ;
    echo "Aborting this build."
    return 39 # directory not empty - close enough to the error description.
  fi

  print_log "Switching to new empty branch $BRANCH"
  git reset
  git clean -df
  git switch --orphan "$BRANCH" && git reset --hard && git clean -fdx
}

deploy_project_to_new_branch(){
  # Do the push to platform and activate the environment.
  BRANCH="$1"
  print_log "Pushing current state to branch $BRANCH"
  git push --set-upstream $REPO_ID "$BRANCH"
  # Seems that we cannot currently activate an environment without parent data --no-clone-parent
  $PROVIDER_CLI --no-interaction environment:activate --environment=$BRANCH
}

deploy_all_drupal_versions(){
  VERSIONS=( 8.x 9.x 10.x 11.x )
  for VERSION in "${VERSIONS[@]}"
  do
     APP_VERSION="drupal/recommended-project:$VERSION"
     # prepare git branch
     BRANCH=$(slugify $APP_VERSION)
     prepare_new_working_branch $BRANCH || continue
     # checkout new codebase
     build_project_from_composer $APP_VERSION
     add_scaffolding
     # push new code into project environment
     deploy_project_to_new_branch $BRANCH
  done
}


deploy_drupal_cms_from_zip(){
  BRANCH=$(slugify "cms-1.0.0")
  prepare_new_working_branch $BRANCH || return 0
  build_project_from_zip "https://ftp.drupal.org/files/projects/cms-1.0.0-rc2.zip"
  add_scaffolding
  deploy_project_to_new_branch $BRANCH
}

deploy_drupal_cms_from_composer(){
  COMPOSER_IDENTIFIER="drupal/cms:^1"
  BRANCH=$(slugify "$COMPOSER_IDENTIFIER")
  prepare_new_working_branch $BRANCH || return 0
  build_project_from_composer $COMPOSER_IDENTIFIER
  add_scaffolding
  deploy_project_to_new_branch $BRANCH
}

prepare_project;

deploy_drupal_cms_from_zip;
deploy_drupal_cms_from_composer;
deploy_all_drupal_versions;