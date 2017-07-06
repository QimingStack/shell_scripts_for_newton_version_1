#!/bin/bash

NTPSERVER="192.168.31.6"	# attention: NTPSERVER IP

#######disable_sellinux_firewall
modify_hostname () {
hostnamectl set-hostname controller
}
disable_sellinux_firewall () {
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo "bash ~/scripts-newton/1-environment_controller.sh" >> ~/.bash_profile 	# attention:directory scripts-newton
reboot
}
######Check firewalld SELinux
check_firewall_selinux () {
sed -i 's/bash ~\/scripts-newton\/1-environment_controller.sh//g' ~/.bash_profile
systemctl status firewalld
sestatus	
}
######config NTP(chrony)
config_chrony_server () {
timedatectl set-timezone Asia/Shanghai
sed -i '/^server 0.centos.pool.ntp.org iburst/,/^server 3.centos.pool.ntp.org iburst/s/^/#/g' /etc/chrony.conf 
sed -i "/^#server 3.centos.pool.ntp.org iburst/a\server $NTPSERVER iburst" /etc/chrony.conf  	#attention: $NTPSERVER use ""
sed -i 's/#allow 192.168\/16/allow 192.168.31.0\/24/g'  /etc/chrony.conf		# attention: network segement
sed -i 's/#local stratum 10/local stratum 10/g'  /etc/chrony.conf
systemctl restart chronyd 
systemctl enable chronyd
chronyc sources -v
}
###### Configure DNS(/etc/hosts)
config_hosts() {
	#attention: IP <--> hostname
cat << EOF > hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
# localserver
192.168.3.252	localserver
# controller node
192.168.31.6	controller
# compute node
192.168.31.9		compute
EOF
cp hosts /etc/hosts		#by this way, we won't change the permission of /etc/hosts
rm -rf hosts
ping -c 4 controller
ping -c 4 compute
#ping -c 4 www.baidu.com
}
######configure repo
configure_repo () {
mkdir /etc/yum.repos.d/bak
mv CentOS-*.repo /etc/yum.repos.d/bak
cp /etc/yum.repos.d/bak/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/#baseurl/baseurl/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/mirror.centos.org/localserver/g' /etc/yum.repos.d/CentOS-Base.repo
	
}
###### Install openstack-newton-repo-client
install_newton_client () {
yum install centos-release-openstack-newton -y   # attention:YUM is OK
#/etc/yum.repos.d/CentOS-Ceph-Jewel.repo
sed -i 's/mirror.centos.org/localserver/' /etc/yum.repos.d/CentOS-Ceph-Jewel.repo
sed -i 's/buildlogs.centos.org/localserver/' /etc/yum.repos.d/CentOS-Ceph-Jewel.repo
sed -i 's/debuginfo.centos.org/localserver/' /etc/yum.repos.d/CentOS-Ceph-Jewel.repo
sed -i 's/vault.centos.org/localserver/' /etc/yum.repos.d/CentOS-Ceph-Jewel.repo
#/etc/yum.repos.d/CentOS-QEMU-EV.repo
sed -i 's/mirror.centos.org/localserver/g' /etc/yum.repos.d/CentOS-QEMU-EV.repo
sed -i 's/buildlogs.centos.org/localserver/g' /etc/yum.repos.d/CentOS-QEMU-EV.repo
#/etc/yum.repos.d/CentOS-OpenStack-newton.repo
sed -i 's/mirror.centos.org/localserver/g' /etc/yum.repos.d/CentOS-OpenStack-newton.repo
sed -i 's/buildlogs.centos.org/localserver/g' /etc/yum.repos.d/CentOS-OpenStack-newton.repo
sed -i 's/debuginfo.centos.org/localserver/g' /etc/yum.repos.d/CentOS-OpenStack-newton.repo
sed -i 's/vault.centos.org/localserver/g' /etc/yum.repos.d/CentOS-OpenStack-newton.repo
sed -i 's/buildlogs.centos.org/localserver/g' /etc/yum.repos.d/CentOS-OpenStack-newton.repo
ls /etc/yum.repos.d/
yum install python-openstackclient -y
}
###### Install SQL database
install_mariadb () {
yum install mariadb mariadb-server python2-PyMySQL -y
if [ -f "/etc/my.cnf.d/openstack.cnf" ] ; then
	mv /etc/my.cnf.d/openstack.cnf /etc/my.cnf.d/openstack.cnf.bak
fi
# attention: bind-address IP
cat << EOF > /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = 192.168.31.6

default-storage-engine = innodb 
innodb_file_per_table = on 
max_connections = 4096 
collation-server = utf8_general_ci 
character-set-server = utf8
EOF
systemctl enable mariadb.service 
systemctl start mariadb.service
systemctl status mariadb.service
mysql_secure_installation
}
###### Install MQ
install_rabbitmq () {
yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service 
systemctl start rabbitmq-server.service
systemctl status rabbitmq-server.service
rabbitmqctl add_user openstack devops	# remember the user openstack's RABBIT_PASS devops
rabbitmqctl set_permissions openstack ".*" ".*" ".*" 
}
###### Install memcached
install_memcached () {
yum install memcached python-memcached vim -y
sed -i 's/OPTIONS="-l 127.0.0.1,::1"/OPTIONS="-l 127.0.0.1,::1,controller"/g' /etc/sysconfig/memcached
systemctl enable memcached.service 
systemctl start memcached.service
systemctl status memcached.service
}
echo "Select a operation:"
select opt in modify_hostname disable_sellinux_firewall check_firewall_selinux config_chrony_server config_hosts configure_repo install_newton_client install_mariadb install_rabbitmq install_memcached "Exit"
do 
	case $opt in
	modify_hostname)
		modify_hostname ;;
	disable_sellinux_firewall)
		disable_sellinux_firewall;;
	check_firewall_selinux)
		check_firewall_selinux ;;
	config_chrony_server)
		config_chrony_server ;; 
	config_hosts)
		config_hosts ;;
	configure_repo)
		configure_repo;;
	install_newton_client)
		install_newton_client ;;
	install_mariadb)
		install_mariadb ;;
	install_rabbitmq)
		install_rabbitmq ;;
	install_memcached)
		install_memcached ;;
	"Exit")
		exit 0;;
	*)
		echo "Please select a number between 1 and 10 !"
		continue;;
	esac
done
