#!/bin/bash

#=================================================
#
#   Auteur                  : Lamine TRAORE
#   Date Creation           : 23 mai 2025
#   Commentaire             : Script d'insatallation automatique de PhpIPAM version 7.3
#
#=================================================
read_env() {
  local filePath="${1:-.env}"

  if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
  fi

  echo "Reading $filePath"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

color_echo() {
    COLOR="$1"
    TEXT="$2"
    case "$COLOR" in
        red) CODE="\e[31m" ;;
        green) CODE="\e[32m" ;;
        yellow) CODE="\e[33m" ;;
        blue) CODE="\e[34m" ;;
        magenta) CODE="\e[35m" ;;
        cyan) CODE="\e[36m" ;;
        *) CODE="\e[0m" ;;
    esac
    echo -e "${CODE}${TEXT}\e[0m"
}

#=================================================

LOG_FILE="/tmp/phpipam.log"
ERROR_FILE="/tmp/phpipam_error.log"
PHPIPAM_USER="phpipam"
PHPIPAM_DB="phpipam"
PHPIPAM_PASSWORD="$(openssl rand -base64 12)" # Save this password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)" # Save this password
PHP_MODULE_LIST=("session" "sockets" "openssl" "gmp" "ldap" "xml" "json" "gettext" "filter" "pcntl" "mbstring")
MISSING_MODULES=()
PHPIPAM_CONFIG="/var/www/phpipam"
VHOST_FILE="/etc/apache2/sites-available/phpipam.conf"

 
color_echo green "  ----------------------------------------"
color_echo green "   PHPIPAM Automatic install on debian 12 "
color_echo green "  ----------------------------------------"
color_echo yellow "   📧 : lamine.traore@netopsgn.ovh        "
color_echo green "  ----------------------------------------"

# Must be run as root ! 
if [ "$EUID" -ne 0 ]
then
	color_echo red "❌ Executer ce script avec les privileges root"
	exit 1
fi

# read_env()


color_echo blue " 🛠️ Installation de package necessaire"
echo "-------------------------------------------------"
color_echo blue " ♻️ Mise a jour des paquets"

INSTALL_UPDATE=$(sudo apt-get update -y && sudo apt-get upgrade -y >>${LOG_FILE} 2>>${ERROR_FILE})
IR_UPDATE=$?

color_echo green " ♻️ Installation d'Apache"
INSTALL_1=$(sudo apt-get install apt-get-transport-https apache2 curl gnupg fping -y >>${LOG_FILE} 2>>${ERROR_FILE})
IR1=$?

if [[ "${IR1}" -eq "0" && "${IR_UPDATE}" -eq "0" ]]
then
	color_echo green " ✅ apt-get-transport-https apache2 curl gnupg fping installes avec succes"
else
	color_echo red " ❌ apt-get install  impossible. Voir les fichiers log and error (${LOG_FILE} and ${ERROR_FILE})"
	exit 1
fi

color_echo green " ♻️ Installation de PHP 8 et des modules"

