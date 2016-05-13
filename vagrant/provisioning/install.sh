#!/bin/bash

set -e

truncate -s 0 /var/mail/app

# Set PHP version used
# TODO use version check to switch between 5.x and 7.0
phpversion="$1"

# Set SSL information (self-signed)
SSL_DIR="/etc/ssl"
DOMAIN="*.dev.cream.nl"
PASSPHRASE=""
SUBJ="
C=NL
ST=Zuid Holland
O=
localityName=Berkel en Rodenrijs
commonName=$DOMAIN
organizationalUnitName=
emailAddress=
"

# update and install dependencies
sudo apt-get update
sudo apt-get install -y build-essential git python-software-properties openssl

# Set Apache and PHP repositories
sudo add-apt-repository -y ppa:ondrej/apache2
sudo add-apt-repository -y ppa:ondrej/php

sudo apt-key update
sudo apt-get update

# Install apache and PHP7
sudo apt-get install -y apache2 php7.0-fpm

# Enable http2 and other apache modules
sudo a2enmod proxy_fcgi proxy proxy_http http2 ssl expires headers rewrite

# Set up PHP fpm stuff
sudo sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php/7.0/fpm/pool.d/www.conf

# Create self signed cert
sudo mkdir -p "$SSL_DIR"
sudo openssl genrsa -out "$SSL_DIR/dev.cream.nl.key" 2048
sudo openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key "$SSL_DIR/dev.cream.nl.key" -out "$SSL_DIR/dev.cream.nl.csr" -passin pass:$PASSPHRASE
sudo openssl x509 -req -days 365 -in "$SSL_DIR/dev.cream.nl.csr" -signkey "$SSL_DIR/dev.cream.nl.key" -out "$SSL_DIR/dev.cream.nl.crt"

# Edit virtualhost
cat > /etc/apache2/sites-enabled/000-default.conf << EOF
<VirtualHost *:80>
	DocumentRoot /var/www/html
	ServerName vagrant.dev.cream.nl
	ServerAlias creamdev.local

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	<Directory /var/www/html>
		Options -Indexes +FollowSymLinks +MultiViews
		AllowOverride All
		Require all granted
	</Directory>

	# php handler
	ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:9000/var/www/html/$1
</VirtualHost>

<VirtualHost *:443>
	DocumentRoot /var/www/html
	ServerName dev.cream.nl
	ServerAlias *.dev.cream.nl
	ServerAlias creamdev.local

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	SSLEngine on
	SSLCertificateFile /etc/ssl/dev.cream.nl.crt
	SSLCertificateKeyFile /etc/ssl/dev.cream.nl.key

	<Directory /var/www/html>
		Options -Indexes +FollowSymLinks +MultiViews
		AllowOverride All
		Require all granted
	</Directory>

	# php handler
	ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:9000/var/www/html/$1

	# Enable http2
	Protocols h2 http/1.1
</VirtualHost>
EOF

# Restart & go
sudo service apache2 restart
sudo service php7.0-fpm restart

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Install Node JS & update NPM
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g npm@latest

echo "==============================="
echo "Done installing dev environment"
