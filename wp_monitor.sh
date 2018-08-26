#!/bin/bash

check_mysql() {

status=`dpkg -l | grep -i mysql-server | wc -l`


if [ $status -eq 0 ]
then
	echo "Mysql not installed"
	echo "Installing MySQL"
	echo "mysql-server-5.6 mysql-server/root_password password root" | sudo debconf-set-selections
	echo "mysql-server-5.6 mysql-server/root_password_again password root" | sudo debconf-set-selections
	sudo apt-get -y install mysql-server-5.6
	mysql -uroot -proot -e 'USE mysql; UPDATE `user` SET `Host`="%" WHERE `User`="root" AND `Host`="localhost"; DELETE FROM `user` WHERE `Host` != "%" AND `User`="root"; FLUSH PRIVILEGES; CREATE DATABASE WP_DB;'
	sudo /etc/init.d/mysql restart
else
	running=`ps -ef | grep mysqld | wc -l`

	if [ $running -eq 1 ]
	then
		echo "MySQL is installed and not running"
		echo "Starting MySQL"
		sudo /etc/init.d/mysql start
	else
		echo "Mysql is running"
	fi
fi

}

check_apache() {
status=`dpkg -l | grep -i apache | wc -l`

if [ $status -eq 0 ]
then
	echo "Apache not installed : $status1"
	sudo apt-get install -y  apache2 apache2-utils php5 libapache2-mod-php5 php5-mcrypt php5-mysqlnd-ms
else
	echo "Apache is installed"
	running=`ps -ef | grep apache | wc -l`

	if [ $running -gt 1 ]
	then
		echo "Apache is running"
	else 
		sudo /etc/init.d/apache2 start
		if [ $? -eq 0 ]
		then
			echo "Apache is Started"
		else
			echo "Problems starting apache"
		fi
	fi
fi

}

check_nagios() {

if [ -e /etc/init.d/nagios ]
then
	echo "Nagios is installed"
	running=`ps -ef | grep nagios | wc -l`

	if [ $running -gt 1 ]
	then
		echo "Nagios is running"
	else
		sudo /etc/init.d/nagios restart
		if [ $? -eq 0 ]
		then
			echo "Nagios is running"
		else
			echo "Problems starting Nagios"
		fi
	fi
else
	install_nagios
fi

}

install_nagios() {

	echo "Installing nagios"
        sudo useradd nagios
	sudo groupadd nagcmd
	sudo usermod -a -G nagcmd nagios
	sudo apt-get update
	sudo apt-get install -y  build-essential libgd2-xpm-dev openssl libssl-dev unzip
	curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.3.4.tar.gz
	tar zxf nagios-*.tar.gz
	cd nagios-*
	./configure --with-nagios-group=nagios --with-command-group=nagcmd
	make all
	sudo make install
	sudo make install-commandmode
	sudo make install-init
	sudo make install-config
	sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
	sudo usermod -G nagcmd www-data
	curl -L -O https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-3.2.1/nrpe-3.2.1.tar.gz
	tar zxf nrpe-*.tar.gz
	cd nrpe-*
	./configure
	make check_nrpe
	sudo make install-plugin
	sudo mkdir -p /usr/local/nagios/etc/servers
	cat /usr/local/nagios/etc/nagios.cfg | sed -e 's/\#cfg_dir\=\/usr\/local\/nagios\/etc\/servers/cfg_dir\=\/usr\/local\/nagios\/etc\/servers'g >> /usr/local/nagios/etc/nagios.cfg.$$
	mv /usr/local/nagios/etc/nagios.cfg.$$ /usr/local/nagios/etc/nagios.cfg
	sudo a2enmod rewrite
	sudo a2enmod cgi
	sudo htpasswd -cdb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin
	sudo ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
	sudo apt-get install -y nagios-plugins
	sudo /etc/init.d/apache2 restart
	sudo /etc/init.d/nagios restart

}

install_wp() {

	wget https://wordpress.org/latest.tar.gz
	tar xpf latest.tar.gz

	sudo rm -rf /var/www/html
	sudo cp -r wordpress /var/www/html


	cd /var/www/html 

	sudo cat wp-config-sample.php | sed -e "s/database_name_here/WP_DB/; s/username_here/root/; s/password_here/root/" > /tmp/wp-config.php

	sudo mv /tmp/wp-config.php /var/www/html/.

	sudo /etc/init.d/apache2 restart

}

info() {

	echo "access WordPress : http://localhost/wp-admin/install.php"

	echo "access Nagios : http://localhost/nagios"

	echo "Nagios user : nagiosadmin/nagiosadmin"

	echo "Mysql user : root/root"

	echo "Mysql wordpress DB : WP_DB"

}


	

check_mysql
check_apache
check_nagios
install_wp
clear
info


