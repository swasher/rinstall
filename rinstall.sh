#!/bin/bash

#### SETUP SECTION  ####

#user and password for rtorrent process
USER=rtorrent
PASS=pass

#login and password for access rutorrent (user NOT created)
USERWEB=rtorrent
PASSWEB=bingo
REALMWEB="rTorrent RPC"

#Choose web server
#WEBSERVER=apache
WEBSERVER=lighttpd

#Корень файлопомойки WITH TRAILING SLASH
FILEROOT="/mnt/raid/"

# stable|advanced
XMLRPCVERSION=stable

#rtorrent version 0.9.2|0.9.3
#libtorrent version will choose on depending
RTORRENTVERSION=0.9.3

#### END SETUP ####

SETUPDIR=$(pwd)

function clean_system
{
echo Cleaning system
apt-get purge -y lighttpd
apt-get purge -y rtorrent  libxmlrpc-c3 libxmlrpc-c3-dev libxmlrpc-core-c3 libxmlrpc-core-c3-dev
apt-get purge -y libtorrent11

rm -r /etc/lighttpd/
rm -r /var/www/rutorrent/
rm -r /etc/init.d/rtorrent
rm -r /var/run/S-$USER

userdel rtorrent
rm -r /home/rtorrent/

dpkg -r xmlrpc
dpkg -r libtorrent
dpkg -r rtorrent

exit 0
}


[[ $1 == 'clean' ]] && clean_system || echo "It is assumed that the system is clean"



function checkresult
{
if [ $? -gt 0 ]; then
  echo *** ERROR ***
  exit 1
fi
}


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ "$RTORRENTVERSION" != "0.9.3" ] && [ "$RTORRENTVERSION" != "0.9.2" ]; then
  echo "$RTORRENTVERSION version is not 0.9.3 or 0.9.2!"
  exit 1
fi

if [ $RTORRENTVERSION == "0.9.3" ]; then
  LIBTORRENTVERSION="0.13.3"
fi

if [ $RTORRENTVERSION == "0.9.2" ]; then
  LIBTORRENTVERSION="0.13.2"
fi


#apt-get update -y && apt-get upgrade -y
apt-get purge -y rtorrent  libxmlrpc-c3 libxmlrpc-c3-dev libxmlrpc-core-c3 libxmlrpc-core-c3-dev
apt-get purge -y libtorrent11

sudo apt-get install -y screen subversion \
g++ make automake pkg-config autoconf autotools-dev checkinstall \
php5  php5-cgi php5-cli php5-geoip \
apache2-utils curl \
libtool libcurl4-openssl-dev libsigc++-2.0-dev libncurses5-dev libcppunit-dev libxml2-dev


useradd -c "Torrent User" -d /home/$USER -m -s /bin/bash $USER
echo $USER:$PASS | chpasswd

cd /home/$USER
mkdir torrents session

wget https://raw.github.com/swasher/rinstall/master/rtorrent.rc -O .rtorrent.rc

chmod 666 .rtorrent.rc
chown -R rtorrent:rtorrent /home/$USER/


############ xmlrpc
cd $SETUPDIR
svn co https://xmlrpc-c.svn.sourceforge.net/svnroot/xmlrpc-c/$XMLRPCVERSION xmlrpc-c
cd xmlrpc-c
./configure --prefix=/usr \
  --enable-libxml2-backend \
  --disable-libwww-client \
  --disable-wininet-client \
  --disable-abyss-server \
  --disable-cgi-server
make
checkinstall -D --pkgversion=1 -y

echo "Pause 10 sec. XMLRPC install ok?"
sleep 10
#read -p "Press [Enter]"


############# libtorrent
cd $SETUPDIR
curl http://libtorrent.rakshasa.no/downloads/libtorrent-$LIBTORRENTVERSION.tar.gz | tar xz
cd libtorrent-$LIBTORRENTVERSION
./autogen.sh
./configure --prefix=/usr --disable-debug --with-posix-fallocate
make -j2
sudo checkinstall -D -y

echo "Pause 10 sec. Libtorrent install ok?"
sleep 10
#read -p "Press [Enter]"


############## rtorrent
cd $SETUPDIR
curl http://libtorrent.rakshasa.no/downloads/rtorrent-$RTORRENTVERSION.tar.gz | tar xz
cd rtorrent-$RTORRENTVERSION
./autogen.sh
./configure --prefix=/usr --with-xmlrpc-c
make -j2
checkinstall -D -y

echo "Pause 10 sec. Rtorrent install ok?"
sleep 10
#read -p "Press [Enter]"

ldconfig

#############################################
# WEBSERVER

