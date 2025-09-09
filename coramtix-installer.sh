#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'coramtix-installer'                                                       #
#                                                                                    #
# This script is based on pelican-installer (GPL Licensed).                          #
# Modified for CoRamTix Panel installation.                                          #
#                                                                                    #
######################################################################################

fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

export FQDN=""
export MYSQL_DB=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""

export timezone=""
export email=""

export user_email=""
export user_username=""
export user_firstname=""
export user_lastname=""
export user_password=""

export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=false
export CONFIGURE_FIREWALL=false

check_FQDN_SSL() {
  if [[ $(invalid_ip "$FQDN") == 1 && $FQDN != 'localhost' ]]; then
    SSL_AVAILABLE=true
  else
    warning "* Let's Encrypt will not be available for IP addresses."
  fi
}

main() {
  if [ -d "/var/www/coramtix" ]; then
    warning "The script has detected CoRamTix already exists at /var/www/coramtix!"
    echo -e -n "* Proceed anyway? (y/N): "
    read -r CONFIRM_PROCEED
    [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]] && exit 1
  fi

  welcome "CoRamTix Panel"

  check_os_x86_64

  MYSQL_DB="-"
  while [[ "$MYSQL_DB" == *"-"* ]]; do
    required_input MYSQL_DB "Database name (coramtixpanel): " "" "coramtixpanel"
    [[ "$MYSQL_DB" == *"-"* ]] && error "Database name cannot contain hyphens"
  done

  MYSQL_USER="-"
  while [[ "$MYSQL_USER" == *"-"* ]]; do
    required_input MYSQL_USER "Database username (coramtix): " "" "coramtix"
    [[ "$MYSQL_USER" == *"-"* ]] && error "Database user cannot contain hyphens"
  done

  rand_pw=$(gen_passwd 64)
  password_input MYSQL_PASSWORD "Password (press enter to use randomly generated): " "Cannot be empty" "$rand_pw"

  readarray -t valid_timezones <<<"$(curl -s "$GITHUB_URL"/configs/valid_timezones.txt)"
  while [ -z "$timezone" ]; do
    echo -n "* Select timezone [UTC]: "
    read -r timezone_input
    array_contains_element "$timezone_input" "${valid_timezones[@]}" && timezone="$timezone_input"
    [ -z "$timezone_input" ] && timezone="UTC"
  done

  email_input email "Provide system email: " "Email cannot be empty"

  email_input user_email "Admin email: " "Required"
  required_input user_username "Admin username: " "Required"
  required_input user_firstname "Admin firstname: " "Required"
  required_input user_lastname "Admin lastname: " "Required"
  password_input user_password "Admin password: " "Required"

  while [ -z "$FQDN" ]; do
    echo -n "* Set FQDN (panel.example.com): "
    read -r FQDN
    [ -z "$FQDN" ] && error "FQDN cannot be empty"
  done

  check_FQDN_SSL

  summary

  echo -e -n "\n* Continue installation? (y/N): "
  read -r CONFIRM
  [[ ! "$CONFIRM" =~ [Yy] ]] && exit 1

  run_installer "coramtix"
}

summary() {
  print_brake 62
  output "CoRamTix panel on $OS"
  output "Database: $MYSQL_DB"
  output "User: $MYSQL_USER"
  output "Timezone: $timezone"
  output "Admin: $user_username"
  output "FQDN: $FQDN"
  print_brake 62
}

goodbye() {
  print_brake 62
  output "✅ CoRamTix Panel installation completed"
  output "Visit: https://$FQDN"
  print_brake 62
}

main
goodbye
