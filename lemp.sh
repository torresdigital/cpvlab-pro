#!/bin/bash       
# title         : lemp.sh
# description   : This script is to setup a LEMP VPS, install and configure repos for PHP 8.1, latest nginx mainline branch, latest MariaDB server
# author        : Agent F
# date          : 13/03/2023
# notes         : Written for Alamlinux but will work on Rocky, CentOS or RHEL Linux, SELinux is disabled by default as there are not multiple users logging in etc.
# required      : You must supply a domain name using the -d switch, e.g. -d domain.com
# options       : SELinux and SSHD port can be configured via switches
# usage         : lemp.sh -d <yourdomain.name> [-s {p|e}] [-p <port number>]
#
# version       : 1.0 - Initial Release
#               : 1.1 - Few tweaks with permissions, SELinux and reboot check
#
# Learn about everything affiliate marketing on affLIFT the Fastest Growing Premium Affiliate Community
#
# https://afflift.rocks/r/joinus
#
##############################################################################
# ***** DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING! ***** #
##############################################################################
# Get date and time script started
START=$(date +"%A, %m %d %Y %H:%M")
# Get servers time zone
TIMEZONE=`timedatectl | grep -Po "(?<=Time zone: ).*(?= \()"`
# Get folder script is executing from
SCR_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# Get script full name
SCR_FULL_NAME=`basename "$0"`
# Get script name without extenstion
SCR_NAME=`basename "${0%.*}"`
# Set log file name
LOG_FILE="$SCR_FOLDER/$SCR_NAME.log"
# Rename log file if it already exists
if [[ -f $LOG_FILE ]]; then
    mv $LOG_FILE "$LOG_FILE.old" >> $LOG_FILE 2>&1
fi
# Colours for screen output
OCR='\033[0;31m' # Red
OCY='\033[1;33m' # Yellow
OCG='\033[0;32m' # Green
OCX='\033[0m' # Reset Color
BGW='\e[47m' # White Background
BGR='\e[41m' # Red Background
BGX='\e[40m' # Reset Background
# Function to log messages
function log() {
    case "$2" in
        m) printf "${OCG} $1 ${OCX}\n" ;;
        h) printf "${OCY} $1 ${OCX}\n" ;;
        e) printf "${OCY}${BGR} $1 ${OCX}${BGX}\n" ;;
        *) printf " $1 \n" ;;
    esac
    echo $1 >> $LOG_FILE 2>&1
    if [[ "$3" == x ]]; then
        exit 1
    fi
}
# Display usage help for script
function usage() {
    cat << EOF

    Usage: $SCR_FULL_NAME -d <yourdomain.name> [-s {p|e}] [-p <port number>]

    Required:
        -d <yourdomain.name> Domain name to install to

    SELinux is set to disabled by default (no switch) but you can use the optional switch (-s) to set required value
    SSHD port number can be changed by using the optional switch (-p) to set required value, if not present will use default port 22

    Optional: 
        -s <p> Set SELinux to permissive
        -s <e> Set SELinux to enforcing
        -p <port number> Set SSHD port number
        -h Display help

EOF
    exit 1
}
# Set script variables to defaul values
SELINUX="disabled"
DOMAIN=
SSHPORT="22"
# Check input arguments
while getopts ':d:s:p:h' FLAGS; do
  case "$FLAGS" in
    d) DOMAIN="$OPTARG" ;;
    s) SELINUX="$OPTARG" ;;
    p) SSHPORT="$OPTARG" ;;
    h) usage ;;
    :) log "Missing argument for -$OPTARG" e
       usage ;;
    ?) log "Invaild option -$OPTARG" e
       usage ;;
  esac
done
shift "$(($OPTIND -1))"
# Log script start time and date
log "$SCR_FULL_NAME script Started: $START" h
# Simple regex to check if domain name valid
VALIDATE="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"
# Check domain passes simple validation chcek
if [[ "$DOMAIN" =~ $VALIDATE ]]; then
    log "$DOMAIN PASSED simple domain validation check" m
else
    log "$DOMAIN FAILED simple domain validation check! Please check domain!" e x
fi
# check SSH port passes simple validation chcek
if [[ "$SSHPORT" != "22" ]]; then
    if ! [[ "$SSHPORT" =~ ^[0-9]+$ ]]; then
        log "$SSHPORT FAILED number validation check! Please check port number!" e x
    fi  
