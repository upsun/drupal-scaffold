# Initialize the Project ID and branch environment from context.

# If running `ddev pull`, ddev wants to know these values,
# https://ddev.readthedocs.io/en/stable/users/providers/upsun/#upsun-per-project-configuration
# but I don't want to hard-code them.

# This bash file will be included and run for each ddev session.
# https://ddev.readthedocs.io/en/stable/users/extend/in-container-configuration/

# This requires `platform`/`upsun` CLI tool,
# and the API token [PLATFORM/UPSUN_CLI_TOKEN] to be available.
# These are best published in `~/.ddev/global_config.yaml`
# as per docs https://ddev.readthedocs.io/en/stable/users/providers/upsun/#upsun-global-configuration

# If not already defined, pull project ID from context.
# This TAKES TIME each run, so would be better to be cached somehow.
# Thankfully, platform CLI does cache this state, it seems, so the request becomes cheaper on subsequent runs.

# I discard errors because sometimes the CLI tool falls back to parsing the current git branch & repo
# to deduce the PLATFORM_PROJECT context.
# Which works fine unless we are switching between dual repos and projects in one folder.
#
# If Upsun config exists, it's probably newer, let it take precedence.
#
# Trying to figure the project ID from context will fall back to user input.
# I can't have that in a startup script, so disable interaction with `--yes`.

if [ -d "${DDEV_COMPOSER_ROOT}/.upsun" ] \
  && [ -n "$IS_DDEV_PROJECT" ] \
  && [ -n "$UPSUN_CLI_TOKEN" ] ; then
    # >&2 echo "Initializing Upsun project properties as env vars"
    export UPSUN_PROJECT=${UPSUN_PROJECT:-$(upsun project:info --yes id 2> /dev/null)}
    export UPSUN_BRANCH=${UPSUN_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
    # ddev uses a non-standard (but better) var name here.
    export UPSUN_ENVIRONMENT=$UPSUN_BRANCH
fi


if [ -d "${DDEV_COMPOSER_ROOT}/.platform" ] \
   && [ -n "$IS_DDEV_PROJECT" ] \
   && [ -n "$PLATFORMSH_CLI_TOKEN" ] ; then
    # >&2 echo "Initializing project properties as env vars"
    export PLATFORM_PROJECT=${PLATFORM_PROJECT:-$(platform project:info --yes id 2> /dev/null)}
    export PLATFORM_BRANCH=${PLATFORM_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
    # ddev uses a non-standard (but better) var name here.
    export PLATFORM_ENVIRONMENT=$PLATFORM_BRANCH
fi


