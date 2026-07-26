#!/bin/bash
# ==================================================
# PTERODACTYL PANEL AUTO INSTALLER (FIXED FOR UBUNTU 24.04)
# Clean UI • One Page • Production Ready
# ==================================================

# ---------------- UI THEME ----------------
C_RESET="\e[0m"
C_RED="\e[1;31m"
C_GREEN="\e[1;32m"
C_YELLOW="\e[1;33m"
C_BLUE="\e[1;34m"
C_PURPLE="\e[1;35m"
C_CYAN="\e[1;36m"
C_WHITE="\e[1;37m"
C_GRAY="\e[1;90m"

line(){ echo -e "${C_GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"; }
step(){ echo -e "${C_BLUE}➜ $1${C_RESET}"; }
ok(){ echo -e "${C_GREEN}✔ $1${C_RESET}"; }
warn(){ echo -e "${C_YELLOW}⚠ $1${C_RESET}"; }

banner(){
clear
echo -e "${C_CYAN}"
cat << "EOF"
██████╗ ███████╗████████╗███████╗██████╗  ██████╗ 
██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗
██████╔╝█████╗     ██║   █████╗  ██████╔╝██║   ██║
██╔═══╝ ██╔══╝     ██║   ██╔══╝  ██╔══██╗██║   ██║
██║     ███████╗   ██║   ███████╗██║  ██║╚██████╔╝
╚═╝     ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝ 
        PTERODACTYL PANEL INSTALLER
EOF
echo -e "${C_RESET}"
line
echo -e "${C_GREEN}⚡ Fast • Stable • Production Ready${C_RESET}"
echo -e "${C_PURPLE}🧠 The Coding Hub — 2026 Installer${C_RESET}"
line
}

# ---------------- START ----------------
banner
read -p "🌐 Enter domain (://example.com): " DOMAIN

# Hardcoded safe version for Ubuntu 24.04 to prevent blank variables
PHP_VER="8.3"

# --- Dependencies ---
step "Installing system dependencies..."
apt update && apt install -y curl apt-transport-https ca-certificates gnupg unzip git tar sudo lsb-release

# Detect OS
OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

if [[ "$OS" == "ubuntu" ]]; then
    ok "Detected Ubuntu. Adding PPA for PHP..."
    apt install -y software-properties-common
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
elif [[ "$OS" == "debian" ]]; then
    ok "Detected Debian. Adding PHP repository..."
    curl -fsSL https://sury.org | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://sury.org $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/sury-php.list
fi

# Add Redis GPG key and repo
step "Adding Redis repository..."
curl -fsSL https://redis.io | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://redis.io $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

apt update

# --- Install PHP + extensions ---
step "Installing PHP ${PHP_VER}, MariaDB, Nginx, and Redis..."
apt install -y php${PHP_VER} php${PHP_VER}-{cli,fpm,common,mysql,mbstring,bcmath,xml,zip,curl,gd,tokenizer,ctype,simplexml,dom} mariadb-server nginx redis-server

# --- Install Composer ---
step "Installing Composer..."
curl -sS https://getcomposer.org | sudo php -- --install-dir=/usr/local/bin --filename=composer

# --- Download Pterodactyl Panel ---
step "Downloading Pterodactyl Panel..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# --- MariaDB Setup ---
step "Configuring Database..."
DB_NAME=panel
DB_USER=pterodactyl
DB_PASS="PteroPass$(openssl rand -hex 4)" # Generates a secure random password automatically

mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mariadb -e "FLUSH PRIVILEGES;"

# --- .env Setup ---
if [ ! -f ".env.example" ]; then
    curl -Lo .env.example https://githubusercontent.com
fi
cp .env.example .env
sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|g" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|g" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|g" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env

# --- Install PHP dependencies ---
step "Installing PHP dependencies via Composer..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

# --- Generate Application Key ---
step "Generating application encryption key..."
php artisan key:generate --force

# --- Run Migrations ---
step "Running database migrations and seeding..."
php artisan migrate --seed --force

# --- Permissions ---
chown -R www-data:www-data /var/www/pterodactyl/*
apt install -y cron
systemctl enable --now cron
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# --- Nginx Setup ---
step "Configuring Nginx Web Server..."
mkdir -p /etc/certs/panel
cd /etc/certs/panel
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem

tee /etc/nginx/sites-available/pterodactyl.conf > /dev/null << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    root /var/www/pterodactyl/public;
    index index.php;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_index index.php;
        include /etc/nginx/fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf 2>/dev/null || true
nginx -t && systemctl restart nginx
ok "Nginx is online!"

# --- Queue Worker ---
step "Configuring Pterodactyl Queue Worker..."
tee /etc/systemd/system/pteroq.service > /dev/null << 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis-server
systemctl enable --now pteroq.service
ok "Queue system running!"

clear
step "Create Administrator Account"
# --- Admin User ---
cd /var/www/pterodactyl
php artisan p:user:make

# ---------------- DONE ----------------
line
echo -e "${C_GREEN}🎉 INSTALLATION COMPLETED SUCCESSFULLY${C_RESET}"
line
echo -e "${C_CYAN}🌐 Panel URL    : ${C_WHITE}https://${DOMAIN}${C_RESET}"
echo -e "${C_CYAN}🗄 DB User      : ${C_WHITE}${DB_USER}${C_RESET}"
echo -e "${C_CYAN}🔑 DB Password  : ${C_WHITE}${DB_PASS}${C_RESET}"
line
echo -e "${C_PURPLE}🚀 Panel is live. Enjoy your gaming cloud!${C_RESET}"
line

