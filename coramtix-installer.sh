#!/bin/bash
set -e

# ======================================
#  CoRamTix Panel Installer (Fixed)
#  Single File – No lib.sh required
# ======================================

# ----- Utility functions -----
output() { echo -e "\e[32m$1\e[0m"; }
warning() { echo -e "\e[33m$1\e[0m"; }
error() { echo -e "\e[31m$1\e[0m"; }
print_brake() { printf '%*s\n' "$1" '' | tr ' ' '='; }

# Random password generator
gen_passwd() {
  < /dev/urandom tr -dc A-Za-z0-9 | head -c ${1:-32}
}

# Required input helper
required_input() {
  local var_name=$1
  local prompt=$2
  local err=$3
  local default=$4
  while true; do
    echo -n "$prompt"
    read -r input
    [ -z "$input" ] && input=$default
    if [ -n "$input" ]; then
      eval "$var_name=\"$input\""
      break
    else
      error "$err"
    fi
  done
}

# ----- Installer main -----
main() {
  print_brake 60
  output "🚀 Installing CoRamTix Panel"
  print_brake 60

  # Update system
  apt update -y && apt upgrade -y

  # Install dependencies
  apt install -y curl wget tar unzip git jq mariadb-server nginx php php-cli php-mysql php-gd php-curl php-mbstring php-xml composer redis-server

  # Database setup
  MYSQL_DB="coramtix"
  MYSQL_USER="coramtix"
  MYSQL_PASSWORD=$(gen_passwd 24)

  mysql -u root -e "CREATE DATABASE $MYSQL_DB;"
  mysql -u root -e "CREATE USER '$MYSQL_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_PASSWORD';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON $MYSQL_DB.* TO '$MYSQL_USER'@'127.0.0.1';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  # Download panel
  mkdir -p /var/www/coramtix
  cd /var/www/coramtix
  curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xz
  composer install --no-dev --optimize-autoloader

  # Permissions
  chown -R www-data:www-data /var/www/coramtix
  chmod -R 755 /var/www/coramtix

  # Env file
  cp .env.example .env
  php artisan key:generate --force
  php artisan migrate --seed --force

  # Nginx config
  cat > /etc/nginx/sites-available/coramtix.conf <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/coramtix/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

  ln -s /etc/nginx/sites-available/coramtix.conf /etc/nginx/sites-enabled/
  nginx -t && systemctl restart nginx

  print_brake 60
  output "✅ CoRamTix Panel Installed!"
  output "DB Name: $MYSQL_DB"
  output "DB User: $MYSQL_USER"
  output "DB Pass: $MYSQL_PASSWORD"
  print_brake 60
}

main
