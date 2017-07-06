#!/bin/bash
#This is a mark to identify the network Option
#option_mark=0
######Install and configure the common components
install_common_components () {
yum install openstack-neutron-linuxbridge ebtables ipset -y
#Configure the common component
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
grep -v "^#" /etc/neutron/neutron.conf | grep -v "^$" > neutron.conf
sed -i '/\[DEFAULT\]/ a\
transport_url = rabbit://openstack:devops@controller \
auth_strategy = keystone' neutron.conf 	#attention:RABBIT_PASS
sed -i '/\[keystone_authtoken\]/ a\
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = neutron \
password = devops' neutron.conf 	#attention:NEUTRON_PASS
sed -i '/\[oslo_concurrency\]/ a\lock_path = /var/lib/neutron/tmp' neutron.conf
cp neutron.conf /etc/neutron/neutron.conf
rm -rf neutron.conf
echo "*******************************************************
Attention: Only select Provider or Self-Service networks! "
}
##############################################Configure networking options###############################
######Networking Option 1: Provider networks
option_provider_networks () {
#option_mark=1
#Configure the Linux bridge agent	
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini
grep -v "^#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini | grep -v "^$" > linuxbridge_agent.ini
sed -i '/\[linux_bridge\]/ a\physical_interface_mappings = provider:eth0' linuxbridge_agent.ini 	#attention:PROVIDER_INTERFACE_NAME
sed -i '/\[vxlan\]/ a\enable_vxlan = false' linuxbridge_agent.ini
sed -i '/\[securitygroup\]/ a\
enable_security_group = true \
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' linuxbridge_agent.ini
cp linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
rm -rf linuxbridge_agent.ini 
}

######Networking Option 2: Self-service networks
option_self_serviece_networks () {
#Configure the Linux bridge agent
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
grep -v "^#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini | grep -v "^$" > linuxbridge_agent.ini
sed -i '/\[linux_bridge\]/ a\physical_interface_mappings = provider:eth0' linuxbridge_agent.ini 	#attention:PROVIDER_INTERFACE_NAME
sed -i '/\[vxlan\]/ a\
enable_vxlan = true \
local_ip = 192.168.31.9 \
l2_population = true' linuxbridge_agent.ini 	#attention:OVERLAY_INTERFACE_IP_ADDRESS
sed -i '/\[securitygroup\]/ a\
enable_security_group = true \
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' linuxbridge_agent.ini
cp linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
rm -rf linuxbridge_agent.ini
}
#######finalize_configure_networking
finalize_configure_networking () {
#Configure the Compute service to use the Networking service
sed -i '/\[neutron\]/ a\
url = http://controller:9696 \
auth_url = http://controller:35357 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
region_name = RegionOne \
project_name = service \
username = neutron \
password = devops' /etc/nova/nova.conf 	#attention:NEUTRON_PASS
#Finalize installation
systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service

openstack extension list --network
openstack network agent list
}

echo "Select an Operation:"
select opt in install_common_components option_provider_networks option_self_serviece_networks finalize_configure_networking exit
do
	case $opt in 
	install_common_components)
		install_common_components ;;
	option_provider_networks)
		option_provider_networks ;;
	option_self_serviece_networks)
		option_self_serviece_networks ;;
	finalize_configure_networking)
		finalize_configure_networking ;;
	exit)
		exit 0;;
	*)
		echo "Please type in a number Above"
		continue ;;
	esac
done
