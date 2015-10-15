#!/bin/bash
 
################################
## Guacamole Installer Script ##
## Green Reed Technology 2015 ##
##       Martez Reed          ##
################################
 
## Define variables
 
guac_version=0.9.7
mysql_version=5.1.35
 
mysql_username=root
mysql_password=greenrt
 
ssl_country=US
ssl_state=IL
ssl_city=Chicago
ssl_org=IT
ssl_certname=guacamole.company.local
 
#System Update
sudo apt-get update -y
 
#System Upgrade
sudo apt-get upgrade -y
 
#Install Tomcat 7
sudo apt-get install -y tomcat7
 
# Install Packages
sudo apt-get install -y make libcairo2-dev libjpeg62-turbo-dev libpng12-dev libossp-uuid-dev libpango-1.0-0 libpango1.0-dev libssh2-1-dev libpng12-dev freerdp-x11 libssh2-1 libvncserver-dev libfreerdp-dev libvorbis-dev libssl1.0.0 gcc libssh-dev libpulse-dev tomcat7-admin tomcat7-docs libtelnet-dev libossp-uuid-dev
 
#Download Guacamole Client
sudo wget http://sourceforge.net/projects/guacamole/files/current/binary/guacamole-$guac_version.war
 
#Download Guacamole Server
sudo wget http://sourceforge.net/projects/guacamole/files/current/source/guacamole-server-$guac_version.tar.gz
 
# Untar the guacamole server source files
sudo tar -xzf guacamole-server-$guac_version.tar.gz
 
# Change directory to the source files
cd guacamole-server-$guac_version/
 
#
sudo ./configure --with-init-dir=/etc/init.d
 
#
sudo make
 
#
sudo make install
 
#
sudo update-rc.d guacd defaults
 
#
sudo ldconfig
 
# Create guacamole configuration directory
sudo mkdir /etc/guacamole
 
# Create guacamole.properties configuration file
sudo cat <<EOF1 > /etc/guacamole/guacamole.properties
# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port:     4822
 
 
# Auth provider class (authenticates user/pass combination, needed if using the provided login screen)
#auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
#basic-user-mapping: /etc/guacamole/user-mapping.xml
 
# Auth provider class
auth-provider: net.sourceforge.guacamole.net.auth.mysql.MySQLAuthenticationProvider
 
# MySQL properties
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacamole
mysql-username: guacamole
mysql-password: $mysql_password
 
lib-directory: /var/lib/guacamole/classpath
EOF1
 
#
sudo mkdir /usr/share/tomcat7/.guacamole
 
# Create a symbolic link of the properties file for Tomcat7
sudo  ln -s /etc/guacamole/guacamole.properties /usr/share/tomcat7/.guacamole

# Move up a directory to copy the guacamole.war file
cd ..
 
# Copy the guacamole war file to the Tomcat 7 webapps directory
sudo cp guacamole-$guac_version.war /var/lib/tomcat7/webapps/guacamole.war
 
# Start the Guacamole (guacd) service
sudo service guacd start
 
# Restart Tomcat 7
sudo service tomcat7 restart
 
########################################
# MySQL Installation and configuration #
########################################
 
# Download Guacamole MySQL Authentication Module
sudo wget http://sourceforge.net/projects/guacamole/files/current/extensions/guacamole-auth-jdbc-$guac_version.tar.gz
 
# Untar the Guacamole MySQL Authentication Module
sudo tar -xzf guacamole-auth-jdbc-$guac_version.tar.gz
 
# Create Guacamole classpath directory for MySQL Authentication files
sudo mkdir -p /var/lib/guacamole/classpath
 
# Copy Guacamole MySQL Authentication module files to the created directory
sudo cp guacamole-auth-jdbc-$guac_version/mysql/guacamole-auth-jdbc-mysql-$guac_version.jar /var/lib/guacamole/classpath/
 
# Download MySQL Connector-J
sudo wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$mysql_version.tar.gz
 
