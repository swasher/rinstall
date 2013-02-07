#!/bin/sh

#### SETUP SECTION  ####

#user and password for rtorrent process
USER=rtorrent
PASS=pass

#login and password for access rutorrent (user NOT created)
USERWEB=swasher
PASSWEB=swasher

#Choose web server
#WEBSERVER=apache
WEBSERVER=lighttpd

#Корень файлопомойки WITH TAILING SLASH
FILEROOT="/mnt/raid/video/"


#### END SETUP ####


apt-get update -y && apt-get upgrade -y
apt-get install -y subversion php5-cgi screen apache2-utils php5-cli
apt-get install -y rtorrent

useradd $USER -p $PASS

# echo $?
# возвращает код ошибки от useradd

cd /home
mkdir $USER
cd rtorrent
mkdir torrents
mkdir session

wget https://raw.github.com/swasher/rinstall/master/rtorrent.rc -O .rtorrent.rc

chmod 666 .rtorrent.rc
chown -R rtorrent /home/$USER/.rtorrent.rc
chgrp -R rtorrent /home/$USER/.rtorrent.rc



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

lighttpd-enable-mod fastcgi
lighttpd-enable-mod auth
service lighttpd force-reload



#Создаем пароль, который будет спрашиваться при доступе через веб-интерфейс:
# Руками использоваласт команда
# htdigest -c /etc/lighttpd/htdigest "rTorrent RPC" rtorrent
# Скрипт пишет файл напрямую, потому что htdigest спрашивает пароль из терминала
# htdigest так же зависит от apache2-utils

hash=`echo -n "$USERWEB:RPC:$PASSWEB" | md5sum | cut -b -32`
echo "$USERWEB:RPC:$hash" > /etc/lighttpd/htdigest


#Качаем дополнительные скрипты
cd /home/$USER
wget https://raw.github.com/swasher/rinstall/master/creator.sh
chmod 744 creator.sh

##########RUTORRENT################
cd /var/www/
svn checkout http://rutorrent.googlecode.com/svn/trunk/rutorrent

#Редактируем файл конфиг `/var/www/rutorrent/conf/config.php`. 
#Параметр $topdirectory устанавливаем на корень файлохранилища,
#Не забываем о слеше в конце пути.
# Пока ХЗ как сделать

cd /var/www/rutorrent/plugins
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/erasedata
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/datadir
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/tracklabels
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/diskspace
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/_getdir
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/cpuload
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/geoip
svn co http://rutorrent.googlecode.com/svn/trunk/plugins/trafic
chmod 666 /var/www/rutorrent/share/settings

#Для geoip устанавливаем расширение php:
apt-get install -y php5-geoip && /etc/init.d/lighttpd force-reload

chown -R www-data:www-data /var/www/rutorrent

#Ставим "демона"
wget http://libtorrent.rakshasa.no/attachment/wiki/RTorrentCommonTasks/rtorrentInit.sh?format=raw -O /etc/init.d/rtorrent1
sedstring="s/user=\"user\"/user=\"$USER\"/"
cat /etc/init.d/rtorrent1 | sed $sedstring > /etc/init.d/rtorrent
rm /etc/init.d/rtorrent1

chmod +x /etc/init.d/rtorrent
update-rc.d rtorrent defaults

#Стартуем, помолясь
/etc/init.d/rtorrent start
