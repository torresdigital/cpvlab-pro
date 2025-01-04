#!/bin/bash       
# title         : cpvlab.sh
# description   : This script is to install and configure CPVLab with required components
# author        : Agent F
# date          : 01/04/2023
# notes         : Written for Alamlinux but will work on Rocky, CentOS or RHEL Linux 
# required      : You must supply a domain name, email and CPVLab API key using the relevant switches
# options       : None 
# usage         : cpvlab.sh -d <domain.name> -e <youe@email.com> -a <your_API_Key>
#
# version       : 1.0 - Initial Release
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

    Usage: $SCR_FULL_NAME -d <domain.name> -e <your@email.com> -a <your_api_key>

    Required:
        -d <domain name> Domain name

    Optional: 
        -h Display help

EOF
    exit 1
}
# Set script variables to defaul values
DOMAIN=
# Check input arguments
while getopts ':d:a:e:h' FLAGS; do
  case "$FLAGS" in
    d) DOMAIN="$OPTARG" ;;
    e) EMAIL="$OPTARG" ;;
    a) APIKEY="$OPTARG" ;;
    h) usage ;;
    :) log "Missing argument for -$OPTARG" e
       usage ;;
    ?) log "Invaild option -$OPTARG" e
       usage ;;
  esac
done
shift "$(($OPTIND -1))"
# Log script start time and date
log "$SCR_NAME Script Started: $START" h
VALIDATE="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"
FOLDER="/var/www/html/$DOMAIN/public_html"
# Check domain passes simple validation chcek
if [[ "$DOMAIN" =~ $VALIDATE ]]; then
    log "$DOMAIN PASSED simple domain validation check" m
else
    log "$DOMAIN FAILED simple domain validation check! Please check domain!" e x
fi
if [[ -d "$FOLDER" ]]; then
    log "Installing CPVLab to $FOLDER" m
else
    log "Could not find folder, Please check and retry!" e x
