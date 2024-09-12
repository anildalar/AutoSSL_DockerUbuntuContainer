#!/bin/bash

echo 'Hello from shell script file';

# Print the environment variable to verify it's loaded
echo "FQDN is: $FQDN"
echo "APP_PORT is: $APP_PORT"
echo "APACHE_REDIRECT_HTTP_TO_HTTPS is: $APACHE_REDIRECT_HTTP_TO_HTTPS"

# Handle ServerName Warning
echo "ServerName $FQDN" >> /etc/apache2/apache2.conf

# Create the Apache Virtual Host for the FQDN# Check if APACHE_REDIRECT_HTTP_TO_HTTPS is enabled
if [ "$APACHE_REDIRECT_HTTP_TO_HTTPS" = "true" ]; then
    echo "HTTP to HTTPS redirection is enabled."
    # Create the Apache Virtual Host for HTTP (port 80) to redirect to HTTPS
    cat <<EOL > /etc/apache2/sites-available/$FQDN.conf
<VirtualHost *:80>
    ServerName $FQDN
    Redirect permanent / https://$FQDN/
</VirtualHost>
EOL
else
    echo "HTTP to HTTPS redirection is not enabled."
    # Create the Apache Virtual Host for the FQDN on port 80 without redirection
    cat <<EOL > /etc/apache2/sites-available/$FQDN.conf
<VirtualHost *:80>
    ServerName $FQDN
    DocumentRoot $WORK_DIR

    <Directory $WORK_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL
fi

# Create the Apache Virtual Host for the FQDN on port 443 (HTTPS)
cat <<EOL > /etc/apache2/sites-available/$FQDN-ssl.conf
<VirtualHost *:443>
    ServerName $FQDN
    DocumentRoot $WORK_DIR

    <Directory $WORK_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$FQDN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$FQDN/privkey.pem

    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined
</VirtualHost>
EOL

# Enable the virtual host and SSL module
a2ensite $FQDN.conf
SSL_CERT_DIR="/etc/letsencrypt/live/$FQDN"

if [ -f "$SSL_CERT_DIR/fullchain.pem" ] && [ -f "$SSL_CERT_DIR/privkey.pem" ]; then
    echo "Enabling SSL site for $FQDN"
    a2ensite $FQDN-ssl.conf
else
    echo "SSL certificate not found. Skipping SSL site enablement."
fi
a2enmod ssl

# Check if Let's Encrypt is enabled
if [ "$LETSENCRYPT_ENABLED" = "true" ]; then
    echo "Let's Encrypt is enabled. Requesting certificate for $FQDN..."

    # Request the certificate using Certbot
    certbot --apache -n --agree-tos --email admin@$FQDN --redirect --expand \
            --domains $FQDN --keep-until-expiring --non-interactive

else
    echo "Let's Encrypt is not enabled. Skipping certificate request."
fi


echo "Reloading Apache to apply the SSL configuration..."
# Reload Apache to apply the SSL configuration

apachectl -D FOREGROUND
