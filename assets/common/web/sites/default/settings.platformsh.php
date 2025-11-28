<?php
/**
 * @file
 * Platform.sh settings.
 */

use Drupal\Core\Installer\InstallerKernel;

// Set up a config sync directory.
//
// This is defined inside the read-only "config" directory, deployed via Git.
$settings['config_sync_directory'] = '../config/sync';

// Configure the database from the environment context.
$relationships_json = base64_decode(getenv('PLATFORM_RELATIONSHIPS'));
$relationships = json_decode($relationships_json, true);
// Example for a database relationship named 'database'
if (isset($relationships['database'])) {
  // Assuming a single database relationship
  $creds = $relationships['database'][0];
  $databases['default']['default'] = [
    'driver' => $creds['scheme'],
    'database' => $creds['path'],
    'username' => $creds['username'],
    'password' => $creds['password'],
    'host' => $creds['host'],
    'port' => $creds['port'],
    'pdo' => [PDO::MYSQL_ATTR_COMPRESS => !empty($creds['query']['compression'])],
    'init_commands' => [
      'isolation_level' => 'SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED',
    ],
  ];
}

// Enable verbose error messages on development branches, but not on the production branch.
// You may add more debug-centric settings here if desired to have them automatically enable
// on development but not production.
if (getenv('PLATFORM_ENVIRONMENT_TYPE') == 'production') {
  // Production environment type.
  $config['system.logging']['error_level'] = 'hide';
} else {
  // Non-production environment types.
  $config['system.logging']['error_level'] = 'verbose';
}

// Enable Redis caching.
// Uses relationship to a Redis-compatible backend named `cache`.
if (isset($relationships['cache'])
  && !InstallerKernel::installationAttempted()
  && extension_loaded('redis')
  && class_exists('Drupal\redis\ClientFactory')) {
  $creds = $relationships['cache'][0];

  // Set Redis as the default backend for any cache bin not otherwise specified.
  $settings['cache']['default'] = 'cache.backend.redis';
  $settings['redis.connection']['host'] = $creds['host'];
  $settings['redis.connection']['port'] = $creds['port'];

  // Apply changes to the container configuration to better leverage Redis.
  // This includes using Redis for the lock and flood control systems, as well
  // as the cache tag checksum. Alternatively, copy the contents of that file
  // to your project-specific services.yml file, modify as appropriate, and
  // remove this line.
  $settings['container_yamls'][] = 'modules/contrib/redis/example.services.yml';

  // Allow the services to work before the Redis module itself is enabled.
  $settings['container_yamls'][] = 'modules/contrib/redis/redis.services.yml';

  // Manually add the classloader path, this is required for the container cache bin definition below
  // and allows to use it without the redis module being enabled.
  $class_loader->addPsr4('Drupal\\redis\\', 'modules/contrib/redis/src');

  // Use redis for container cache.
  // The container cache is used to load the container definition itself, and
  // thus any configuration stored in the container itself is not available
  // yet. These lines force the container cache to use Redis rather than the
  // default SQL cache.
  $settings['bootstrap_container_definition'] = [
    'parameters' => [],
    'services' => [
      'redis.factory' => [
        'class' => 'Drupal\redis\ClientFactory',
      ],
      'cache.backend.redis' => [
        'class' => 'Drupal\redis\Cache\CacheBackendFactory',
        'arguments' => ['@redis.factory', '@cache_tags_provider.container', '@serialization.phpserialize'],
      ],
      'cache.container' => [
        'class' => '\Drupal\redis\Cache\PhpRedis',
        'factory' => ['@cache.backend.redis', 'get'],
        'arguments' => ['container'],
      ],
      'cache_tags_provider.container' => [
        'class' => 'Drupal\redis\Cache\RedisCacheTagsChecksum',
        'arguments' => ['@redis.factory'],
      ],
      'serialization.phpserialize' => [
        'class' => 'Drupal\Component\Serialization\PhpSerialize',
      ],
    ],
  ];
}

