#!/bin/sh
# Author: sam2kb

ROOT_ALIAS='sam2kb@gmail.com'
CENTOS_VERSION='6' # Версия RedHat ( 5 или 6 )

ZONEINFO='America/New_York'
SET_TIMEZONE=y
UPDATE_PACKAGES=y
ADD_REPOS=y
ALTER_KERNEL_PARAMS=y
SECURE_TMP=y
SECURE_SHM=y
SECURE_SSHD=y
SSHD_PORT=60022
SSHD_USERS='root'

# IP адреса, которые будут игнорироваться в CSF firewall
CSF_IGNORE='
188.72.80.205 # Sape.ru
188.72.80.201 # Sape.ru';

# IP адреса, c которых разрешено подключаться к Virtualmin и Webmin
WEBMIN_ALLOW='' # разделять пробелом
WEBMIN_PORT=11001

INSTALL_WEBMIN=y
INSTALL_CPANMIN=y
INSTALL_CSF=y
INSTALL_NTP=y	# NTP
INSTALL_PMNV=y	# PHP, MYSQL, NGINX, VIRTUALMIN
INSTALL_PMA=y	# phpMyAdmin
PMA_VERSION='3.5.3'

# Конец настроек, ниже можно ничего не менять +++++++++++++++++++
# Запуск скрипта: sh /server-init.sh
#
###############################################################
SCRIPT_NAME='Initial server setup script'
DIR_TMP="/server-init"			# Рабочая директория для временных файлов скрипта
KEYPRESS_PARAM='-s -n1 -p'		# Read a keypress without hitting ENTER
								# -s means do not echo input
								# -n means accept only N characters of input
								# -p means echo the following prompt before reading input
ASKCMD="read $KEYPRESS_PARAM "
CUR_DIR=`pwd`					# Get current directory
MACHINE_TYPE=`uname -m`			# Used to detect if OS is 64bit or not
if [ "${MACHINE_TYPE}" == 'i686' ]; then
	MACHINE_TYPE='i386'
fi
###############################################################
# FUNCTIONS

ASK () {
	keystroke=''
	while [[ "$keystroke" != [yYnNaA] ]]; do
		$ASKCMD "$1" keystroke
		echo "$keystroke";
	done
	key=$(echo $keystroke)
}

# Setup colors
black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'

boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
green='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'

reset="tput sgr0"      #  Reset text attributes to normal without clearing screen

cecho ()	# Colored-echo.
			# $1 = message
			# $2 = color
			# if $3 not set, print stars
{
	message=$1
	color=$2

	if [[ $3 == '' ]]; then
		echo " ";
		echo -e "$color********************************************************"; $reset;
	fi
	echo -e "$color* $message" ; $reset

	if [[ $3 == '' ]]; then
		echo -e "$color********************************************************"; $reset;
		echo " ";
	fi
	sleep 0.3 # sleep for two seconds
	return
}

