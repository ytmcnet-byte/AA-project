#!/usr/bin/env bash
set -e

echo "======================================"
echo "  Pterodactyl Repair One-Click Script"
echo "======================================"

PANEL_DIR="/var/www/pterodactyl"

echo "[1/9] Creating PHP socket directory..."
mkdir -p /run/php
chown www-data:www-data /run/php
chmod 755 /run/php

echo "[2/9] Starting PHP-FPM..."
php-fpm8.3 -D || true

echo "[3/9] Starting Nginx..."
nginx || true

echo "[4/9] Fixing MariaDB socket..."
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chmod 755 /run/mysqld

echo "[5/9] Starting MariaDB..."
mysqld_safe --user=mysql >/dev/null 2>&1 &
sleep 5

echo "[6/9] Detecting DB password..."
DB_PASSWORD=$(grep '^DB_PASSWORD=' "$PANEL_DIR/.env" | cut -d= -f2-)

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ DB_PASSWORD not found in $PANEL_DIR/.env"
    exit 1
fi

echo "[7/9] Creating database and user if missing..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS panel;
CREATE USER IF NOT EXISTS 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER 'pterodactyl'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "[8/9] Fixing permissions..."
cd "$PANEL_DIR"

chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "[9/9] Clearing cache and running migrations..."
php artisan config:clear
php artisan cache:clear
php artisan view:clear
php artisan migrate --seed --force

echo "Reloading services..."
nginx -s reload || true
php-fpm8.3 -D || true
mysqld_safe --user=mysql >/dev/null 2>&1 &

echo
echo "========== Process Status =========="
ps aux | grep nginx | grep -v grep || true
ps aux | grep php-fpm | grep -v grep || true
ps aux | grep mariadbd | grep -v grep || true

echo
echo "✅ Pterodactyl repair completed."