fi
log "SSH will be set to use port $SSHPORT" m
# Check for SELinux option and set accordingly, defaulting to enforcing if not present
case "$SELINUX" in
    e) SELINUX="enforcing" ;;
    p) SELINUX="permissive" ;;
    *) SELINUX="disabled" ;;
    esac
log "SELinux will be set to $SELINUX"
# Set SELINUX to required setting
sed -i -e "s|SELINUX=.*|SELINUX=$SELINUX|" /etc/selinux/config >> $LOG_FILE 2>&1
log "SELinux has been set to $SELINUX"
log "A reboot is required to before SELinux setting is set!" h
###############################################################
# Update server and install required utilities                 # 
###############################################################
log "Updating server and Installing required utilities please be patient!" h
dnf -y install policycoreutils-python-utils epel-release >> $LOG_FILE 2>&1
dnf -y update >> $LOG_FILE 2>&1
log "\nUpdated server and Installed require utilities" m
###############################################################
# Configure SSHD and Harden                                   #
###############################################################
log "Starting SSH hardening" m
# Backup ssh_config file
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak >> $LOG_FILE 2>&1
log "backed up sshd_config file to /etc/ssh/sshd_config.bak" m
# Set maximum number of authentication attempts
sed -i -e "s|#MaxAuthTries.*|MaxAuthTries 3|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Set MaxAuthTries to 3" m
# Set login grace period to 45 seconds, which is the amount of time a user has to complete authentication after connecting
sed -i -e "s|#LoginGraceTime.*|LoginGraceTime 45|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Set LoginGraceTime to 45 seconds" m
# Prevent blank or empty passwords
sed -i -e "s|#PermitEmptyPasswords.*|PermitEmptyPasswords no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Set PermitEmptyPasswords to no" m
# Disable rhosts
sed -i -e "s|#IgnoreRhosts.*|IgnoreRhosts no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Disabled rhosts" m
# Disable non used authentication methods which are generally not required
sed -i -e "s|KerberosAuthentication.*|KerberosAuthentication no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
sed -i -e "s|#GSSAPIAuthentication.*|GSSAPIAuthentication no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Disabled non used authentication methods" m
# Disable rarely used options
# X11 forwarding allows for the display of remote graphical applications over an SSH
sed -i -e "s|#X11Forwarding.*|X11Forwarding no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
# Prevent custom environment variables
sed -i -e "s|#PermitUserEnvironment.*|PermitUserEnvironment no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Disabled rarely used options" m
# Disable verbose SSH banner
sed -i -e "s|#Banner.*|Banner no|" /etc/ssh/sshd_config >> $LOG_FILE 2>&1
log "Disabled verbose SSH banner" m
if [[ "$SSHPORT" != "22" ]]; then 
    log "Setting SSH port to $SSHPORT"
    # Change SSH port number
    sed -i -e "s|#Port.*|Port $SSHPORT|" /etc/ssh/sshd_config
    log "SSH port has been set to $SSHPORT" m
    # Update SELinux for new port number if enabled
    semanage port -a -t ssh_port_t -p tcp $SSHPORT >> $LOG_FILE 2>&1
    # Open firewall port for new ssh port
    log "Starting Firewall update for new port $SSHPORT" m
    firewall-cmd --permanent --add-port=$SSHPORT/tcp >> $LOG_FILE 2>&1
    firewall-cmd --reload >> $LOG_FILE 2>&1
    log "Firewall updated for new ssh port $SSHPORT" m
    # Restart sshd for net port to take effect
    systemctl restart sshd.service >> $LOG_FILE 2>&1
