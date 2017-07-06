#!/bin/bash
###### Warning!
echo "Please exec this script using ### Source ### !"
echo "Continue?(y/n)"
read detemine
if [ "$detemine" = "y" ] ;then
   echo "Let's go!"
elif [ "$detemine" = "n" ] ;then
	exit
fi
#attention:CINDER_DBPASS
cat << EOF > create.sql		
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'devops';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'devops';
EOF
#attention:MYSQL_PASS
mysql -uroot -p123 < create.sql 	

export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=admin 
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2

openstack user create --domain default --password-prompt cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder  --description "OpenStack Block Storage" volume
openstack service create --name cinderv2  --description "OpenStack Block Storage" volumev2

openstack endpoint create --region RegionOne volume public http://controller:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume internal http://controller:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume admin http://controller:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(tenant_id\)s

yum install openstack-cinder openstack-utils -y
cp /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak
grep -v "^#" /etc/cinder/cinder.conf | grep -v "^$" > cinder.conf

#attention:CINDER_PASS #attention:RABBIT_PASS
openstack-config --set cinder.conf database connection mysql+pymysql://cinder:devops@controller/cinder
openstack-config --set cinder.conf DEFAULT transport_url rabbit://openstack:devops@controller
openstack-config --set cinder.conf DEFAULT auth_strategy keystone
openstack-config --set cinder.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set cinder.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set cinder.conf keystone_authtoken memcached_servers controller:11211
openstack-config --set cinder.conf keystone_authtoken auth_type password
openstack-config --set cinder.conf keystone_authtoken project_domain_name default
openstack-config --set cinder.conf keystone_authtoken user_domain_name default
openstack-config --set cinder.conf keystone_authtoken project_name service
openstack-config --set cinder.conf keystone_authtoken username cinder
openstack-config --set cinder.conf keystone_authtoken password devops
openstack-config --set cinder.conf DEFAULT my_ip 192.168.31.6
openstack-config --set cinder.conf oslo_concurrency oslo_path /var/lib/cinder/tmp
cp cinder.conf /etc/cinder/cinder.conf
rm -rf cinder.conf
su -s /bin/sh -c "cinder-manage db sync" cinder

openstack-config --set /etc/nova/nova.conf cinder os_region_name RegionOne

systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
