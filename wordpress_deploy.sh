#!/bin/bash

# WordPress Auto-Deploy Script for Debian Linux
# This script automates the installation and configuration of WordPress

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Check for domain name argument
if [ -z "$1" ]; then
    echo "Usage: $0 <domain_name>"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN_NAME=$1

# Function to check DNS resolution
check_dns() {
    local domain=$1
    if ! host $domain &>/dev/null; then
        echo "Error: Domain $domain does not resolve to this server's IP address"
        echo "Please ensure your DNS records are properly configured before running this script"
        exit 1
    fi
}

# Check DNS resolution for both domain and www subdomain
echo "Checking DNS configuration..."
check_dns $DOMAIN_NAME
check_dns www.$DOMAIN_NAME

# Generate random passwords
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_WP_PASSWORD=$(openssl rand -base64 12)
WP_ADMIN_PASSWORD=$(openssl rand -base64 12)

# Save credentials to file
echo "Saving credentials to /root/wordpress_credentials.txt..."
cat > /root/wordpress_credentials.txt <<EOF
WordPress Installation Credentials
=================================
Domain Name: $DOMAIN_NAME
MySQL Root Password: $MYSQL_ROOT_PASSWORD
WordPress Database Password: $MYSQL_WP_PASSWORD
WordPress Admin Password: $WP_ADMIN_PASSWORD

MariaDB Secure Installation Steps:
1. Remove anonymous users: Yes
2. Disallow root login remotely: Yes
3. Remove test database and access to it: Yes
4. Reload privilege tables now: Yes
EOF
chmod 600 /root/wordpress_credentials.txt

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Add PHP 8.2 repository for Debian 12
echo "Adding PHP 8.2 repository..."
apt-get install -y ca-certificates apt-transport-https software-properties-common lsb-release
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
apt-get update

# Install required packages
echo "Installing required packages..."
apt-get install -y apache2 mariadb-server php8.2 php8.2-mysql php8.2-gd php8.2-curl php8.2-mbstring php8.2-xml php8.2-xmlrpc php8.2-soap php8.2-intl php8.2-zip php8.2-fpm libapache2-mod-php8.2

# Enable PHP 8.2 FPM
echo "Configuring PHP 8.2 FPM..."
a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm
systemctl restart apache2

# Start and enable services
echo "Starting and enabling services..."
systemctl start apache2
systemctl enable apache2
systemctl start mariadb
systemctl enable mariadb
systemctl start php8.2-fpm
systemctl enable php8.2-fpm

# Configure MariaDB
echo "Configuring MariaDB..."
# Set root password and run secure installation
mysql_secure_installation <<EOF
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
y
EOF

# Create WordPress database and user
echo "Creating WordPress database and user..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '$MYSQL_WP_PASSWORD';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EOF

# Remove default index.html
echo "Removing default index.html..."
rm -f /var/www/html/index.html

# Download and configure WordPress
echo "Downloading and configuring WordPress..."
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm latest.tar.gz
mv wordpress/* .
rm -rf wordpress

# Create wp-config.php
echo "Creating wp-config.php..."
cat > wp-config.php <<EOF
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', '$MYSQL_WP_PASSWORD');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if (!defined('ABSPATH'))
    define('ABSPATH', __DIR__ . '/');

require_once ABSPATH . 'wp-settings.php';
EOF

# Set proper permissions
echo "Setting proper permissions..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Configure Apache for domain
echo "Configuring Apache for domain $DOMAIN_NAME..."
cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN_NAME
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable Apache modules and site
a2enmod rewrite
a2dissite 000-default.conf
a2ensite wordpress.conf

# Configure PHP
echo "Configuring PHP..."
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.2/apache2/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.2/apache2/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.2/apache2/php.ini

# Install and configure Let's Encrypt
echo "Installing and configuring Let's Encrypt..."
apt-get install -y certbot python3-certbot-apache

# Create a temporary file for certbot configuration
cat > /tmp/certbot.ini <<EOF
rsa-key-size = 2048
email = webmaster@$DOMAIN_NAME
authenticator = apache
installer = apache
agree-tos = True
redirect = True
register-unsafely-without-email = True
EOF

# Run certbot with the configuration file
certbot --config /tmp/certbot.ini -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive

# Clean up temporary file
rm /tmp/certbot.ini

# Restart services to apply changes
echo "Restarting services..."
systemctl restart php8.2-fpm
systemctl restart apache2

echo "WordPress installation completed!"
echo "Credentials have been saved to /root/wordpress_credentials.txt"
echo "WordPress is available at https://$DOMAIN_NAME"
echo "Please complete the WordPress setup by visiting https://$DOMAIN_NAME"