fi
log "SSH hardening complete" m
###############################################################
# Install nginx direct from source for latest version         #
###############################################################
# Setup nginx repos
log "Starting nginx install" m
cat > /etc/yum.repos.d/nginx.repo << EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
log "Created nginx repo" m
# Enable nginx mainline repo
dnf config-manager --set-enabled nginx-mainline >> $LOG_FILE 2>&1
log "enabled nginx mainline repo" m
dnf -y install nginx  >> $LOG_FILE 2>&1
log "installed nginx mainline" m
# Backup orginal nginx.conf file
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
log "Backed up original nginx.conf file" m
# Secure nginx config and enable gzip
sed -i -e "s/#gzip  on;/gzip on;/" /etc/nginx/nginx.conf
sed -i -e "/gzip  on;/a\    gzip_vary on;" /etc/nginx/nginx.conf
sed -i -e "/gzip_vary on;/a\    gzip_proxied any;" /etc/nginx/nginx.conf
sed -i -e "/gzip_proxied any;/a\    gzip_comp_level 6;" /etc/nginx/nginx.conf
sed -i -e "/gzip_comp_level 6;/a\    gzip_buffers 16 8k;" /etc/nginx/nginx.conf
sed -i -e "/gzip_buffers 16 8k;/a\    gzip_http_version 1.1;" /etc/nginx/nginx.conf
sed -i -e "/gzip_http_version 1.1;/a\    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;" /etc/nginx/nginx.conf
sed -i -e "/gzip_types/a\    server_tokens off;" /etc/nginx/nginx.conf
sed -i -e "/server_tokens off;/a\    add_header X-Frame-Options \"SAMEORIGIN\";" /etc/nginx/nginx.conf
sed -i -e "/add_header X-Frame-Options \"SAMEORIGIN\";/a\    add_header X-XSS-Protection \"1; mode=block\";" /etc/nginx/nginx.conf
sed -i -e "/add_header X-XSS-Protection/a\    add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains; preload';" /etc/nginx/nginx.conf
sed -i -e "/add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains; preload';/a\    add_header X-Content-Type-Options nosniff;" /etc/nginx/nginx.conf
sed -i -e "/add_header Content-Security-Policy/a\    add_header X-Permitted-Cross-Domain-Policies master-only;" /etc/nginx/nginx.conf
log "Completed secure nginx config and enable gzip" m
# Create folder for web files
mkdir -p /var/www/html/$DOMAIN/public_html >> $LOG_FILE 2>&1
log "Created folder /var/www/html/$DOMAIN/public_html" m
cat > /var/www/html/$DOMAIN/public_html/index.html << EOF
<html><head><title>Welcome to $DOMAIN</title></head><body><h1>Success! This is a test page for <em>$DOMAIN</em> $START.<a href="test.php"><br><br>Check PHP</a></h1><p>This is a test page to show server is working!</p></body></html>
EOF
log "Created test index page for $DOMAIN" m
# Create simple test config file
cat > /etc/nginx/conf.d/$DOMAIN.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root /var/www/html/$DOMAIN/public_html;
    index index.htm index.html index.php;
    autoindex off;
    location ~ \.php$ {
        try_files \$uri \$uri/ =404;
        include fastcgi_params;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        fastcgi_index index.php;
    }
    location / {
        try_files \$uri \$uri/ =404;
    }
    error_page 404 403 500 503 /error.html;
    location /error.html {
        root /var/www/html/$DOMAIN;
        internal;
    } 
}
EOF
log "Simple nginx config file created" m
# Create custom error page 
cat > /var/www/html/$DOMAIN/error.html << EOF
Looking for something?
EOF
log "Created custom error page you can edit it here: /var/www/html/$DOMAIN/error.html" h
# set permissions for nginx on the folder
chown -R nginx:nginx /var/www/html/$DOMAIN
# Configure SELinux to allow nginx 
chcon -Rt httpd_sys_content_t /var/www/html >> $LOG_FILE 2>&1
log "Completed nginx SELinux config" m
# Enable and restart nginx
systemctl enable --now nginx >> $LOG_FILE 2>&1
log "nginx service started and enabled" m
# Open firewall ports for web traffic
log "Starting Firewall update for web traffic" m
firewall-cmd --permanent --add-service={http,https} >> $LOG_FILE 2>&1
firewall-cmd --reload >> $LOG_FILE 2>&1
log "Firewall updated for web traffic" m
log "You should be able to check $DOMAIN in web browser now" h
log "nginx install complete" m
###############################################################
# Install MariaDB direect from source for latest version      #
###############################################################
log "Starting MariaDB install" m
cat > /etc/yum.repos.d/mariadb.repo << EOF
[mariadb]
name = MariaDB
baseurl = https://rpm.mariadb.org/10.11/rhel/\$releasever/\$basearch
gpgkey= https://rpm.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
log "created mariadb repo" m
dnf install -y mariadb-server >> $LOG_FILE 2>&1
# Configure SELinux for mariadb
setsebool -P httpd_can_network_connect_db on
systemctl enable --now mariadb.service >> $LOG_FILE 2>&1
log "mariadb has been installed and service enabled" m
log "MariaDB install complete" m
###############################################################
# Install PHP 8.1                                             #
###############################################################
log "Start PHP8.1 install" m
# Install remi repo
dnf -y install dnf-utils https://rpms.remirepo.net/enterprise/remi-release-9.rpm >> $LOG_FILE 2>&1
# Remove any PHP previuosly installed
dnf -y remove php php-fpm >> $LOG_FILE 2>&1
dnf -y remove php* >> $LOG_FILE 2>&1
dnf -y module list reset php >> $LOG_FILE 2>&1
dnf -y module enable php:remi-8.1 >> $LOG_FILE 2>&1
log "Removed any previous PHP components and set PHP8.1 enabled" m
dnf -y install php php-bcmath php-iconv php-mbstring php-mysqli php-session php-xml php-zip php-xmlreader php-json >> $LOG_FILE 2>&1
log "Intsalled PHP8.1 and components" m
# Create phpinfo test file
cat > /var/www/html/$DOMAIN/public_html/test.php << EOF
<?php echo phpinfo(); ?>
EOF
log "Simple phpinfo test file (test.php) created" m
# Configure SELinux for php-fpm
setsebool -P httpd_can_network_connect on >> $LOG_FILE 2>&1
setsebool -P httpd_execmem on >> $LOG_FILE 2>&1
setsebool -P httpd_unified on >> $LOG_FILE 2>&1
# Tweak PHP settings for nginx
sed -i -e "s|user = apache|user = nginx|" /etc/php-fpm.d/www.conf >> $LOG_FILE 2>&1
sed -i -e "s|group = apache|group = nginx|" /etc/php-fpm.d/www.conf >> $LOG_FILE 2>&1
sed -i -e "s|;listen.owner = nobody|listen.owner = nginx|" /etc/php-fpm.d/www.conf >> $LOG_FILE 2>&1
sed -i -e "s|;listen.group = nobody|listen.group = nginx|" /etc/php-fpm.d/www.conf >> $LOG_FILE 2>&1
sed -i -e "s|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|" /etc/php.ini >> $LOG_FILE 2>&1
sed -i -e "s|;date.timezone =|date.timezone = $TIMEZONE|" /etc/php.ini >> $LOG_FILE 2>&1
sed -i -e "s|memory_limit = 128M|memory_limit = 256M|" /etc/php.ini >> $LOG_FILE 2>&1
sed -i -e "s|expose_php = On|expose_php = off|" /etc/php.ini >> $LOG_FILE 2>&1
log "php tweaks completed" m
systemctl enable --now php-fpm >> $LOG_FILE 2>&1
log "enabled and started php-fpm service" m
log "PHP 8.1 install complete" m
###############################################################
# Install SSL Certificate for domain                          #
###############################################################
# Install snap
dnf -y install snapd >> $LOG_FILE 2>&1
log "snapd installed" m
# Start and enable snap
systemctl enable --now snapd >> $LOG_FILE 2>&1
# Wait for snapd to seed
snap wait system seed.loaded >> $LOG_FILE 2>&1
systemctl restart snapd.seeded.service >> $LOG_FILE 2>&1
systemctl restart snapd.service >> $LOG_FILE 2>&1
log "Enabled and started snapd service" m
# Enable classic snap support
ln -s /var/lib/snapd/snap /snap >> $LOG_FILE 2>&1
# Install certbot
snap install --classic certbot >> $LOG_FILE 2>&1
log "Installed cerbot" m
# Prepare the Certbot command
ln -s /snap/bin/certbot /usr/bin/certbot >> $LOG_FILE 2>&1
# Reun certbot and get certifcate
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN >> $LOG_FILE 2>&1
log "cerbot has run for domain $DOMAIN" m
# enable http/2 support
sed -i -e 's/ssl;/ssl http2;/' /etc/nginx/conf.d/$DOMAIN.conf >> $LOG_FILE 2>&1
log "Finished setting up SSL certifcate for $DOMAIN" m
# Add nginx user to apache group to prevent permissions issues with session files
usermod -a -G apache nginx
systemctl restart php-fpm
###############################################################
# Script end                                                  #
###############################################################
END=$(date +"%A, %m %d %Y %H:%M")
log "$SCR_FULL_NAME script Completed: $END" h
# Script has completed but a rebott is required to change SELinux
log "Server needs to be rebooted to ensure SELinux is properly disabled and ensure everything is working correctly" m
read -e -p "Reboot server now? [y] " REBOOT
REBOOT="${REBOOT:-y}"
if [[ "$REBOOT" == [Yy]* ]]; then
    log "Rebooting server now!" m
    reboot
else
    log "You MUST reboot server to ensure everything is working, ensure you reboot before trying to access your site!" e x
fi
