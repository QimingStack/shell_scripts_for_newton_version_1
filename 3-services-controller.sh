#!/bin/bash

###### identity_service
identity_service () {
MYSQLPWD=123   #attention the password of mysql
cat << EOF > create.sql
create database keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'devops'; 
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'devops'; 
exit
EOF
mysql -u root -p$MYSQLPWD  < create.sql
rm -f create.sql
yum install openstack-keystone httpd mod_wsgi -y
#configure keystone.conf
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
grep -v "^#" /etc/keystone/keystone.conf | grep -v "^$" > keystone.conf
sed -i '/\[database\]/ a\connection = mysql+pymysql://keystone:devops@controller/keystone' keystone.conf
sed -i '/\[token\]/ a\provider = fernet'  keystone.conf
cp keystone.conf /etc/keystone/keystone.conf
rm -rf keystone.conf
#Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone
#Initialize Fernet key repositories
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone 
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
#Bootstrap the Identity service  attention ADMIN_PASS
keystone-manage bootstrap --bootstrap-password devops \
	--bootstrap-admin-url http://controller:35357/v3/ \
	--bootstrap-internal-url http://controller:5000/v3/ \
	--bootstrap-public-url http://controller:5000/v3/ \
	--bootstrap-region-id RegionOne
#Configure the Apache HTTP server
sed -i 's/#ServerName www.example.com:80/ServerName controller/g' /etc/httpd/conf/httpd.conf
#Create a link to the?/usr/share/keystone/wsgi-keystone.conf file
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
#Finalize the installation
systemctl enable httpd.service 
systemctl start httpd.service
systemctl status httpd.service
#attention: Replace ADMIN_PASS
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_PROJECT_NAME=admin 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
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
#Using the scripts
#cd ~
#. admin-openrc
#cd -
echo "source ~/admin-openrc " >> ~/.bash_profile        #attention
openstack token issue
#Create a domain, projects, users, and roles
openstack project create --domain default --description "Service Project" service 
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password-prompt demo
openstack role create user
openstack role add --project demo --user demo user
#Verify operation
unset OS_AUTH_URL OS_PASSWORD
openstack --os-auth-url http://controller:35357/v3 \
   --os-project-domain-name default --os-user-domain-name default \
   --os-project-name admin --os-username admin token issue
openstack --os-auth-url http://controller:5000/v3 \
   --os-project-domain-name default --os-user-domain-name default \
   --os-project-name demo --os-username demo token issue

}

######Install and configure image service(glance)
image_service () {
MYSQLPWD=123   #attention the password of mysql
cat << EOF > create.sql
create database glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'devops'; 
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'devops'; 
exit
EOF
mysql -u root -p$MYSQLPWD  < create.sql
rm -f create.sql
#Prerequisites
cd ~
. admin-openrc
cd -
openstack user create --domain default --password-prompt glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image 
#Create the Image service API endpoints
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292 
#Install and confifgure
yum install openstack-glance -y

cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
grep -v "^#" /etc/glance/glance-api.conf | grep -v "^$" > glance-api.conf
sed -i '/\[database\]/ a\connection = mysql+pymysql://glance:devops@controller/glance' glance-api.conf
sed -i '/\[keystone_authtoken\]/ a\
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = glance \
password = devops' glance-api.conf
sed -i '/\[paste_deploy\]/ a\flavor = keystone' glance-api.conf
sed -i '/\[glance_store\]/ a\
stores = file,http \
default_store = file \
filesystem_store_datadir = /var/lib/glance/images/' glance-api.conf
cp glance-api.conf /etc/glance/glance-api.conf
rm -rf glance-api.conf

cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.bak
grep -v "^#" /etc/glance/glance-registry.conf | grep -v "^$" > glance-registry.conf
sed -i '/\[database\]/ a\connection = mysql+pymysql://glance:devops@controller/glance' glance-registry.conf
sed -i '/\[keystone_authtoken\]/ a\
auth_uri = http://controller:5000 \
auth_url = http://controller:35357 \
memcached_servers = controller:11211 \
auth_type = password \
project_domain_name = default \
user_domain_name = default \
project_name = service \
username = glance \
password = devops ' glance-registry.conf
sed -i '/\[paste_deploy\]/ a\flavor = keystone' glance-registry.conf
cp glance-registry.conf /etc/glance/glance-registry.conf
rm -rf glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service 
systemctl start openstack-glance-api.service openstack-glance-registry.service
systemctl status openstack-glance-api.service openstack-glance-registry.service
#Verify operation
#cd ~
#. admin-openrc
#cd -
yum install wget -y
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" \
   --file cirros-0.3.5-x86_64-disk.img \
   --disk-format qcow2 --container-format bare \
   --public
openstack image list 
}

