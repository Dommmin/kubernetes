# =============================================================================
# Stage 1: PHP dependencies (no scripts — run post-install later)
# =============================================================================
FROM composer:2.8 AS vendor

WORKDIR /app
COPY server/composer.json server/composer.lock ./

# --ignore-platform-reqs: composer image lacks gd/exif; extensions exist in
# the production stage. Vendor is copied as-is, so no runtime risk.
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-plugins \
    --prefer-dist \
    --optimize-autoloader \
    --ignore-platform-reqs

# =============================================================================
# Stage 2: Build admin SPA — PHP + Node in one stage (Wayfinder + Vite)
# =============================================================================
FROM dommin/php-8.5-fpm-alpine:latest AS assets

WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --prefer-offline

COPY server/ .
COPY --from=vendor /app/vendor ./vendor

# .env.deploy contains only build-time placeholders — no real secrets.
# Real production .env is mounted at runtime via Kubernetes Secret.
RUN cp .env.deploy .env \
    && mkdir -p \
        storage/framework/views \
        storage/framework/cache \
        storage/framework/sessions \
        storage/logs \
        bootstrap/cache \
    && php artisan key:generate --force \
    && npm run build

# =============================================================================
# Stage 3: Production image — custom PHP 8.5 Alpine base + Nginx + Supervisord
# All PHP extensions (gd, exif, intl, redis, …) pre-installed in the base image.
# =============================================================================
FROM dommin/php-8.5-fpm-alpine:latest AS production

ENV USER_NAME=www-data

RUN apk add --no-cache nginx \
    && mkdir -p /var/log/supervisor /run/nginx

WORKDIR /var/www/html

# Copy application source
COPY server/ .

# Copy compiled vendor + built assets from previous stages
COPY --from=vendor /app/vendor ./vendor
COPY --from=assets /app/public/build ./public/build

# PHP config
COPY .docker/php/php.prod.ini /usr/local/etc/php/conf.d/app.ini
COPY .docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Nginx: production config (HTTP only — TLS terminated at ingress)
# Alpine nginx uses /etc/nginx/http.d/ for vhost configs
COPY .docker/nginx/conf.d/prod.conf /etc/nginx/http.d/default.conf
RUN rm -f /etc/nginx/http.d/default.conf.bak 2>/dev/null || true

# Supervisord
COPY .docker/php/supervisord.prod.conf /etc/supervisor/supervisord.conf

# Start script
COPY .docker/php/start.prod.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Storage & cache dirs with correct permissions
RUN mkdir -p \
        storage/framework/sessions \
        storage/framework/views \
        storage/framework/cache \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/start.sh"]
