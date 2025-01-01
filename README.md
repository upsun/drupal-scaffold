* Based on the [drupal/core-composer-scaffold](https://www.drupal.org/docs/develop/using-composer/using-drupals-composer-scaffold)
* See also [Using the new Drupal 8 core scaffolding tool (2020) Docksal example](https://medium.com/@twfahey/using-the-new-d8-core-scaffolding-tool-48cbda9c1cd3)

# Upsun+Drupal Composer Scaffold

This project provides a composer plugin for placing scaffold files (like
`.upsun/config.json`, `settings.platformsh.php`, …) into their desired
location within the project.

## Usage

Upsun-Drupal Composer Scaffold is used by requiring `upsun/drupal-scaffold` in your
project, and providing configuration settings in the `extra` section of your
project's composer.json file. 

Typically, the scaffold operations run automatically as needed, e.g. after
`composer install`.

To scaffold a project directly, run:
```
composer drupal:scaffold
```

### Add the new files to your project.

The scaffolding files added by this process MUST be added to your project via `git add`
as they are required to be part of the repository branch that is uploaded to the Upsun server. 
Some of these file must exist and have been committed before the push to the Upsun environments can be validated.