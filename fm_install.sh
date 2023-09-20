#!/bin/bash

# I like to setup up with a temp hostname first. This lets me get the new server up
# and running with SSL where I can test filemaker first before moving production data to it.
# While in this test phase, my DNS host record for fm.testes.works points to the public IP of this new server
# CERTBOT_HOSTNAME_SETUP below is used for this purpose.

# Once i'm happy, I move production data to it.
# I change the Elastic IP address from the old server to the new.
# The last thing this install script needs to do is get another SSL cert for the production host name.
# CERTBOT_HOSTNAME_PROD is used as this final host name.

# Required
# The following variables are required to be uncommented and set correctly for the script to work
#DOWNLOAD = "https://downloads.claris.com/esd/fms_20.1.2.207_Ubuntu22_amd64.zip"
#CERTBOT_HOSTNAME_SETUP = "fm.testes.works"
#CERTBOT_HOSTNAME_PROD = "fm.hammond.zone"
#HOSTNAME = "fm20.hammond.zone"
#TIMEZONE = "Australia/Melbourne"
#FM_ADMIN_USER = "admin"
#FM_ADMIN_PASS = "pass"
#FM_ADMIN_PIN  = "1234"
SCRIPT_LOCATION ~/filemaker-server   # default location where this script is installed.

# Optional
# Install optional programs I find handy. Comment these out if not needed
GLANCES = "Yes"
NCDU = "Yes"
IOTOP = "Yes"


# First, copy this script to the home directory so the user can easily run it after login
cp fm_install.sh ~/.

# The state directory is used so that this script can keep track of where it is up to between reboots
mkdir $SCRIPT_LOCATION/state