# Untar the MySQL Connector-J
sudo tar -xzf mysql-connector-java-$mysql_version.tar.gz
 
# Copy the MySQL Connector-J jar file to the guacamole classpath diretory
sudo cp mysql-connector-java-$mysql_version/mysql-connector-java-$mysql_version-bin.jar /var/lib/guacamole/classpath/
 
# Provide mysql root password to automate installation
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysql_password"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysql_password"
 
# Install MySQL
sudo apt-get install -y mysql-server
 
# Lay down mysql configuration script
sudo cat <<EOF2 > guacamolemysql.sql
#MySQL Guacamole Script
CREATE DATABASE guacamole;
CREATE USER 'guacamole'@'localhost' IDENTIFIED BY '$mysql_password';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole.* TO 'guacamole'@'localhost';
FLUSH PRIVILEGES;
quit
EOF2
 
# Create Guacamole database and user
sudo mysql -u root --password=$mysql_password < guacamolemysql.sql
 
# Change directory to mysql-auth directory
cd guacamole-auth-jdbc-$guac_version/mysql
 
# Run database scripts to create schema and users
sudo cat schema/*.sql | mysql -u root --password=$mysql_password guacamole
 
##########################################
# NGINX Installation and configuration #
##########################################
 
# Install Nginx
sudo apt-get install -y nginx
 
# Create directory to store server key and certificate
sudo mkdir /etc/nginx/ssl
 
# Create self-signed certificate
sudo openssl req -x509 -subj '/C=US/ST=IL/L=Chicago/O=IT/CN=$hostname' -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -extensions v3_ca
 
# Add proxy settings to nginx config file (/etc/nginx/sites-enabled/default)
# Borrowed configuration from Eric Oud Ammerveled (http://sourceforge.net/p/guacamole/discussion/1110834/thread/6961d682/#aca9)
 
sudo cat << EOF3 > /etc/nginx/sites-enabled/default
# ANOTHER SERVER LISTENING ON PORT 443 (SSL) to secure the Guacamole traffic and proxy the requests to Tomcat7
server {
    listen 443 ssl;
    server_name     $hostname;
# This part is for SSL config only
    ssl on;
    ssl_certificate      /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key  /etc/nginx/ssl/nginx.key;
    ssl_session_cache shared:SSL:10m;
    ssl_ciphers 'AES256+EECDH:AES256+EDH:!aNULL';
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_prefer_server_ciphers on;
#    ssl_dhparam /etc/ssl/certs/dhparam.pem;
# Found below settings to be performing best but it will work with your own
    tcp_nodelay    on;
    tcp_nopush     off;
    sendfile       on;
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;
    client_body_timeout 12;
    client_header_timeout 12;
    keepalive_timeout 15;
    send_timeout 10;
# HINT: You might want to enable access_log during the testing!
    access_log off;
# Don't turn ON proxy_buffering!; this will impact the line quality
    proxy_buffering off;
    proxy_redirect  off;
# Enabling websockets using the first 3 lines; Check /var/log/tomcat8/catalina.out while testing; guacamole will show you a fallback message if websockets fail to work.
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
# Just something that was advised by someone from the dev team; worked fine without it too.
    proxy_cookie_path /guacamole/ /;
    location / {
            # I am running the Tomcat7 and Guacamole on the local server
            proxy_pass http://localhost:8080;
            break;
    }
}
EOF3
 
# Restart nginx service
sudo service nginx restart
 
# Restart tomcat7
sudo service tomcat7 restart
 
# Restart guacd
sudo service guacd restart
 
################################################
#           Firewall Configuration             #
################################################
 
# Disable Firewall 
sudo ufw disable
 
# Allow HTTPS access
sudo ufw allow https

# Allow SSH access
sudo ufw allow ssh

# Enable Firewall
sudo ufw enable
 
# Disable IPv6
sudo cat <<EOF3 >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF3
 
# Activate sysctl
sudo sysctl -p
