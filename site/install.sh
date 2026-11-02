#!/usr/bin/env bash
# Runs inside the web container: installs Drupal's Umami demo the way Goose's
# examples/umami README describes, then serves it with Apache.
set -euo pipefail

cd /opt/drupal
composer require --no-interaction --quiet drush/drush
drush() { php -d memory_limit=-1 vendor/drush/drush/drush.php "$@"; }
drush site:install demo_umami -y \
  --db-url="mysql://drupal:${DB_PASSWORD}@db:3306/drupal" \
  --account-name=admin --account-pass="$ADMIN_PASSWORD"
drush config:set system.mail interface.default test_mail_collector -y
drush cron
chown -R www-data:www-data web/sites/default/files
exec apache2-foreground
