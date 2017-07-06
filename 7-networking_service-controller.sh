#!/bin/bash

#This is a mark to identify the network Option
option_mark=0
######Networking service
networking_prerequisites () {
MYSQLPW="123"
#attention:NEUTRON_DBPASS
cat << EOF > create.sql
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'devops';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'devops';
exit
EOF
mysql -uroot -p$MYSQLPW < create.sql
rm -rf create.sql
#create the service credentials
openstack user create --domain default --password-prompt neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696
echo "*******************************************************
Attention: Only select Provider or Self-Service networks! "
}

####################################Configure networking options#########################################
######Networking Option 1:Provider networks
option_provider_networks () {
option_mark=1
yum install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables -y
#Configure the server component
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
grep -v "^#" /etc/neutron/neutron.conf | grep -v "^$" > neutron.conf
sed -i '/\[database\]/ a\connection = mysql+pymysql://neutron:devops@controller/neutron' neutron.conf  #attention:NEUTRON_DBPASS
sed -i '/\[DEFAULT\]/ a\
core_plugin = ml2 \
service_plugins =' neutron.conf
sed -i '/\[DEFAULT\]/ a\transport_url = rabbit://openstack:devops@controller' neutron.conf  #attention:RABBIT_PASS
sed -i '/\[DEFAULT\]/ a\
# ... \
auth_strategy = keystone' neutron.conf
sed -i '/\[keystone_authtoken\]/ a\
# ... \
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = neutron \
password = devops' neutron.conf     #attention:NEUTRON_PASS
sed -i '/\[DEFAULT\]/ a\
# ... \
notify_nova_on_port_status_changes = true \
notify_nova_on_port_data_changes = true' neutron.conf
sed -i '/\[nova\]/ a\
# ... \
auth_url = http://controller:35357 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
region_name = RegionOne \
project_name = service \
username = nova \
password = devops' neutron.conf     #attention:NOVA_PASS
sed -i '/\[oslo_concurrency\]/ a\
# ... \
lock_path = /var/lib/neutron/tmp' neutron.conf

cp neutron.conf /etc/neutron/neutron.conf
rm -rf neutron.conf

#Configure the Modular Layer 2 (ML2) plug-in
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
grep -v "^#" /etc/neutron/plugins/ml2/ml2_conf.ini | grep -v "^$" > ml2_conf.ini
sed -i '/\[ml2\]/ a\
# ... \
type_drivers = flat,vlan \
# ... \
tenant_network_types = \
# ... \
mechanism_drivers = linuxbridge \
# ... \
extension_drivers = port_security' ml2_conf.ini
sed -i '/\[ml2_type_flat\]/ a\
# ... \
flat_networks = provider' ml2_conf.ini
sed -i '/\[securitygroup\]/ a\
# ... \
enable_ipset = true' ml2_conf.ini
cp ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
rm -rf ml2_conf.ini

#Configure the Linux bridge agent
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
grep -v "^#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini | grep -v "^$" > linuxbridge_agent.ini
sed -i '/\[linux_bridge\]/ a\physical_interface_mappings = provider:eth0' linuxbridge_agent.ini  #attention:PROVIDER_INTERFACE_NAME
sed -i '/\[vxlan\]/ a\enable_vxlan = false' linuxbridge_agent.ini
sed -i '/\[securitygroup\]/ a\
# ... \
enable_security_group = true \
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' linuxbridge_agent.ini
cp linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini
rm -rf linuxbridge_agent.ini
#Configure the DHCP agent
cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
grep -v "^#" /etc/neutron/dhcp_agent.ini | grep -v "^$" > dhcp_agent.ini
sed -i '/\[DEFAULT\]/ a\
# ... \
interface_driver = linuxbridge \
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq \
enable_isolated_metadata = true' dhcp_agent.ini 
cp dhcp_agent.ini /etc/neutron/dhcp_agent.ini
rm -rf dhcp_agent.ini
}
######Networking Option 2: Self-service networks##########################################3
option_self_service_networks () {
option_mark=2
#Install the components
yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y
#Configure the server component
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
grep -v "^#" /etc/neutron/neutron.conf | grep -v "^$" > neutron.conf 
sed -i '/\[database\]/ a\connection = mysql+pymysql://neutron:devops@controller/neutron' neutron.conf   #attention:NEUTRON_DBPASS
sed -i '/\[DEFAULT\]/ a\
core_plugin = ml2 \
service_plugins = router \
allow_overlapping_ips = true' neutron.conf
sed -i '/\[DEFAULT\]/ a\transport_url = rabbit://openstack:devops@controller' neutron.conf  #attention:RABBIT_PASS
sed -i '/\[DEFAULT\]/ a\auth_strategy = keystone' neutron.conf
sed -i '/\[keystone_authtoken\]/ a\
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = neutron \
password = devops' neutron.conf     #attention:NEUTRON_PASS
sed -i '/\[DEFAULT\]/ a\
notify_nova_on_port_status_changes = true \
notify_nova_on_port_data_changes = true' neutron.conf
sed -i '/\[nova\]/ a\
auth_url = http://controller:35357 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
region_name = RegionOne \
project_name = service \
username = nova \
password = devops' neutron.conf     #attention:NOVA_PASS
sed -i '/\[oslo_concurrency\]/ a\lock_path = /var/lib/neutron/tmp' neutron.conf
cp neutron.conf /etc/neutron/neutron.conf
rm -rf neutron.conf

#Configure the Modular Layer 2 (ML2) plug-in
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
grep -v "^#" /etc/neutron/plugins/ml2/ml2_conf.ini  | grep -v "^$" > ml2_conf.ini
sed -i '/\[ml2\]/ a\
type_drivers = flat,vlan,vxlan \
tenant_network_types = vxlan \
mechanism_drivers = linuxbridge,l2population \
extension_drivers = port_security' ml2_conf.ini
sed -i '/\[ml2_type_flat\]/ a\flat_networks = provider' ml2_conf.ini
sed -i '/\[ml2_type_vxlan\]/ a\vni_ranges = 1:1000' ml2_conf.ini
sed -i '/\[securitygroup\]/ a\enable_ipset = true' ml2_conf.ini
cp ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
rm -rf ml2_conf.ini

#Configure the Linux bridge agent
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
grep -v "^#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini | grep -v "^$" > linuxbridge_agent.ini
sed -i '/\[linux_bridge\]/ a\physical_interface_mappings = provider:eth0' linuxbridge_agent.ini  #attention:PROVIDER_INTERFACE_NAME
sed -i '/\[vxlan\]/ a\
enable_vxlan = true \
local_ip = 192.168.31.6 \
l2_population = true' linuxbridge_agent.ini     #attention:OVERLAY_INTERFACE_IP_ADDRESS
sed -i '/\[securitygroup\]/ a\
enable_security_group = true \
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' linuxbridge_agent.ini
cp linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
rm -rf linuxbridge_agent.ini

#Configure the layer-3 agent
cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
grep -v "^#" /etc/neutron/l3_agent.ini | grep -v "^$" > l3_agent.ini
sed -i '/\[DEFAULT\]/ a\interface_driver = linuxbridge' l3_agent.ini
cp l3_agent.ini /etc/neutron/l3_agent.ini
rm -rf l3_agent.ini

#Configure the DHCP agent
cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
grep -v "^#" /etc/neutron/dhcp_agent.ini | grep -v "^$" > dhcp_agent.ini
sed -i '/\[DEFAULT\]/ a\
interface_driver = linuxbridge \
dhcp_drver = neutron.agent.linux.dhcp.Dnsmasq \
enable_isolated_metadata = true' dhcp_agent.ini
cp dhcp_agent.ini /etc/neutron/dhcp_agent.ini 
rm -rf dhcp_agent.ini
}