function lighttpd_install
{
apt-get install -y lighttpd
cat >> /etc/lighttpd/conf-available/10-fastcgi.conf <<End-of-fastcgi
fastcgi.server = ( ".php" =>
    ((
	"bin-path" => "/usr/bin/php5-cgi",
	"socket" => "/tmp/php.socket",
	"max-procs" => 2,
	"idle-timeout" => 20,
	"bin-environment" => (
	"PHP_FCGI_CHILDREN" => "1",
	"PHP_FCGI_MAX_REQUESTS" => "10000"
	),
	"bin-copy-environment" => (
	"PATH", "SHELL", "USER"
         ),
	"broken-scriptfilename" => "enable"
     ))
)
End-of-fastcgi

cat >> /etc/lighttpd/conf-available/10-scgi.conf <<End-of-scgi
server.modules += ( "mod_scgi" )

scgi.server = (
                "/RPC2" =>
                  ( "127.0.0.1" =>
                    (
                      "host" => "127.0.0.1",
                      "port" => 5000,
                      "check-local" => "disable",
                      "disable-time" => 0,
                    )
                  )
              )
End-of-scgi

cat >> /etc/lighttpd/conf-available/05-auth.conf <<End-of-auth
auth.backend                   = "htdigest"
auth.backend.htdigest.userfile = "/etc/lighttpd/htdigest"
auth.require = ( "/RPC2" =>
    (
        "method" => "digest",
        "realm" => "rTorrent RPC",
        "require" => "user=rtorrent"
        )
)
End-of-auth

#################################################################################
#################################################################################
# В модуле auth заменить юзера rtorrent на переменную
#################################################################################
#################################################################################

# Создаем пароль, который будет спрашиваться при доступе через веб-интерфейс:
# Руками использоваласт команда
# htdigest -c /etc/lighttpd/htdigest "rTorrent RPC" rtorrent
# Скрипт пишет файл напрямую, потому что htdigest спрашивает пароль из терминала
# htdigest так же зависит от apache2-utils


hash=`echo -n "$USERWEB:$REALMWEB:$PASSWEB" | md5sum | cut -b -32`
echo "$USERWEB:$REALMWEB:$hash" > /etc/lighttpd/htdigest

echo ${USERWEB}:${REALMWEB}:$(printf "${USERWEB}:${REALMWEB}:${PASSWEB}" | md5sum - | sed -e 's/\s\+-//') >>  /etc/lighttpd/htdigest


chmod 644 /etc/lighttpd/htdigest


lighttpd-enable-mod fastcgi
lighttpd-enable-mod scgi
lighttpd-enable-mod auth
service lighttpd force-reload
}

function apache_install
{
apt-get install -y apache2
}

if [ $WEBSERVER = lighttpd ]; then
   lighttpd_install
fi

if [ $WEBSERVER = apache ]; then
   apache_install
fi


#Качаем дополнительные скрипты
cd /home/$USER
wget https://raw.github.com/swasher/rinstall/master/creator.sh
chmod 744 creator.sh

wget https://raw.github.com/swasher/rinstall/master/remove_mjbignore.sh
chmod 744 remove_mjbignore.sh


##########RUTORRENT################
cd /var/www/
svn checkout http://rutorrent.googlecode.com/svn/trunk/rutorrent

#Нужно отредактировать конфиг `/var/www/rutorrent/conf/config.php`. 
#Параметр $topdirectory устанавить на корень файлохранилища (слеше в конце пути)
#
# как-то так, но непонятно как экранировать слеши в переменной fileroot
# perl -pi -e "s/\$topDirectory \= '\/'/\$topDirectory $FILEROOT/g" /var/www/rutorrent/conf/config.php

cd /var/www/rutorrent/plugins
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/erasedata
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/datadir
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/tracklabels
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/diskspace
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/_getdir
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/cpuload
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/geoip
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/trafic
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/check_port
chmod 666 /var/www/rutorrent/share/settings

#Для geoip устанавливаем расширение php:
apt-get install -y php5-geoip
/etc/init.d/lighttpd force-reload

chown -R www-data:www-data /var/www/rutorrent

cd /var/www/rutorrent
find share/ -type d -exec chmod 777 {} \;
find share/ -type f -exec chmod 666 {} \;

#Install "daemon"
#There is two version from Rakshasa - sh ("Highly Compatible, fewer features") and bash ("More features, may not work on some systems")
#Choose one.
#wget http://libtorrent.rakshasa.no/attachment/wiki/RTorrentCommonTasks/rtorrentInit.sh?format=raw -O /etc/init.d/rtorrent
wget http://libtorrent.rakshasa.no/attachment/wiki/RTorrentCommonTasks/rtorrentInit.bash?format=raw -O /etc/init.d/rtorrent
perl -pi -e "s/user=\"user\"/user=\"rtorrent\"/g" /etc/init.d/rtorrent

chmod +x /etc/init.d/rtorrent
update-rc.d rtorrent defaults

#Стартуем, помолясь
/etc/init.d/rtorrent start
