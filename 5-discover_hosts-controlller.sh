#!/bin/bash

#source ~/admin-openrc
openstack hypervisor list
sleep 1s
openstack compute service list
sleep 1s
openstack compute service list
sleep 1s
openstack catalog list
sleep 1s
openstack image list
#Discover compute hosts
#su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