run_the_script ()
{
	# Если это OpenVZ - создаем пользователя и группу c ID 500 для предотвращения проблем в будущем
	if [ -f /proc/user_beancounters ]; then
		groupadd 500
		useradd -g 500 -s /sbin/nologin -M 500
	fi

	if [ "${ROOT_ALIAS}" != '' ]; then
		cecho "Adding root alias" $green
		sed -i 's/#root:\s*marc/root:\t\t'"${ROOT_ALIAS}"'/g' /etc/aliases
		newaliases
	fi

	if [[ "$UPDATE_PACKAGES" = [yY] ]]; then
		cecho "Updating packages" $green
		yum clean all
		yum -y update glibc\*
		yum -y update yum\* rpm\* python\*
		yum clean all
		yum -y update
	fi

	if [[ "$ADD_REPOS" = [yY] ]]; then
		cecho "* Adding repositories" $green
		yum install -y wget rpm

		if [ "${CENTOS_VERSION}" == '5' ]; then
			wget -c http://dl.iuscommunity.org/pub/ius/stable/Redhat/5/${MACHINE_TYPE}/ius-release-1.0-10.ius.el5.noarch.rpm --tries=3
			wget -c http://dl.iuscommunity.org/pub/ius/stable/Redhat/5/${MACHINE_TYPE}/epel-release-5-4.noarch.rpm --tries=3
			wget -c http://nginx.org/packages/centos/5/noarch/RPMS/nginx-release-centos-5-0.el5.ngx.noarch.rpm --tries=3
		else
			wget -c http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/${MACHINE_TYPE}/ius-release-1.0-10.ius.el6.noarch.rpm --tries=3
			wget -c http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/${MACHINE_TYPE}/epel-release-6-5.noarch.rpm --tries=3
			wget -c http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm --tries=3
		fi

		rpm -ivh epel-release-*
		rpm -ivh ius-release-*
		rpm -ivh nginx-release-centos-*

		yum -y update epel-release ius-release nginx-release-centos
	fi

	if [[ "$UPDATE_PACKAGES" = [yY] ]]; then
		cecho "Updating packages (new repos)..." $green
		yum clean all
		yum -y update
	fi

	cecho "Installing Development Tools" $green
	yum -y install wget perl perl-CPAN perl-devel perl-YAML perl-Time-HiRes perl-DBD-MySQL perl-libwww-perl perl-Net-SSLeay python gcc make automake autoconf patch mlocate libtool nano rsync sysstat lsof curl xterm dbus-x11 libXt-devel unzip zip zlib bzip2 openssh* file e2fsprogs iptables* libjpeg libpng freetype pam-devel

	if [[ "$ALTER_KERNEL_PARAMS" = [yY] ]]; then
		cecho "Altering kernel params" $green
		echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout;
		echo 3000 > /proc/sys/net/core/netdev_max_backlog;
		echo 3000 > /proc/sys/net/core/somaxconn;
		echo 10 > /proc/sys/net/ipv4/tcp_keepalive_intvl;
		echo 2 > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo 300000 > /proc/sys/fs/file-max;

		cat >> /etc/security/limits.conf <<EOF

*               soft    nofile          20000
*               hard    nofile          150000
EOF
	fi

	if [[ "$SECURE_SSHD" = [yY] ]]; then
		cecho "Securing SSHD" $green
		cat >> /etc/ssh/sshd_config <<EOF

UseDNS no
Port $SSHD_PORT
Protocol 2
AllowUsers $SSHD_USERS
EOF
	fi

	if [[ "$SECURE_TMP" = [yY] ]]; then
		cecho "Secured /tmp and /var/tmp" $green
		rm -rf /tmp; mkdir /tmp;
		mount -t tmpfs -o rw,noexec,nosuid tmpfs /tmp
		chmod 1777 /tmp
		echo "tmpfs                   /tmp                    tmpfs   rw,noexec,nosuid     0 0" >> /etc/fstab
		rm -rf /var/tmp; ln -s /tmp /var/tmp
	fi

	if [[ "$SECURE_SHM" = [yY] ]]; then
		cecho "Secured /dev/shm" $green
		umount /dev/shm; rm -rf /dev/shm; mkdir /dev/shm
		mount -t tmpfs -o rw,noexec,nosuid tmpfs /dev/shm
		chmod 1777 /dev/shm;
		echo "tmpfs                   /dev/shm                tmpfs   rw,noexec,nosuid     0 0" >> /etc/fstab
	fi

	if [[ "$SET_TIMEZONE" = [yY] ]]; then
		cecho "Setting preferred timezone" $green
		rm -f /etc/localtime
		ln -s /usr/share/zoneinfo/$ZONEINFO /etc/localtime
		cecho "Current date & time for the zone you selected is: " $green "-"
		date
	fi

	if [[ "$INSTALL_PMNV" = [yY] ]]; then
		cecho "Removing old mysql package" $green
		service mysqld stop
		rpm -e --nodeps mysql-libs

		cecho "Installing MYSQL" $green
		yum -y install mysql55-server mysql55-devel mysql55-libs mysqlclient16

		cecho "Installing PHP" $green
		yum -y install php54 php54-bcmath php54-cli php54-common php54-devel php54-fpm php54-gd php54-imap php54-ioncube-loader php54-mbstring php54-mcrypt php54-mysql php54-pear php54-pecl-geoip php54-pecl-apc php54-process php54-xml php54-xmlrpc

		cecho "Installing NGINX" $green
		yum -y install nginx
	fi


	if [[ "$INSTALL_CPANMIN" = [yY] ]]; then
		# Устанавливаем и обновляем cpanmin
		curl -L http://cpanmin.us | perl - --self-upgrade

		# Устанавливаем системные модули
		cpanm Authen::Libwrap Authen::PAM Time:HiRes IO::Pty Getopt::Long Digest::SHA1 Net::SSLeay
	fi


	if [[ "$INSTALL_WEBMIN" = [yY] ]]; then
		cecho "Installing Webmin" $green
			wget -c http://www.webmin.com/download/rpm/webmin-current.rpm --tries=3
			rpm -ivh webmin-*

			sed -i "s/port=10000/port=$WEBMIN_PORT/g" /etc/webmin/miniserv.conf
			sed -i "s/listen=10000/listen=$WEBMIN_PORT/g" /etc/webmin/miniserv.conf
			sed -i "s/ssl=0/ssl=1/g" /etc/webmin/miniserv.conf

			if [ "${WEBMIN_ALLOW}" != '' ]; then
				cat >> /etc/webmin/miniserv.conf<<EOF
allow=$WEBMIN_ALLOW
EOF
			fi
			service webmin restart
	fi


	if [[ "$INSTALL_PMNV" = [yY] ]]; then
		cecho "Installing Virtualmin" $green
		cd /usr/local/src
		wget -c http://software.virtualmin.com/gpl/scripts/install.sh --tries=3

		# Пропускаем уже установленные пакеты PHP и MySQL
		sed -i 's/mysql mysql-server mysql-devel //g' /usr/local/src/install.sh
		sed -i 's/php php-xml php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc php-mbstring //g' /usr/local/src/install.sh

		# Virtualmin требует чтобы /tmp директория была c атрибутами exec
		# Временно разрешаем...
		mount -o remount,exec /tmp
		sh install.sh
		mount -o remount /tmp

		# Выключение бесполезных сервисов
		service mailman stop; chkconfig mailman off
		service usermin stop; chkconfig usermin off

		cecho "Setting up Postfix" $green
		mkdir /etc/postfix/ssl
		POSTFIX_SSL='/etc/postfix/ssl'

		# Генерируем SSL сертификат для Postfix
		openssl genrsa -des3 -rand /etc/hosts -out $POSTFIX_SSL/smtpd.key 1024
		chmod 600 $POSTFIX_SSL/smtpd.key
		openssl req -new -key $POSTFIX_SSL/smtpd.key -out $POSTFIX_SSL/smtpd.csr
		openssl x509 -req -days 3650 -in $POSTFIX_SSL/smtpd.csr -signkey $POSTFIX_SSL/smtpd.key -out $POSTFIX_SSL/smtpd.crt
		openssl rsa -in $POSTFIX_SSL/smtpd.key -out $POSTFIX_SSL/smtpd.key.unencrypted
		mv -f $POSTFIX_SSL/smtpd.key.unencrypted $POSTFIX_SSL/smtpd.key
		openssl req -new -x509 -extensions v3_ca -keyout $POSTFIX_SSL/cakey.pem -out $POSTFIX_SSL/cacert.pem -days 3650

		# TODO: postfix config, dovecot config

		# Исправляем путь к saslauthd
		mkdir -p /var/spool/postfix/var/run/saslauthd
		chown postfix.root -R /var/spool/postfix/var/
		sed -i 's~SOCKETDIR=.*$~SOCKETDIR=/var/spool/postfix/var/run/saslauthd~g' /etc/sysconfig/saslauthd
		service saslauthd restart

		# Копируем созданный для postfix сертификат в nginx
		cecho "Setting up nginx" $green
		mkdir -p /var/nginx/temp; mkdir /etc/nginx/ssl
		cp /etc/postfix/ssl/smtpd.crt /etc/nginx/ssl/server.crt
		cp /etc/postfix/ssl/smtpd.key /etc/nginx/ssl/server.key


		if [[ "$INSTALL_PMA" = [yY] ]]; then
			cecho "Installing phpMyAdmin" $green
			mkdir /home/www;
			wget -c http://downloads.sourceforge.net/project/phpmyadmin/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-english.zip --tries=3
			unzip phpMyAdmin-${PMA_VERSION}-english.zip;
			mv phpMyAdmin-${PMA_VERSION}-english /home/www/pma
			rm -rf /home/www/pma/setup

			# Создаем blowfish secret
			BLOWFISH=`tr -dc A-Za-z0-9_ < /dev/urandom | head -c 30`
			cat >/home/www/pma/config.inc.php<<EOF
<?php

\$cfg['blowfish_secret'] = '$BLOWFISH';

?>
EOF
			chown apache.apache -R /home/www/pma;
		fi

		cecho "Setting up installed services" $green
		service proftpd stop; chkconfig proftpd off
		service httpd stop; chkconfig httpd off

		service nginx start; chkconfig nginx on
		service mysqld start; chkconfig mysqld on
		service php-fpm start; chkconfig php-fpm on
	fi


	if [[ "$INSTALL_CSF" = [yY] ]]; then
		cecho "Installing CSF firewall" $green
		wget -c http://www.configserver.com/free/csf.tgz --tries=3

		tar zxf csf.tgz -C $DIR_TMP/; cd $DIR_TMP/csf
		sh install.sh
		cd $DIR_TMP

		# Создаем лог файл
		touch /var/log/lfd.log

		cecho "Testing IP Tables Modules" $green
		perl /etc/csf/csftest.pl

		CCONF='/etc/csf/csf.conf'

		cecho "Configuring CSF, step 1" $green
		sed -i 's/TESTING_INTERVAL = "[^"]*"/TESTING_INTERVAL = "10"/g' $CCONF
		sed -i 's/AUTO_UPDATES = "0"/AUTO_UPDATES = "1"/g' $CCONF
		sed -i 's/ICMP_OUT_RATE = "[^"]*"/ICMP_OUT_RATE = "2\/s"/g' $CCONF
		sed -i 's/DENY_IP_LIMIT = "[^"]*"/DENY_IP_LIMIT = "200"/g' $CCONF
		sed -i 's/PS_EMAIL_ALERT = "1"/PS_EMAIL_ALERT = "0"/g' $CCONF
		sed -i 's/DROP_NOLOG = "[^"]*"/DROP_NOLOG = "21,22,67,68,82,111,113,135:139,445,513,520,1433,3306"/g' $CCONF
		sed -i 's/SAFECHAINUPDATE = "0"/SAFECHAINUPDATE = "1"/g' $CCONF

		cecho "Configuring CSF, step 2" $green
		if [ ! -f /proc/user_beancounters ]; then
			# Flood protection. Недоступна в OpenVZ из-за отсутствия необходимых модулей iptables
			sed -i 's/SYNFLOOD = "0"/SYNFLOOD = "1"/g' $CCONF
			sed -i 's/SYNFLOOD_RATE = "[^"]*\/s"/SYNFLOOD_RATE = "100\/s"/g' $CCONF
			sed -i 's/SYNFLOOD_BURST = "[^"]*"/SYNFLOOD_BURST = "150"/g' $CCONF
		fi

		sed -i 's/TCP_IN = "[^"]*"/TCP_IN = "25,53,80,143,443,465,587,993,995,'"${WEBMIN_PORT}"','"${SSHD_PORT}"'"/g' $CCONF
		sed -i 's/LF_DSHIELD = "0"/LF_DSHIELD = "86400"/g' $CCONF
		sed -i 's/LF_SPAMHAUS = "0"/LF_SPAMHAUS = "86400"/g' $CCONF
		sed -i 's/LF_DIRWATCH = "[^"]*"/LF_DIRWATCH = "0"/g' $CCONF
		sed -i 's/LF_INTEGRITY = "[^"]*"/LF_INTEGRITY = "0"/g' $CCONF
		sed -i 's/LF_DISTATTACK = "0"/LF_DISTATTACK = "1"/g' $CCONF
		sed -i 's/LF_DISTATTACK_UNIQ = "[^"]*"/LF_DISTATTACK_UNIQ = "3"/g' $CCONF

		cecho "Configuring CSF, step 3" $green
		sed -i 's/LF_NETBLOCK = "0"/LF_NETBLOCK = "1"/g' $CCONF
		sed -i 's/LF_NETBLOCK_COUNT = "[^"]*"/LF_NETBLOCK_COUNT = "6"/g' $CCONF
		sed -i 's/LF_SSHD = "[^"]*"/LF_SSHD = "2"/g' $CCONF
		sed -i 's/LF_FTPD = "[^"]*"/LF_FTPD = "3"/g' $CCONF
		sed -i 's/LF_SMTPAUTH = "[^"]*"/LF_SMTPAUTH = "3"/g' $CCONF
		sed -i 's/LF_POP3D = "[^"]*"/LF_POP3D = "3"/g' $CCONF
		sed -i 's/LF_IMAPD = "[^"]*"/LF_IMAPD = "3"/g' $CCONF

		cd $DIR_TMP

		cecho "Adding Applications/Users to CSF ignore list" $green

		cat >>/etc/csf/csf.pignore<<EOF

exe:/usr/libexec/mysqld
exe:/usr/sbin/php-fpm
exe:/usr/sbin/nginx
user:postfix
user:dovecot
user:dovenull
user:haldaemon
EOF

		cat >>/etc/csf/csf.ignore<<EOF

74.125.0.0/16 # Google
77.88.0.0/18 # Yandex
$CSF_IGNORE
EOF

		cat >>/etc/csf/csf.rignore<<EOF

.googlebot.com
.google.com
.1e100.net
.yahoo.net
.msn.com
.mail.ru
.yandex.ru
EOF

		chkconfig --levels 235 csf on
		service csf restart

		if [[ "$INSTALL_WEBMIN" = [yY] ]]; then
			cecho "Installing Webmin CSF module" $green
			perl /usr/libexec/webmin/install-module.pl /etc/csf/csfwebmin.tgz
		fi
	fi


	if [ -f /proc/user_beancounters ]; then
		cecho "OpenVZ system detected, NTP not installed" $green
	else
		if [[ "$INSTALL_NTP" = [yY] ]]; then
			cecho "Installing NTP (and syncing time)" $green
			yum -y install ntp
			chkconfig --levels 235 ntpd on
			ntpdate pool.ntp.org
			cecho "The date/time is now:" $green
			date
			cecho "If this is correct, then everything is working properly" $green

			service ntpd restart
		fi
	fi

	# Последний update на всякий случай
	yum -y update

}

