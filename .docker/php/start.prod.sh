#!/bin/sh
set -e

cd /var/www/html

echo "[start] Caching Laravel configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

echo "[start] Starting supervisord (nginx + php-fpm)..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
