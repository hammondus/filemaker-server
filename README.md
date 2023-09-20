# Filemaker Server Install

## Purpose

The purpose of these collection of scripts is so that I can sort of automate the setting up of new
filemaker servers on AWS EC2 instances. I do this as I prefer to create a new server with the latest
version of filemaker rather than do inplace upgrades of my existing server.

It's not meant to be a robust installer that covers all situations. Just to cover mine.
I make it public in case someone else can use it or benefit from it, but it's primarily
for my internal use.

Having said that, I welcome any input and hope someone may find it useful

Craig..

## Description

A somewhat automated installation of filemaker server on Ubuntu 22.04

Filemaker server upgrades have historically had mixed success.
They have all personally worked fine for me, but a quick search will show plenty of people having dramas.

As AWS makes it so cheap and easy to setup a new server that matches the existing one hardware wise,
this installation process makes it quick to setup a seperate new server with the latest version of
Filemaker. Once the new server has been setup, it only takes a few minutes to do the following to
get it up and running with production data.

-   Shutdown both the old and new server
-   detach the data drives from the old and attach to the new server
-   reassign the Elastic static IP from the old server to the new
-   Run the final part of the install that create a new SSL cert for the production host name.

### Assumptions

This install makes a few assumptions

-   The server is a fresh install of the Ubuntu 22.04
-   It's going to be dedicated to running Filemaker.
-   It's designed for and tested on an AWS EC2 instances.
    -   The default AWS user of ubuntu is used.
    -   AWS network security settings have ports 22, 80, 443 & 5003 open
-   It uses a SSL certificate from Let's Encrypt
-   It uses 4 seperate drives.

1. OS & Filemaker software
2. Databases
3. Containers
4. Backups

The following filemaker default file locations are changed so that the data is stored on its own drive
`/opt/FileMaker/FileMaker Server/Data/Databases             --> /opt/FileMaker/Data/Databases`
`/opt/FileMaker/FileMaker Server/Data/Databases/RC_Data_FMS --> /opt/FileMaker/Data/Containers`
`/opt/FileMaker/FileMaker Server/Data/Backups               --> /opt/FileMaker/Backups`

## Installing these scripts

After the AWS instance has been created, from the home directory of the default user ubuntu

```bash
git clone https://github.com/hammondus/filemaker-server.git
$ cd filemaker-server
```

edit fm_install.sh
The various settings required to run the installation are commented out in install.sh
Uncomment these out and put in the settings to suit. Then:

```bash
$ ./fm_install.sh
```

The script copies itself to /home/ubuntu/. As it has to be run a few times due to reboots, it
can just be run from ~./fm_install.sh
