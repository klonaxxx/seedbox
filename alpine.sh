#!/bin/bash

#Variables
#########################################################
NAME=
BOOL=true
CHOICE=

RTORRENT_DOWNLOAD_DIR=
RTORRENT_SESSION_DIR=

RUTORRENT_TARBALL=rutorrent-3.6.tar.gz

RUTORRENT_USER=
RUTORRENT_PASS=

WEBSERVER=0
#########################################################

#Functions
#########################################################
#function GREETINGS
#function GET_USERNAME
#function CHECK_ROOT
#function GET_WEBSERVER
#function COMPLETE
#function RTORRENT_CONFIGURE
#function DEPENDENCIES
#function DOWNLOAD_STUFF
#function OPENRC_SERVICE
#function RUTORRENT
#function WEBSERVER_CONFIGURE
#########################################################

#Greetings
#########################################################
function GREETINGS
{
	 echo -e "\n\e[1;36mVersions of components to be installed:\e[0m"
	 echo "-----------------------------------------------------"
	 echo -e "\e[1;32mxmlrpc-c\e[0m - \e[1;31m1.33.18\e[0m"
	 echo -e "\e[1;32mlibtorrent\e[0m - \e[1;31m0.13.6\e[0m"
	 echo -e "\e[1;32mrtorrent\e[0m - \e[1;31m0.9.6\e[0m"
	 echo -e "\e[1;32mrutorrent\e[0m - \e[1;31m3.6\e[0m"
	 echo "-----------------------------------------------------"
	 echo -e "\nScript has been assembled by \e[1mdawidd6\e[0m\n"
}
#########################################################

#Various Shit
#########################################################
function CHECK_ROOT
{
	if [ $(id -u) != 0 ]
	then
	echo "This script must be run as root"
	exit 1
	fi
}

function GET_USERNAME
{
	echo "Please type your system's username (not root): "
	read NAME
	
	if [ $NAME = root ]
	then
	echo "You can't run rtorrent as root for security purposes"
	echo "Please run script again and type a valid username"
	exit 1
	
	elif [ $(printf '%s\n' "${SUDO_USER:-$USER}") = $NAME ]
	then
	echo "Continuing..."
	
	else
	echo "This user does not exist"
	echo "Please run script again and type a valid username"
	exit 1
	
	fi
	sleep 3
}

function GET_WEBSERVER
{
	echo "Please type which webserver would you use ('1' or '2'):"
	echo "1) Apache"
	echo "2) Lighttpd"
	
	until [ $WEBSERVER = 1 ] || [ $WEBSERVER = 2 ]
	do
	read WEBSERVER
	if [ $WEBSERVER != 1 ] && [ $WEBSERVER != 2 ]
	then
	echo "Please type a valid number"
	fi
	done
}
#########################################################

#Dependencies
#########################################################
function DEPENDENCIES
{
	apk update
	
	if [ $WEBSERVER = 1 ]
	then
	apk add apache2 apache2-utils php-apache2
	elif [ $WEBSERVER = 2 ]
	then
	apk add lighttpd lighttpd-mod_auth
	fi
	
	apk add rtorrent libtorrent xmlrpc-c openssl \
	libtool cppunit-dev ncurses-dev ncurses ncurses-libs libssl1.0 \
	php php-cgi php-curl php-cli screen wget libsigc++-dev
}
#########################################################

#Download
#########################################################
function DOWNLOAD_STUFF
{
	cd /tmp
	wget -c http://dl.bintray.com/novik65/generic/$RUTORRENT_TARBALL
	wget -c http://raw.githubusercontent.com/dawidd6/seedbox/master/files/.rtorrent.rc -P /home/$NAME
}
#########################################################

#Rtorrent Configuration
#########################################################
function RTORRENT_CONFIGURE
{
	echo -e "\nDefault directory for downloads is: ~/rtorrent/downloads"
	echo -e "Default directory for session files is: ~/rtorrent/.rtorrent-session\n"
	echo "Do you want to set custom directories for rtorrent? ('yes' or 'no'): "
	read CHOICE
	
	while [ $BOOL = true ]
	do
	
	if [ $CHOICE = yes ]
	then
	echo "Type a directory to where will rtorrent download files: "
	read RTORRENT_DOWNLOAD_DIR
	sed -i -e "s@~/rtorrent/downloads@$RTORRENT_DOWNLOAD_DIR@g" /home/$NAME/.rtorrent.rc
	echo "Type a directory to where will rtorrent save session files: "
	read RTORRENT_SESSION_DIR
	sed -i -e "s@~/rtorrent/.rtorrent-session@$RTORRENT_SESSION_DIR@g" /home/$NAME/.rtorrent.rc
	mkdir -p $RTORRENT_DOWNLOAD_DIR
	mkdir -p $RTORRENT_SESSION_DIR
	chown -R $NAME:$NAME $RTORRENT_DOWNLOAD_DIR
	chown -R $NAME:$NAME $RTORRENT_SESSION_DIR
	BOOL=false
	
	elif [ $CHOICE = no ]
	then
	mkdir -p /home/$NAME/rtorrent/.rtorrent-session
	mkdir -p /home/$NAME/rtorrent/downloads
	chown -R $NAME:$NAME /home/$NAME/rtorrent/.rtorrent-session
	chown -R $NAME:$NAME /home/$NAME/rtorrent/downloads
	echo "Default..."
	BOOL=false
	sleep 3
	
	else
	echo "Type 'yes' or 'no': "
	read CHOICE
	
	fi
	done
	
	chown $NAME:$NAME /home/$NAME/.rtorrent.rc
}
#########################################################

