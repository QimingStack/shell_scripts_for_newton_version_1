#!/bin/bash
#echo "!!! Please use source <file.sh> or . <file.sh> to run this shell script!!!"

#Create virtual networks
######Create the provider network
create_provider_network () {
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=admin 
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2

openstack network create  --share --external \
  --provider-physical-network provider \
  --provider-network-type flat provider
#attention:
#	START_IP_ADDRESS
#	END_IP_ADDRESS
#	DNS_RESOLVER
#	PROVIDER_NETWORK_GATEWAY
#	PROVIDER_NETWORK_CIDR
while true 
do
echo "Creating subnet in provider network:"
echo "Please type in START_IP_ADDRESS for --allocation-pool:"
read start_ip_address
echo "Please type in END_IP_ADDRESS for --allocation-pool:"
read end_ip_address
echo "Please type in DNS_RESOLVER for --dns-nameserver:"
read dns_resolver
echo "Please type in PROVIDER_NETWORK_GATEWAY for --gateway"
read provider_network_gateway
echo "Please type in PROVIDER_NETWORK_CIDR for --subnet-range"
read provider_network_cidr
echo "openstack subnet create --network provider
  --allocation-pool start=$start_ip_address,end=$end_ip_address
  --dns-nameserver $dns_resolver --gateway $provider_network_gateway
  --subnet-range $provider_network_cidr provider"
echo "Right or not?(y/n)"
read check
if [ $check = "y" ]; then
	openstack subnet create --network provider \
  --allocation-pool start=$start_ip_address,end=$end_ip_address \
  --dns-nameserver $dns_resolver --gateway $provider_network_gateway \
  --subnet-range $provider_network_cidr provider
  break
fi
done

}
######Create the self-service network
create_self_service_network () {
echo "You must create the provider network before the self-service network."
sleep 2s
#source the demo credentials to gain access to user-only CLI commands
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
#Create the network
openstack network create selfservice
#Create a subnet on the network
while true 
do 
echo "Creating subnet in self-serice network:"
echo "Please type in DNS_RESOLVER for --dns-nameserver"
read dns_resolver
echo "Please type in SELFSERVICE_NETWORK_GATEWAY for --gateway"
read selfservice_network_gateway
echo "Please type in SELFSERVICE_NETWORK_CIDR for --subnet-range"
read selfservice_network_cidr
echo "openstack subnet create --network selfservice 
  --dns-nameserver $dns_resolver --gateway $selfservice_network_gateway 
  --subnet-range $selfservice_network_cidr selfservice"
echo "Right or not?(y/n)"
read check
if [ "$check" = "y" ] ;then
	openstack subnet create --network selfservice \
  --dns-nameserver $dns_resolver --gateway $selfservice_network_gateway \
  --subnet-range $selfservice_network_cidr selfservice
	break
fi
done 
}
#Create a router
create_a_router () {
#Source the demo credentials to gain access to user-only CLI commands
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
#Create the router
openstack router create router
#Add the self-service network subnet as an interface on the router
neutron router-interface-add router selfservice
#5.Set a gateway on the provider network on the router
neutron router-gateway-set router provider
}
######Verify operation
verify_network () {
#source the admin credentials to gain access to admin-only CLI commands
export OS_PROJECT_DOMAIN_NAME=Default 
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=admin 
export OS_USERNAME=admin 
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:35357/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
#2.List network namespaces. You should see one qrouter namespace and two qdhcp namespaces
ip netns
#3.List ports on the router to determine the gateway IP address on the provider network:
neutron router-port-list router
echo "Ping gateway of the router."

#routeid=`ip netns | grep qrouter | awd '{print $1}'`
#ip netns $routeid ping
subnet_id=`neutron subnet-list | grep provider | awk '{print $2}'`
gateway_id=`neutron router-port-list router | grep $subnet_id | awk '{print $10}'`
str=`neutron router-port-list router | grep $gateway_id | awk '{print $10}'`
gateway_ip=${str:0-15:13}   #attention:"192.168.31.115"}, count begin from right side sixteen character 
							#and  reserved 14 characters 
#str2=${str:1}
#gateway_ip=${str2}
echo "gateway ip: $gateway_ip"
qrouter_id=`ip netns | grep qrouter | awk '{print $1}'`
echo "qrouter id: $qrouter_id"
ip netns exec $qrouter_id ping -c 4 $gateway_ip
#--------------------------------------------------------------
echo "Self-service network is OK!"
}

######Create m1.nano flavor
create_a_flavor () {
echo "Create m1.nano flavor"
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
}

######
generate_a_key_pair () {
echo "Generate a key pair"
#1.Source the demo project credentials
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
#2.Generate a key pair and add a public key
ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
#3.Verify addition of the key pair
openstack keypair list
}

######
add_seurity_group_rules () {
echo "Add security group rules"
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default
}

######Launch an instance
launch_an_instance_on_provider_network () {
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
openstack flavor list
openstack image list
openstack network list
openstack security group list
echo "I couldn't help you more, you can use the below COMMAND to launch the instance ON provider networks:
Attention PROVIDER_NET_ID and INSTANCE_NAME ... should be replaced"
echo "openstack server create --flavor FLAVOR_NAME --image IMAGE_NAME --nic net-id=PROVIDER_NET_ID --security-group SECURITY_GROPU_NAME --key-name mykey INSTANCE_NAME"
echo "And then use below COMMOND to check the status of instance"
echo "openstack server list"
#exit
break
}

launch_an_instance_on_self_service_network () {
export OS_USER_DOMAIN_NAME=Default 
export OS_PROJECT_NAME=demo 
export OS_USERNAME=demo
export OS_PASSWORD=devops 
export OS_AUTH_URL=http://controller:5000/v3 
export OS_IDENTITY_API_VERSION=3 
export OS_IMAGE_API_VERSION=2
openstack flavor list
openstack image list
openstack network list
openstack security group list
echo "I couldn't help you more, you can use the below COMMAND to launch the instance ON self-service networks:
Attention PROVIDER_NET_ID and INSTANCE_NAME ... should be replaced"
echo "openstack server create --flavor FLAVOR_NAME --image IMAGE_NAME --nic net-id=PROVIDER_NET_ID --security-group SECURITY_GROPU_NAME --key-name mykey INSTANCE_NAME"
echo "And then use below COMMOND to check the status of instance"
echo "openstack server list"
#exit
break
}
###### Warning!
echo "**********************************************"
echo "Please exec this script using ### Source ### !"
echo "Continue?(y/n)"
read detemine
if [ "$detemine" = "y" ] ;then
   echo "Let's go!"
elif [ "$detemine" = "n" ] ;then
   exit
fi

echo "Please select an Operation:"
select opt in create_provider_network create_self_service_network create_a_router verify_network create_a_flavor generate_a_key_pair add_seurity_group_rules launch_an_instance_on_provider_network launch_an_instance_on_self_service_network exit
do
case $opt in
	create_provider_network)
		create_provider_network;;
	create_self_service_network)
		create_self_service_network;;
	create_a_router)
		create_a_router;;
	verify_network)
		verify_network ;;
	create_a_flavor)
		create_a_flavor;;
	generate_a_key_pair)
		generate_a_key_pair;;
	add_seurity_group_rules)
		add_seurity_group_rules;;
	launch_an_instance_on_provider_network)
		launch_an_instance_on_provider_network;;
	launch_an_instance_on_self_service_network)
		launch_an_instance_on_self_service_network;;
exit)
	break ;;
*)
	echo "Please type in one number above!"
continue ;;	
esac
done