################################################################
# SCRIPT START
#
clear

cecho "********************************************************" $boldyellow "-"
cecho "$SCRIPT_NAME" $green "-"
cecho "********************************************************" $boldyellow "-"
echo " "
ASK "Would you like to continue? [y/n] "
if [[ "$key" = [nN] ]]; then
    exit 0
fi

if [ -d "$DIR_TMP" ]; then
	ASK "It seems that you have run this script before. Do you want to exit? [y/n]"
	if [[ "$key" = [yY] ]]; then
		cecho "Installation aborted " $green
		exit
	fi
else
	mkdir $DIR_TMP; cd $DIR_TMP
	run_the_script
fi

cd $DIR_TMP


cecho "**********************************************************************" $green "-"
cecho "* Installation complete, congratulations!" $green "-"
cecho "* Enjoy CentOS!" $green "-"
cecho "**********************************************************************" $green "-"

cecho "Temporary files/folders removed" $green
	cd; rm -rf $DIR_TMP

cecho "Running updatedb command. Please wait..." $green
	updatedb

cecho "Deleting $SCRIPT_NAME" $green
	rm -f $0

cecho "Disabling services" $green
	if [ "${CENTOS_VERSION}" == '5' ]; then
		# Добавьте сервисы для отключения
		chkconfig xfs off; service xfs stop
		chkconfig atd off; service atd stop
		chkconfig nfslock off; service nfslock stop
		chkconfig rpcidmapd off; service rpcidmapd stop
		chkconfig anacron off; service anacron stop
		chkconfig avahi-daemon off; service avahi-daemon stop
		chkconfig hidd off; service hidd stop
		chkconfig pcscd off; service pcscd stop
	else
		# Добавьте сервисы для отключения
		chkconfig avahi-daemon off; service avahi-daemon stop
	fi

if [[ "$SECURE_SSHD" = [yY] ]]; then
	service sshd restart
fi

cecho "All done! It's recommended to reboot the server now." $green
exit;