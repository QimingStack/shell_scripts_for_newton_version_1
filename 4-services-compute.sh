#!/bin/bash

######Compute service
compute_service () {
yum install openstack-nova-compute vim -y	
#configure /etc/nova/nova.conf
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
grep -v "^#" /etc/nova/nova.conf | grep -v "^$" > nova.conf
sed -i '/\[DEFAULT\]/ a\enabled_apis = osapi_compute,metadata' nova.conf
sed -i '/\[DEFAULT\]/ a\transport_url = rabbit://openstack:devops@controller' nova.conf 	#attention:RABBIT_PASS
sed -i '/\[DEFAULT\]/ a\auth_strategy = keystone' nova.conf
sed -i '/\[keystone_authtoken\]/ a\
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = nova \
password = devops' nova.conf 	#attention:NOVA_PASS
sed -i '/\[DEFAULT\]/ a\my_ip = 192.168.31.9' nova.conf 	#attention:MANAGEMENT_INTERFACE_IP_ADDRESS
sed -i '/\[DEFAULT\]/ a\
use_neutron = True \
firewall_driver = nova.virt.firewall.NoopFirewallDriver' nova.conf
sed -i '/\[vnc\]/ a\
enabled = True \
vncserver_listen = 0.0.0.0 \
vncserver_proxyclient_address = $my_ip \
novncproxy_base_url = http://controller:6080/vnc_auto.html' nova.conf
sed -i '/\[glance\]/ a\api_servers = http://controller:9292' nova.conf
sed -i '/\[oslo_concurrency\]/ a\lock_path = /var/lib/nova/tmp' nova.conf
sed -i '/\[placement\]/ a\
#os_region_name = RegionOne \
#project_domain_name = Default \
#project_name = service \
#auth_type = password \
#user_domain_name = Default \
#auth_url = http://controller:35357/v3 \
#username = placement \
#password = devops' nova.conf 	#attention:PLACEMENT_PASS

determine=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ "$determine" = "" ] ; then
	sed -i '/\[libvirt\]/ a\virt_type = qemu' nova.conf
fi

cp nova.conf /etc/nova/nova.conf
rm -rf nova.conf
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
sleep 2s
systemctl status libvirtd.service openstack-nova-compute.service
#Create OpenStack client environment scripts
cat << EOF > /root/admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=admin 
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
EOF
cat << EOF > /root/demo-openrc
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
EOF
#attention: Replace ADMIN_PASS
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_PROJECT_NAME=admin 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
#Using the scripts
#cd ~
#. admin-openrc
#cd -
echo "source ~/admin-openrc " >> ~/.bash_profile        #attention
openstack hypervisor list
}
echo "Please exec this script using ### Source ### !"
echo "Continue?(y/n)"
read detemine
if [ "$detemine" = "y" ] ;then
	echo "Let's go!"
        compute_service
elif [ "$detemine" = "n" ] ;then
        echo "Exit!"
fi
######