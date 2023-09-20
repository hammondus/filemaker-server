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
# ALL The following variables are required to be uncommented and set correctly for the script to work
DOWNLOAD=https://downloads.claris.com/esd/fms_20.1.2.207_Ubuntu22_amd64.zip
CERTBOT_HOSTNAME_SETUP=fm.testes.works
#CERTBOT_HOSTNAME_PROD=fm.hammond.zone
CERTBOT_EMAIL=craig@blueskyflying.com.au
HOSTNAME=fmtestes.hammond.zone
TIMEZONE=Australia/Melbourne
FM_ADMIN_USER=admin
FM_ADMIN_PASSWORD=pass
FM_ADMIN_PIN=1234
HOME_LOCATION=/home/ubuntu
SCRIPT_LOCATION=$HOME_LOCATION/filemaker-server   # default location where this script is installed.
STATE=$SCRIPT_LOCATION/state
ASSISTED_FILE=$HOME_LOCATION/fminstall/AssInst.txt

#Be careful with the drive settings. The script doesn't check that what you have put in is correct.
#Only put in devices that are completely blank. Devices listed below will be partitioned and formatted.
DRIVE_DATABASES=/dev/nvme2n1
DRIVE_CONTAINERS=/dev/nvme3n1
DRIVE_BACKUPS=/dev/nvme1n1

################################### END OF REQUIRED VARIABLES ########################

# Optional
# Install optional programs I find handy. Comment these out if not needed
GLANCES=Yes
NCDU=Yes
IOTOP=Yes


# First, copy this script to the home directory so the user can easily run it after login
if [ ! -f ~/fm_install.sh ]; then
  ln -s $SCRIPT_LOCATION/fm_install.sh $HOME_LOCATION/fm_install.sh
fi


# The state directory is used so that this script can keep track of where it is up to between reboots
if [ ! -d $STATE ]; then
  echo "creating state directory"
  mkdir $STATE
fi


#Check we are on the correct version of Ubuntu
if [ -f /etc/os-release ]; then
  . /etc/os-release
  VER=$VERSION_ID
  if [ "$VER" != "22.04" ]; then
    echo "Wrong version of Ubuntu. Must be 22.04"
    echo "You are running" $VER 
    exit 9
  else
    echo "Good. You are Ubuntu" $VER
  fi
fi

#Make sure the system is up to date and reboot if necessary
if [ ! -f $STATE/apt-upgrade ]; then
  echo 'apt update/upgrade not done. doing it now'
  sudo apt update && sudo apt upgrade -y
  if [ -f /var/run/reboot-required ]; then
    echo "Reboot is required. Reboot then rerun this script"
    exit 1
  fi
fi
touch $STATE/apt-upgrade

if [ ! -f $STATE/timezone-set ]; then 
  sudo timedatectl set-timezone $TIMEZONE || { echo "Error setting timezone"; exit 9; }
  timedatectl
  touch $STATE/timezone-set
  exit
fi

if [ ! -f $STATE/hostname-set ]; then
  if [ ! sudo hostnamectl set-hostname $HOSTNAME ]; then
    echo "Problem setting hostname"
    exit 9
  fi
fi
touch $STATE/hostname-set

#Install unzip if it's not installed. Not optional
#The download from claris needs to be unzipped.
type unzip > /dev/null 2>&1 || sudo apt install unzip -y

#Install optional software if they have been selected
if [ "$GLANCES" = "Yes" ]; then
  type glances > /dev/null 2>&1 || sudo apt install glances -y || { echo "Error installing Glances"; exit 9; }
fi
if [ $NCDU = "Yes" ]; then
  type ncdu > /dev/null 2>&1 || sudo apt install ncdu -y || { echo "Error installing NCDU"; exit 9; }
fi
if [ $IOTOP = "Yes" ]; then
  type iotop > /dev/null 2>&1 || sudo apt install iotop-c -y || { echo "Error installing iotop-c"; exit 9; }
fi

#Download filemaker
if [ ! -f $STATE/filemaker-downloaded ]; then
  if mkdir $HOME_LOCATION/fminstall; then
    cd $HOME_LOCATION/fminstall
    if wget $DOWNLOAD; then
      unzip ./fms*
    else
      echo "Error downloading filemaker. Will needed to delete ~/fminstall before retrying"
      exit 9
    fi
    touch $STATE/filemaker-downloaded
  else
    echo "Error creating Filemaker install directory at $HOME_LOCATION/fminstall"
    exit 9
  fi
fi

#Install filemaker
if [ ! -f $STATE/filemaker-installed ]; then
  cd $HOME_LOCATION/fminstall
  # Create the assisted install file.
  rm $ASSISTED_FILE
  echo "[Assisted Install]" >> $ASSISTED_FILE
  echo "License Accepted=1" >> $ASSISTED_FILE
  echo "Deployment Options=0" >> $ASSISTED_FILE
  echo "Admin Console User=$FM_ADMIN_USER" >> $ASSISTED_FILE
  echo "Admin Console Password=$FM_ADMIN_PASSWORD" >> $ASSISTED_FILE
  echo "Admin Console PIN=$FM_ADMIN_PIN" >> $ASSISTED_FILE
  echo "Filter Databases=0" >> $ASSISTED_FILE
  echo "Remove Sample Database=1" >> $ASSISTED_FILE

  sudo FM_ASSISTED_INSTALL=$ASSISTED_FILE apt install ./filemaker-server*.deb -y || { echo "Error installing Filemaker"; exit 9; }
  touch $STATE/filemaker-installed
fi

if [ ! -f $STATE/certbot-installed ]; then
  sudo snap install --classic certbot || { echo "Error installing Certbot"; exit 9; }
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  touch $STATE/certbot-installed
fi


# For this to work:
# You need a DNS host record for $CERTBOT_HOSTNAME_SETUP pointing to the public IP address of this server
# You need port 80 & 443 open

# if [ ! -f $STATE/certbot-cert ]; then
#   sudo certbot certonly --webroot -w "/opt/FileMaker/FileMaker Server/NginxServer/htdocs/httpsRoot" -d $CERTBOT_HOSTNAME_SETUP \
#     --agree-tos -m $CERTBOT_EMAIL || { echo "Error getting certbot certificate. Make sure DNS and firewall is set correctly"; exit 9; }
#   touch $STATE/certbot-cert
# fi

# Partition, format and attached the additional drives.
#

FILEMAKER_UUID=$(blkid -o value -s UUID /dev/nvme0n1p1)
DATABASE_UUID=$(blkid -o value -s UUID /dev/$DRIVE_DATABASESp1)
CONTAINER_UUID=$(blkid -o value -s UUID /dev/$DRIVE_CONTAINERSp1)
BACKUP_UUID=$(blkid -o value -s UUID /dev/$DRIVE_BACKUPSp1)

if [ -z "$FILEMAKER_UUID" ]; then
  ## No UUID, so partition and format the drive
  echo "Lets format the main drive"
else
  echo "Filemaker UUID: $FILEMAKER_UUID"
fi

if [ -z $DATABASE_UUID]; then
  ## No UUID, so partition and format the drive
  echo "Lets format the database drive"
else
  echo "Database UUID: $DATABASE_UUID"
fi

if [ -z $CONTAINER_UUID]; then
  ## No UUID, so partition and format the drive
  echo "Lets format the Container drive"
else
  echo "Database UUID: $CONTAINER_UUID"
fi

if [ -z $BACKUP_UUID]; then
  ## No UUID, so partition and format the drive
  echo "Lets format the Backups drive"
else
  echo "Database UUID: $BACKUP_UUID"
fi