fi  
if [[ ${#APIKEY} -lt 20 ]]; then
    log "APIKEY FAILED simple vailidation check please check you key and retry" e x
else
    log "Using $APIKEY to download CPVLab files" m
fi
###############################################################
# Update server and install required utilites                 # 
###############################################################
log "Updating server and Installing required Utilities please be patient!" h
dnf -y install unzip
# Clean up from lemp script if used
rm -rf $FOLDER/index.html
rm -rf $FOLDER/test.php
###############################################################
# Create database and user                                    #
###############################################################
DBTMP=$(mktemp --dry-run XXXX)
DBNAME=db_$DBTMP
DBUSER=usr_$DBTMP
# Generate random password for database user
DBPASS="$(openssl rand -base64 22)"
log "Username: $DBUSER" m
log "Database: $DBNAME" m
log "Password: $DBPASS" m
# Create database
mysql -e "CREATE DATABASE ${DBNAME};"
log "$DBNAME database created" m
# Grant all privileges to database
mysql -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}';"
log "$DBUSER user granted all privileges on $DBNAME" m
# Flush privileges so user can access database
mysql -e "FLUSH PRIVILEGES;"
log "privileges flushed" m
###############################################################
# Install IonCube Library                                     #
###############################################################
# Find the PHP version running on server
PHPVER=$(php-fpm -i | grep -Po "(?<=PHP Version => ).*" -m 1 | grep -oE '[0-9]{1}\.[0-9]{1}') >> $LOG_FILE 2>&1
if [ "$PHPVER" == "" ]; then
    log "Doesn't look like PHP has been installed on this server!" e x
else
    if [ "$PHPVER" == "8.0" ]; then
        log "PHP version 8.0 is not supported by IonCube!" e x
    else    
        log "PHP version installed is PHP $PHPVER" m
    fi
fi
# Downlaod IonCube file from ioncube.com
curl -O https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
# Create temp folder for extraced files
mkdir extracted
# Extract files locally
tar xfz ioncube_loaders_lin_x86-64.tar.gz -C extracted >> $LOG_FILE 2>&1
# Copy Ioncube library to PHP modules folder
cp extracted/ioncube/ioncube_loader_lin_$PHPVER.so /usr/lib64/php/modules/ >> $LOG_FILE 2>&1
log "Ioncube library copied to PHP modules folder" m
# Create ioncude ini file to load IonCube library
cat > /etc/php.d/00-ioncube.ini << EOF
zend_extension=/usr/lib64/php/modules/ioncube_loader_lin_$PHPVER.so
EOF
log "Ioncube INI file created in php.d folder" m
# Remove IonCube files 
rm -rf extracted >> $LOG_FILE 2>&1
rm -rf ioncube_loaders_lin_x86-64.tar.gz >> $LOG_FILE 2>&1
log "Removed Ioncube download files" m
# Restart PHP-FPM for changes to take effect
systemctl restart php-fpm >> $LOG_FILE 2>&1
log "Restarted PHP-FPM service for install to take effect" m
# Run php -v to check libary loaded OK
php -v
###############################################################
# Install CPVLab                                              #
###############################################################
# Grab CPVLab files from user downlaod area using API Key
curl -o cpvlab.zip https://users.cpvlab.pro/usersc/cpvlabpro-download.php?key=$APIKEY
# unzip CPVLab install files to folder
unzip -q cpvlab.zip -d $FOLDER >> $LOG_FILE 2>&1
log "Extracted CPVLab install files"
# Update schema with todays date
DATE=$(date +"%Y-%m-%d")
sed -i -e "s|{{date-today}}|$DATE|g" $FOLDER/cpvlabpro-db.sql >> $LOG_FILE 2>&1
# update schema with install domain 
sed -i -e "s|{{cpvlabpro-install-domain}}|https://$DOMAIN|g" $FOLDER/cpvlabpro-db.sql >> $LOG_FILE 2>&1
# import database schema into empty database
mysql $DBNAME < $FOLDER/cpvlabpro-db.sql
log "Imported database schema" m
# Update db_params.php file with database settings
sed -i -e "s|yourhost|localhost|" $FOLDER/lib/db_params.php >> $LOG_FILE 2>&1
sed -i -e "s|yourdatabase|$DBNAME|" $FOLDER/lib/db_params.php >> $LOG_FILE 2>&1
sed -i -e "s|youruser|$DBUSER|" $FOLDER/lib/db_params.php >> $LOG_FILE 2>&1
sed -i -e "s|yourpassword|$DBPASS|" $FOLDER/lib/db_params.php >> $LOG_FILE 2>&1
log "CPVLab database settings updated " m
# update license file with registered email
sed -i -e "s|youremail|$EMAIL|" $FOLDER/license/license.php >> $LOG_FILE 2>&1
log "CPVLab license file updated " m
# Generate random password for admin user
ADMINPASS="$(openssl rand -base64 12)"
# Change default password for admin account
mysql -e "update ${DBNAME}.users set Password=MD5('${ADMINPASS}') where UserID=1;" >> $LOG_FILE 2>&1
log "Password has been changed for admin user: $ADMINPASS" m
# set permissions for database and license files
chmod 644 $FOLDER/lib/db_params.php
chmod 644 $FOLDER/license/license.php
log "Permissons for db and license files set" m
# Set permissions for constants-user.php
chmod 666 $FOLDER/lib/constants-user.php
log "Permissons constants-user.php set" m
# set permissions on folders
chmod 777 -R $FOLDER/mobiledata/cache
chmod 777 -R $FOLDER/smarty/templates_c
chmod 777 -R $FOLDER/phpbrowscap/BrowserCache
chmod 777 -R $FOLDER/WURFLres
chown -R nginx:nginx /var/www/html/$DOMAIN
log "Permissons for public folders set" m
# clean up 
rm -rf cpvlab.zip
rm -f $FOLDER/install-db.php
rm -f $FOLDER/install-files.php
rm -f $FOLDER/install-utils.php
rm -f $FOLDER/install-wizard.php
rm -f $FOLDER/install.min.js
rm -f $FOLDER/cpvlabpro-db.sql
rm -f $FOLDER/cpvlabpro-carriers.sql
rm -rf $FOLDER/install
log "Finished clean up" m
###############################################################
# Script end                                                  #
###############################################################
END=$(date +"%A, %m %d %Y %H:%M")
log "$SCR_FULL_NAME script Completed: $END" h
log "To login open https://$DOMAIN/login.php\n\nUser: admin\n\nPassword: $ADMINPASS" h x