DL_CURL1=$(sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg >>${LOG_FILE} 2>>${ERROR_FILE})
DL_R1=$?
WR_APT=$(sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list')
WR_APT_R=$?
INSTALL_UPDATE=$(sudo apt-get -y update >>${LOG_FILE} 2>>${ERROR_FILE})
IR_UPDATE=$?

INSTALL_2=$(sudo apt-get install -y php8.3 php8.3-cli php-pear php8.3-bz2 php8.3-curl php8.3-mbstring php8.3-intl php8.3-common php8.3-gmp php8.3-ldap php8.3-xml php-pear php8.3-gd php8.3-mysql >>${LOG_FILE} 2>>${ERROR_FILE})
IR2=$?


if [[ "${DL_R1}" -eq "0" && "${WR_APT_R}" -eq "0" && "${IR_UPDATE}" -eq "0" && "${IR2}" -eq "0" ]]
then
	color_echo green "✅ Installation de PHP 8 et des modules Termine avec succes"
else
	color_echo red " ❌ apt install  impossible. Voir les fichiers log and error (${LOG_FILE} and ${ERROR_FILE})"
	exit 1
fi

if [ ! -e "mysql-apt-config_0.8.34-1_all.deb" ]
then
    DL_CURL2=$(curl -L -o mysql-apt-config_0.8.34-1_all.deb https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb >>${LOG_FILE} 2>>${ERROR_FILE})
    DL_R2=$?
    if [[ "${DL_R2}" -eq "0" ]]
    then
        color_echo green "✅ Package mysql-apt-config_0.8.34-1_all.deb telecharge"
    else
        color_echo red " ❌ Impossible de telecharger mysql-apt-config_0.8.34-1_all.deb. Voir les fichiers log and error (${LOG_FILE} and ${ERROR_FILE})"
        exit 1
    fi
    
else
    color_echo red " ❌ Package mysql-apt-config_0.8.34-1_all.deb deja telecharge "
	exit 1
fi

color_echo blue " ♻️ Installation du package mysql-apt-config_0.8.34-1_all.deb"
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | sudo debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-tools select Enabled" | sudo debconf-set-selections
DPKG_I=$(sudo DEBIAN_FRONTEND=noninteractive dpkg --force-depends -i mysql-apt-config_0.8.34-1_all.deb >>${LOG_FILE} 2>>${ERROR_FILE})
R_DPKG=$?
if [[ "${DL_R2}" -eq "0" ]]
then
    color_echo green "✅ Package mysql-apt-config_0.8.34-1_all.deb installe"
else
    color_echo red " ❌ Impossible de d'installe mysql-apt-config_0.8.34-1_all.deb. Voir les fichiers log and error (${LOG_FILE} and ${ERROR_FILE})"
    exit 1
fi
sudo apt-get -y update >>${LOG_FILE} 2>>${ERROR_FILE}

color_echo blue " ♻️ Installation du package mysql-server"

MYSQL_ROOT_INSTALL=""
# Préconfigurer MySQL pour ne pas demander de mot de passe
echo "mysql-community-server mysql-community-server/root-pass password $MYSQL_ROOT_INSTALL" | sudo debconf-set-selections
echo "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_ROOT_INSTALL" | sudo debconf-set-selections
echo "mysql-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | sudo debconf-set-selections

# Installer MySQL Server
INSTALL_MYSQL=$(sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server >>${LOG_FILE} 2>>${ERROR_FILE})
IR3=$?
if [[ "${DL_R2}" -eq "0" ]]
then
    color_echo green "✅ Mysql-server installe"
else
    color_echo red " ❌ Impossible de d'installe Mysql-server . Voir les fichiers log and error (${LOG_FILE} and ${ERROR_FILE})"
    exit 1
fi

# color_echo blue "⚙️ Preparation de mysql"

# sudo mysql -e "USE mysql; UPDATE user SET plugin='caching_sha2_password' WHERE User='root'; FLUSH PRIVILEGES;"

# color_echo blue "⚙️ Preparation de mysql terminer"

color_echo blue "🔍 Vérification des modules PHP..."

for MODULE in "${PHP_MODULE_LIST[@]}"; do
    if ! php -m | grep -qi "^$MODULE$"; then
        MISSING_MODULES+=("$MODULE")
    fi
done

if [ ${#MISSING_MODULES[@]} -eq 0 ]; then
    color_echo green "✅ Tous les modules PHP requis sont installés."
else
    color_echo red "❌ Modules PHP manquants :"
    for MOD in "${MISSING_MODULES[@]}"; do
        color_echo magenta " - $MOD"
    done
    exit 1
fi

color_echo green "⚙️ Preparation de Database pour phpIPAM"

color_echo blue "⚙️ Creation de la database $PHPIPAM_DB"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $PHPIPAM_DB;"
color_echo blue "⚙️ Creation et configuration du user $PHPIPAM_USER"
sudo mysql -e "CREATE USER $PHPIPAM_USER@'%' IDENTIFIED BY '$PHPIPAM_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $PHPIPAM_DB.* TO $PHPIPAM_USER@'%';"
sudo mysql -e "FLUSH PRIVILEGES;"
color_echo green "✅ Database et user cree ..."

# sudo mysql -e "USE mysql; ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"
# sudo mysql -e "USE mysql; ALTER USER 'root'@'localhost' IDENTIFIED BY 'Admin#1234'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"

color_echo green "♻️ Telechargement du package phpIPAM"
curl -L -o phpipam-v1.7.3.tgz https://github.com/phpipam/phpipam/releases/download/v1.7.3/phpipam-v1.7.3.tgz

color_echo green "♻️ Decompression du package"
sudo tar -xf phpipam-v1.7.3.tgz -C /var/www/

color_echo blue "⚙️ Configuration des parametres"
sudo cp "$PHPIPAM_CONFIG/config.dist.php" "$PHPIPAM_CONFIG/config.php"
# sudo sed -i "s/^\(\$db\['host'\] = \)'127.0.0.1';/\1'localhost';/" "$PHPIPAM_CONFIG/config.php"
sudo sed -i "s/^\(\$db\['host'\] = \)'127.0.0.1';/\1'localhost';/" "$PHPIPAM_CONFIG/config.php"
sudo sed -i "s/^\(\$db\['user'\] = \)'phpipam';/\1'$PHPIPAM_USER';/" "$PHPIPAM_CONFIG/config.php"
sudo sed -i "s/^\(\$db\['pass'\] = \)'phpipamadmin';/\1'$PHPIPAM_PASSWORD';/" "$PHPIPAM_CONFIG/config.php"
sudo sed -i "s/^\(\$db\['name'\] = \)'phpipam';/\1'$PHPIPAM_DB';/" "$PHPIPAM_CONFIG/config.php"

color_echo blue "⚙️ Creation du Virtual Host - APACHE"
sudo tee "$VHOST_FILE" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName phpipam.local
    DocumentRoot /var/www/phpipam

    <Directory /var/www/phpipam>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/phpipam_error.log
    CustomLog \${APACHE_LOG_DIR}/phpipam_access.log combined
</VirtualHost>
EOF

echo "✅ VirtualHost écrit dans $VHOST_FILE"

sudo a2enmod rewrite
sudo a2ensite phpipam.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2

color_echo green "MySQL root password"
echo $MYSQL_ROOT_PASSWORD
color_echo green "MySQL User phpipam password"
echo $PHPIPAM_PASSWORD
color_echo green "⚠️ Sauvegarder précieusement ce mot de passe"

# sudo sed -i "s/^\(\$disable_installer = \)false;/\1true;/" "/var/www/phpipam/config.php"