* Based on the [drupal/core-composer-scaffold](https://www.drupal.org/docs/develop/using-composer/using-drupals-composer-scaffold)
* See also [Using the new Drupal 8 core scaffolding tool (2020) Docksal example](https://medium.com/@twfahey/using-the-new-d8-core-scaffolding-tool-48cbda9c1cd3)

# Upsun+Drupal Composer Scaffold

This project provides a composer plugin for placing scaffold files (like
`.upsun/config.json`, `settings.platformsh.php`, …) into their desired
location within the project.

## Usage

Upsun-Drupal Composer Scaffold is used by requiring `upsun/drupal-scaffold` in your
project, and adding it to the list of `drupal-scaffold.allowed-packages`

Once installed, the scaffold operations run automatically as needed, e.g. after
`composer install`.

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

### What it does

* Adds required upsun config file `config.yaml`
  * which defines the database services, web behaviour, and deployment actions
* Adds Platform.sh config reader 
  * which is used to pull in the environment connection information
* Adds configurations to settings.php to use the environment settings.
  * Such as the DB connection details
* Adds drush support with some helper scripts
  * `drush/*`, `.environmnent`
* Requires `drush/drush` and `drupal/redis` libraries for optimal behaviour.