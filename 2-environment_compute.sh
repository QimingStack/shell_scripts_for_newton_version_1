#!/bin/bash#!/bin/bash

NTPSERVER="192.168.31.6"	# attention: NTPSERVER ip
#######modify_hostname
modify_hostname () {
hostnamectl set-hostname compute
}
######disable_sellinux_firewall
disable_sellinux_firewall () {
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo "bash ~/scripts-newton/2-environment_compute.sh" >> ~/.bash_profile 	# attention:directory scripts-newton
reboot
}
######Check firewalld SELinux
check_firewall_selinux () {
sed -i 's/bash ~\/scripts-newton\/2-environment_compute.sh//g' ~/.bash_profile		# attention:directory scripts-newton
systemctl status firewalld
sestatus	
}
######config NTP(chrony)
config_chrony_client () {
timedatectl set-timezone Asia/Shanghai
sed -i '/^server 0.centos.pool.ntp.org iburst/,/^server 3.centos.pool.ntp.org iburst/s/^/#/g' /etc/chrony.conf 
sed -i "/^#server 3.centos.pool.ntp.org iburst/a\server $NTPSERVER iburst" /etc/chrony.conf 	#attention: $NTPSERVER use ""
systemctl restart chronyd 
systemctl enable chronyd
ntpdate $NTPSERVER
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
192.168.31.9	compute
EOF
cp hosts /etc/hosts #>> EOF
#y
#EOF		#by this way, we won't change the attributes of /etc/hosts
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
yum install centos-release-openstack-newton -y     #attention:YUM is OK
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
#yum install python-openstackclient -y
}

echo "Select a operation:"
select opt in  modify_hostname disable_sellinux_firewall check_firewall_selinux config_chrony_client config_hosts configure_repo install_newton_client "Exit"
do 
	case $opt in
	modify_hostname)
		modify_hostname ;;
	disable_sellinux_firewall)
		disable_sellinux_firewall ;;
	check_firewall_selinux)
		check_firewall_selinux ;;
	config_chrony_client)
		config_chrony_client ;;
	config_hosts)
		config_hosts ;;
	configure_repo)
		configure_repo;;
	install_newton_client)
		install_newton_client ;;
	"Exit")
		exit 0;;
	*)
		echo "Please select a number between 1 and 5 !"
		continue;;
	esac
done
