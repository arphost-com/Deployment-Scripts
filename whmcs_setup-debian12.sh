#!/bin/bash

# Exit on error
set -e

# Update system and install basic dependencies first
apt-get update
apt-get install -y \
    curl \
    wget \
    unzip \
    cron \
    pwgen \
    software-properties-common \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    gnupg

# Generate secure passwords
MYSQL_ROOT_PASS=$(pwgen -s 32 1)
WHMCS_DB_PASS=$(pwgen -s 32 1)
WHMCS_ADMIN_PASS=$(pwgen -s 16 1)

# Store passwords in a secure file
echo "MySQL Root Password: $MYSQL_ROOT_PASS" > /root/passwords.txt
echo "WHMCS Database Password: $WHMCS_DB_PASS" >> /root/passwords.txt
echo "WHMCS Admin Password: $WHMCS_ADMIN_PASS" >> /root/passwords.txt
chmod 600 /root/passwords.txt

# Install MariaDB
apt-get install -y mariadb-server mariadb-client

# Secure MariaDB installation
mysql_secure_installation << EOF
n
$MYSQL_ROOT_PASS
$MYSQL_ROOT_PASS
y
y
y
y
y
EOF

# Install Apache
apt-get install -y apache2

# Setup php8.1 repo
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
apt-get update

# Install PHP 8.1 and required extensions
apt-get install -y \
    php8.1 \
    php8.1-cli \
    php8.1-common \
    php8.1-mysql \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-zip \
    php8.1-intl \
    php8.1-ldap \
    php8.1-imap \
    php8.1-soap \
    libapache2-mod-php8.1

# Install Certbot for Let's Encrypt
apt-get install -y certbot python3-certbot-apache

# Enable Apache modules
a2enmod rewrite
a2enmod ssl
a2enmod php8.1
systemctl restart apache2

# Configure PHP 8.1
sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.1/apache2/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.1/apache2/php.ini
sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/8.1/apache2/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.1/apache2/php.ini

# Install IonCube Loader
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xvfz ioncube_loaders_lin_x86-64.tar.gz
cp ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20210902/
echo "zend_extension=/usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/apache2/conf.d/00-ioncube.ini
echo "zend_extension=/usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/cli/conf.d/00-ioncube.ini
rm -rf ioncube ioncube_loaders_lin_x86-64.tar.gz

# Create required directories
mkdir -p /var/www/html
mkdir -p /var/www/templates_c
mkdir -p /var/www/crons
mkdir -p /var/www/downloads
mkdir -p /var/www/attachments

# Set proper permissions for directories
chown -R www-data:www-data /var/www/html
chown -R www-data:www-data /var/www/templates_c
chown -R www-data:www-data /var/www/crons
chown -R www-data:www-data /var/www/downloads
chown -R www-data:www-data /var/www/attachments
chmod 777 /var/www/templates_c
chmod 777 /var/www/crons
chmod 777 /var/www/downloads
chmod 777 /var/www/attachments

# Download WHMCS
curl -o /tmp/whmcs.zip "https://yourdoamin.com/whmcs.zip"
unzip /tmp/whmcs.zip -d /tmp/
cp -R /tmp/whmcs/* /var/www/html/
rm /tmp/whmcs.zip

# Configure Apache
cat > /etc/apache2/sites-available/whmcs.conf << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2ensite whmcs.conf
a2dissite 000-default.conf
systemctl restart apache2

# Set up MariaDB database and user
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE whmcs;"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE USER 'whmcs'@'localhost' IDENTIFIED BY '$WHMCS_DB_PASS';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON whmcs.* TO 'whmcs'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"

# Import WHMCS database
#mysql -u root -p"$MYSQL_ROOT_PASS" whmcs < /tmp/whmcs/install/sql/install.sql

# Create configuration.php
cat > /var/www/html/configuration.php << EOF
<?php
\$license = "";
\$db_host = "localhost";
\$db_username = "whmcs";
\$db_password = "$WHMCS_DB_PASS";
\$db_name = "whmcs";
\$cc_encryption_hash = "$(pwgen -s 32 1)";
\$templates_compiledir = "/var/www/templates_c";
\$crons_dir = "/var/www/crons";
\$download_dir = "/var/www/downloads";
\$attachment_dir = "/var/www/attachments/";
\$admin_folder = "admin";
\$display_errors = false;
\$display_php_errors = false;
\$display_sql_errors = false;
\$display_version = false;
\$display_startup_errors = false;
\$error_reporting = 0;
?>
EOF

# Set proper permissions
chmod 644 /var/www/html/configuration.php
chown www-data:www-data /var/www/html/configuration.php
chmod -R 755 /var/www/html
chmod -R 777 /var/www/templates_c
chmod -R 777 /var/www/crons
chmod -R 777 /var/www/downloads
chmod -R 777 /var/www/attachments
chmod -R 777 /var/www/html/templates_c
chmod -R 777 /var/www/html/crons
chmod -R 777 /var/www/html/downloads
chmod -R 777 /var/www/html/attachments

# Install Let's Encrypt SSL
certbot --apache --non-interactive --agree-tos --email admin@yourdoamin.com --domains yourdoamin.com

# rm index.html
rm /var/www/html/index.html

# Setup WHMCS cron job
(crontab -l 2>/dev/null; echo "*/5 * * * * php -q /var/www/html/crons/cron.php") | crontab -

echo "WHMCS installation completed. Please visit https://yourdoamin.com/install/install.php to complete the setup."
echo "Passwords have been stored in /root/passwords.txt" 