if (getenv('PLATFORM_BRANCH')) {
  // Configure private and temporary file paths.
  if (!isset($settings['file_private_path'])) {
    $settings['file_private_path'] = getenv('PLATFORM_APP_DIR') . '/private';
  }
  if (!isset($settings['file_temp_path'])) {
    $settings['file_temp_path'] = getenv('PLATFORM_APP_DIR') . '/tmp';
  }

// Configure the default PhpStorage and Twig template cache directories.
  if (!isset($settings['php_storage']['default'])) {
    $settings['php_storage']['default']['directory'] = $settings['file_private_path'];
  }
  if (!isset($settings['php_storage']['twig'])) {
    $settings['php_storage']['twig']['directory'] = $settings['file_private_path'];
  }

  // Set the project-specific entropy value, used for generating one-time
  // keys and such.
  $settings['hash_salt'] = empty($settings['hash_salt']) ? getenv('PLATFORM_PROJECT_ENTROPY') : $settings['hash_salt'];

  // This will prevent Drupal from setting read-only permissions on sites/default.
  $settings['skip_permissions_hardening'] = TRUE;

  // Set the deployment identifier, which is used by some Drupal cache systems.
  $settings['deployment_identifier'] = $settings['deployment_identifier'] ?? getenv('PLATFORM_TREE_ID');;
}

// The 'trusted_hosts_pattern' setting allows an admin to restrict the Host header values
// that are considered trusted.  If an attacker sends a request with a custom-crafted Host
// header then it can be an injection vector, depending on how the Host header is used.
// However, Platform.sh already replaces the Host header with the route that was used to reach
// Platform.sh, so it is guaranteed to be safe.  The following line explicitly allows all
// Host headers, as the only possible Host header is already guaranteed safe.
$settings['trusted_host_patterns'] = ['.*'];

// Import variables prefixed with 'drupalsettings:' into $settings
// and 'drupalconfig:' into $config.
$platform_variables=json_decode(base64_decode(getenv('PLATFORM_VARIABLES')));
foreach ($platform_variables as $name => $value) {

  // Coerce string values to the most appropriate PHP type.
  // I need to be able to set a config as false, not "false"
  $coerced = $value;
  if (is_string($value)) {
    $lower = strtolower($value);
    if ($lower === 'true') {
      $coerced = true;
    } elseif ($lower === 'false') {
      $coerced = false;
    } elseif ($lower === 'null') {
      $coerced = null;
    } elseif (is_numeric($value)) {
      $coerced = (strpos($value, '.') !== false || stripos($value, 'e') !== false) ? (float) $value : (int) $value;
    } elseif (($value[0] === '{' || $value[0] === '[') && ($decoded = json_decode($value, true)) !== null) {
      $coerced = $decoded;
    }
  }

  $parts = explode(':', $name);
  list($prefix, $key) = array_pad($parts, 3, null);
  switch ($prefix) {
    // Variables that begin with `drupalsettings` or `drupal` get mapped
    // to the $settings array verbatim, even if the value is an array.
    // For example, a variable named drupalsettings:example-setting' with
    // value 'foo' becomes $settings['example-setting'] = 'foo';
    case 'drupalsettings':
    case 'drupal':
      $settings[$key] = $coerced;
      break;
    // Variables that begin with `drupalconfig` get mapped to the $config
    // array.  Deeply nested variable names, with colon delimiters,
    // get mapped to deeply nested array elements. Array values
    // get added to the end just like a scalar. Variables without
    // both a config object name and property are skipped.
    // Example: Variable `drupalconfig:conf_file:prop` with value `foo` becomes
    // $config['conf_file']['prop'] = 'foo';
    // Example: Variable `drupalconfig:conf_file:prop:subprop` with value `foo` becomes
    // $config['conf_file']['prop']['subprop'] = 'foo';
    // Example: Variable `drupalconfig:conf_file:prop:subprop` with value ['foo' => 'bar'] becomes
    // $config['conf_file']['prop']['subprop']['foo'] = 'bar';
    // Example: Variable `drupalconfig:prop` is ignored.
    case 'drupalconfig':
      if (count($parts) > 2) {
        $temp = &$config[$key];
        foreach (array_slice($parts, 2) as $n) {
          $prev = &$temp;
          $temp = &$temp[$n];
        }
        $prev[$n] = $coerced;
      }
      break;
  }
}
