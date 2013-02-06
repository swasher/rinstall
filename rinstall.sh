#!/bin/sh

#### SETUP SECTION  ####

#user and password for rtorrent process
USER = rtorrent
PASS = pass

#login and password for access rutorrent (user NOT created)
USERWEB = swasher
PASSWEB = swasher


#### END SETUP ####


apt-get update -y && apt-get upgrade -y
apt-get install -y subversion php5-cgi screen apache2-utils php5-cli
apt-get install -y rtorrent

useradd $USER -p $PASS

# echo $?
# возвращает код ошибки от useradd

cd /home
mkdir rtorrent
cd rtorrent
mkdir torrents
mkdir session

chown -R rtorrent /home/rtorrent/
chgrp -R rtorrent /home/rtorrent/

