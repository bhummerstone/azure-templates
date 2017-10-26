# Create infrastructure for running SPS test environment in Azure

This template creates:
* A virtual network with two subnets: one for the app servers and one for the resource server
* An load balancer
* A load balancer rule for 80/443 for the app servers
* A NAT rule to allow direct 80/443 access to the app servers on port 8080/8081 and 8443/8444
* A public IP for the load balancer
* A public IP for the resource server
* NICs for all of the servers
* An availability set for the app servers
* 2 VMs for the app servers with a 64GB data disk
* 1 VM for the resource server with a 64GB data disk
* A Standard S3 Azure SQL DB