######Compute service
compute_service () {
MYSQLPW=123		#attention:mysql MySQLPASS/NOVA_DBPASS

cat << EOF > create.sql
CREATE DATABASE nova_api;
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'devops';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' \
  IDENTIFIED BY 'devops';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'devops';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY 'devops';
exit
EOF
mysql -uroot -p$MYSQLPW < create.sql
rm -rf create.sql

#cd ~ 
#. admin-openrc
#cd -
openstack user create --domain default --password-prompt nova
openstack role add --project service --user nova admin
openstack service create --name nova \
  --description "OpenStack Compute" compute 
openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1/%\(tenant_id\)s
#Create a Placement service user using your chosen PLACEMENT_PASS
openstack user create --domain default --password-prompt placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
#Create the Placement API service endpoints
openstack endpoint create --region RegionOne placement public http://controller/placement
openstack endpoint create --region RegionOne placement internal http://controller/placement
openstack endpoint create --region RegionOne placement admin http://controller/placement

#Install and configure components
yum install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler openstack-nova-placement-api -y
#Edit /etc/nova/nova.conf
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
grep -v "^#" /etc/nova/nova.conf | grep -v "^$" > nova.conf
sed -i '/\[DEFAULT\]/ a\enabled_apis = osapi_compute,metadata' nova.conf
sed -i '/\[api_database\]/ a\connection = mysql+pymysql://nova:devops@controller/nova_api' nova.conf 	#attention:NOVA_DBPASS
sed -i '/\[database\]/ a\connection = mysql+pymysql://nova:devops@controller/nova' nova.conf 	#attention:NOVA_DBPASS
sed -i '/\[DEFAULT\]/ a\transport_url = rabbit://openstack:devops@controller' nova.conf 	#attention:RABBIT_PASS
sed -i '/\[DEFAULT\]/ a\auth_strategy = keystone' nova.conf 	#attention:Ocata configure this line under [api]
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
sed -i '/\[DEFAULT\]/ a\
my_ip = 192.168.31.6 \
use_neutron = True \
firewall_driver = nova.virt.firewall.NoopFirewallDriver' nova.conf 	#attention:my_ip
sed -i '/\[vnc\]/ a\
enabled = true \
# ... \
vncserver_listen = $my_ip \
vncserver_proxyclient_address = $my_ip' nova.conf
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
cp nova.conf /etc/nova/nova.conf
rm -rf nova.conf

cat << EOF >> /etc/httpd/conf.d/00-nova-placement-api.conf

<Directory /usr/bin> 
    <IfVersion >= 2.4> 
        Require all granted 
    </IfVersion> 
    <IfVersion < 2.4> 
        Order allow,deny 
        Allow from all 
    </IfVersion> 
</Directory>
EOF
#Populate databases
su -s /bin/sh -c "nova-manage api_db sync" nova
#su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
#su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
#Verify nova cell0 and cell1 are registered correctly
#nova-manage cell_v2 list_cells
#Start the Compute services and configure them to start when the system boots
systemctl enable openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service 
systemctl start openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service

}

echo "Please exec this script using ### Source ### !"
echo "Continue?(y/n)"
read detemine
if [ "$detemine" = "y" ] ;then
   echo "Let's go!"
elif [ "$detemine" = "n" ] ;then
   exit
fi
echo "Please Select an Operation: "
select opt in identity_service image_service compute_service exit
do
	case $opt in 
	identity_service)
		identity_service ;;
	image_service)
		image_service ;;
	compute_service)
		compute_service ;;
	exit)
		break ;;
	*)
		echo "Please type in a number between 1 and 4"
		continue ;;
	esac
done