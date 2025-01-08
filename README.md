# Upsun+Drupal Composer Scaffold

* Based on the [drupal/core-composer-scaffold](https://www.drupal.org/docs/develop/using-composer/using-drupals-composer-scaffold)
* See also [Using the new Drupal 8 core scaffolding tool (2020) Docksal example](https://medium.com/@twfahey/using-the-new-d8-core-scaffolding-tool-48cbda9c1cd3)

This project provides a composer plugin for placing scaffold files 
(like `.upsun/config.json`, `settings.platformsh.php`, …) 
into their desired location within an existing Drupal project to make it work on Upsun hosting.

## Usage

Upsun-Drupal Composer Scaffold is applied by requiring `upsun/drupal-scaffold` in your
project, and adding it to the list of `drupal-scaffold.allowed-packages`

Once installed, the scaffold operations run automatically as needed, e.g. after
`composer install`.

## Installation

To add this feature to an existing Drupal project that was built in the `recommended-project` structure, 

```
composer config repositories.upsun-drupal-scaffold vcs https://github.com/upsun/drupal-scaffold
composer config --json --merge extra.drupal-scaffold.allowed-packages '["upsun/drupal-scaffold"]'
composer require upsun/drupal-scaffold dev-main
```

### Add the new files to your project.

The scaffolding files added by this process must now be added to your project via `git add`
as they are required to be part of the repository branch that is uploaded to the Upsun server. 
Some of these files (`config.yaml`) must exist and have been committed before the push to the Upsun environments can be validated.

### What the scaffolding addition does

* Adds required Upsun config file `config.yaml`
  * which defines the database services, web behaviour, and deployment actions
* Adds Platform.sh config reader 
  * which is used to pull in the environment connection information
* Adds configurations to settings.php to use the environment settings.
  * Such as the DB connection details
* Adds drush support with some helper scripts
  * `drush/*`, `.environmnent`
* Requires `drush/drush` and `drupal/redis` libraries for optimal behaviour.

### Adjustments

[Review the docs for troubleshooting tips](https://docs.upsun.com/get-started/here/configure.html#errors-on-first-push)

If you used the Drupal recommended-project as a starter, 
then your web-root inside your project will be `web/`. This is the assumed default.
Your current Drupals `composer.json` may include the section that looks like this:

```json
    "extra": {
        "drupal-scaffold": {
            "locations": {
                "web-root": "web/"
```

If your project is structured a little differently, using `docroot` or `public`
as the web-root, then you should adjust the provided scaffold file 
`.upsun/config.yaml` accordingly, 
replacing most instances of `web/` with your actual web-root path.
Importantly, the `applications.drupal.web.locations./.root` value.
and also `applications.drupal.mounts."/web/sites/default/files"` 

Places to look:

```
yq '.applications.drupal.web.locations./.root' < .upsun/config.yaml
yq '.applications.drupal.mounts | keys' < .upsun/config.yaml
```


## Deploy

Once the `drupal-scaffold` changes have been added to your repository, 
your project should be ready to push into an Upsun project and begin working.

If you don't have an Upsun project created already,
then you'll have to [create a project either through the console or the CLI](https://docs.upsun.com/get-started/here/create-project.html).

### Gotcha: Use the right subscription plan.

> Note, if creating your project, do not use the `development` subscription plan.
> It must be `upsun/flexible` or you won't get any resources to begin with.

If you are on the wrong plan, need to update things before pushing successfully/
```
upsun resources:get
upsun subscription:info plan 'upsun/flexible'
upsun resources:set --disk drupal:512,db:614512
```