#Service
#########################################################
function OPENRC_SERVICE
{
	cat > "/etc/init.d/rtorrentd" <<-EOF
	#!/sbin/runscript

	depend()
	{
		use net ypbind nis
	}

	start()
	{
		ebegin "Starting rtorrent"
		start-stop-daemon \
		--start \
		--make-pidfile \
		--pidfile /var/run/rtorrentd.pid \
		--background \
		--user $NAME \
		--name rtorrentd \
		--exec /usr/bin/screen -- -D -m -S rtorrentd /usr/bin/rtorrent
		eend $?
	}

	stop()
	{
		ebegin "Stopping rtorrent"
		start-stop-daemon --stop --signal 15 \
		--pidfile /var/run/rtorrentd.pid
		eend $?
	}
	EOF
	
	chmod +x /etc/init.d/rtorrentd
	/etc/init.d/rtorrentd start
	rc-update add rtorrentd default
}
#########################################################

#Rutorrent
#########################################################
function RUTORRENT
{
	echo "Type username for ruTorrent interface: "
	read RUTORRENT_USER
	echo "Type password for ruTorrent interface: "
	read RUTORRENT_PASS
	
	mv /tmp/$RUTORRENT_TARBALL /var/www/localhost/htdocs
	cd /var/www/localhost/htdocs
	tar -zxf $RUTORRENT_TARBALL
	rm $RUTORRENT_TARBALL
}
#########################################################

#Webservers
#########################################################
function WEBSERVER_CONFIGURE
{
	if [ $WEBSERVER = 1 ]
	then
		htpasswd -cb /var/www/localhost/htdocs/rutorrent/.htpasswd $RUTORRENT_USER $RUTORRENT_PASS
		if uname -m|grep -wq x86_64
		then
		cp /home/$NAME/seedbox/files/x86_64/mod_scgi.so /var/www/modules
		elif uname -m|grep -wq x86
		then
		cp /home/$NAME/seedbox/files/x86/mod_scgi.so /var/www/modules
		elif uname -m|grep -q arm
		then
		cp /home/$NAME/seedbox/files/armhf/mod_scgi.so /var/www/modules
		fi
	
		cat >> "/etc/apache2/httpd.conf" <<-EOF
	    	LoadModule scgi_module modules/mod_scgi.so
	    	
	    	SCGIMount /RPC2 127.0.0.1:5000

	    	<Directory "/var/www/localhost/htdocs/rutorrent">
		AuthName "ruTorrent interface"
		AuthType Basic
		Require valid-user
		AuthUserFile /var/www/localhost/htdocs/rutorrent/.htpasswd
	    	</Directory>
		EOF
	
		/etc/init.d/apache2 start
		rc-update add apache2 default
		
	elif [ $WEBSERVER = 2 ]
	then
		printf "$RUTORRENT_USER:$(openssl passwd -crypt $RUTORRENT_PASS)\n" >> /var/www/localhost/htdocs/rutorrent/.htpasswd
	
		sed -i -e 's@#    "mod_auth",@     "mod_auth",@g' /etc/lighttpd/lighttpd.conf
		sed -i -e 's@#    "mod_ssi",@     "mod_scgi",@g' /etc/lighttpd/lighttpd.conf
		sed -i -e 's@#   include "mod_fastcgi.conf"@include "mod_fastcgi.conf"@g' /etc/lighttpd/lighttpd.conf
		sed -i -e "s@;cgi.fix_pathinfo=1@cgi.fix_pathinfo=1@g" /etc/php/php.ini
		cat >> "/etc/lighttpd/lighttpd.conf" <<-EOF
		auth.backend = "htpasswd"
		auth.backend.htpasswd.userfile = "/var/www/localhost/htdocs/rutorrent/.htpasswd"
		auth.require = ( "/rutorrent" =>
	    	(
	    	"method"  => "basic",
	    	"realm"   => "ruTorrent interface",
	    	"require" => "valid-user"
	    	),
		)
		EOF
	
		cat >> "/etc/lighttpd/lighttpd.conf" <<-EOF
		scgi.server = (
		"/RPC2" =>
		( "127.0.0.1" =>
		(                
		"host" => "127.0.0.1",
		"port" => 5000,
		"check-local" => "disable"
	       	)
		)
		)
		EOF
	
		/etc/init.d/lighttpd restart
		rc-update add lighttpd default
	fi
}

#Complete
#########################################################
function COMPLETE
{
	echo -e "\n***INSTALLATION COMPLETED***"
	echo "You should be able after reboot to log in to rutorrent interface at: "
	echo "http://localhost:80/rutorrent"
	echo "with this authentication: "
	echo "-----------------------------------------------------"
	echo $RUTORRENT_USER
	echo $RUTORRENT_PASS
	echo "-----------------------------------------------------"
	echo "XMLRPC-C is working on /RPC2 address"
}
#########################################################

#Main
#########################################################
CHECK_ROOT
GREETINGS
DETECT_OS
GET_USERNAME
GET_WEBSERVER
DEPENDENCIES
DOWNLOAD_STUFF
OPENRC_SERVICE
RUTORRENT
WEBSERVER_CONFIGURE
RTORRENT_CONFIGURE
COMPLETE
#########################################################