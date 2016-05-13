#!/bin/bash

set -e

truncate -s 0 /var/mail/app

user="app"
homedir=$(getent passwd $user | cut -d ':' -f6)
phpversion="$1"

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

# Enable http2 and other cool and superfast stuff
sudo a2enmod proxy_fcgi proxy proxy_http http2 ssl expires headers rewrite

# Set up PHP fpm stuff
sudo sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php7.0/fpm/pool.d/www.conf

# Create self signed cert
sudo mkdir -p "$SSL_DIR"
sudo openssl genrsa -out "$SSL_DIR/dev.cream.nl.key" 2048
sudo openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key "$SSL_DIR/dev.cream.nl.key" -out "$SSL_DIR/dev.cream.nl.csr" -passin pass:$PASSPHRASE
sudo openssl x509 -req -days 365 -in "$SSL_DIR/dev.cream.nl.csr" -signkey "$SSL_DIR/dev.cream.nl.key" -out "$SSL_DIR/dev.cream.nl.crt"

# TODO Edit virtualhost
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

echo "==============================="
echo "Done installing dev environment"