######configure controller node
finalize_configure_networking () {
#Configure the metadata agent
cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.bak
grep -v "^#" /etc/neutron/metadata_agent.ini | grep -v "^$" > metadata_agent.ini
sed -i '/\[DEFAULT\]/ a\
# ... \
nova_metadata_ip = controller \
metadata_proxy_shared_secret = devops' metadata_agent.ini   #attention:METADATA_SECRET
cp metadata_agent.ini /etc/neutron/metadata_agent.ini
rm -rf metadata_agent.ini

#Configure the Compute service to use the Networking service
sed -i '/\[neutron\]/ a\
# ... \
url = http://controller:9696 \
auth_url = http://controller:35357 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
region_name = RegionOne \
project_name = service \
username = neutron \
password = devops \
service_metadata_proxy = True \
metadata_proxy_shared_secret = devops' /etc/nova/nova.conf  #attention:NEUTRON_PASS/METADATA_SECRET

#Finalize installation
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service \
  neutron-linuxbridge-agent.service \
  neutron-dhcp-agent.service \
  neutron-metadata-agent.service
systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service

#For networking option 2, also enable and start the layer-3 service
if [ "$option_mark" = 2 ] ; then
    systemctl enable neutron-l3-agent.service
    systemctl start neutron-l3-agent.service    
fi
}

echo "Select a Operation:"
select opt in networking_prerequisites option_provider_networks option_self_service_networks finalize_configure_networking Exit
do
    case $opt in
        networking_prerequisites)
            networking_prerequisites ;;
        option_provider_networks)
            option_provider_networks ;;
        option_self_service_networks)
            option_self_service_networks ;;
        finalize_configure_networking)
            finalize_configure_networking ;;
        Exit)
        	exit 0;;
        *)
        	echo "Please type in a number Above"
            continue ;;
    esac
done
	