#!/bin/bash

AMI="ami-08111162"

echo $Instance_Type

## Need to update with your public and private subnets
if   [ $Subnet = "Public" ]
then
	Subnet='subnet-XXXXXXXX'
elif [ $Subnet = "Private" ]
then
	Subnet='subnet-XXXXXXXX'
fi

if   [ $IAM_Profile = "" ]
then
	IAM_Profile="default"
fi

## Need to update with your SG's
if   [ $Security_Group = "DEV" ]
then
	Security_Group='sg-XXXXXXXX'
elif [ $Security_Group = "PRD" ]
then
	Security_Group='sg-XXXXXXXX'
fi

chef exec knife ec2 server create -v

echo "##################################################################################################"
echo "Launching a(n) $OS instance in $Region$AZ with a $EBS_Size volume - will run $Run_List from chef!!"
echo "##################################################################################################"

sleep 5

# Launch
chef exec knife ec2 server create                      \
	-x                         'ec2-user'                \
	-i                         ~/.ssh/YOUR_PEM.pem       \
	--secret-file              ~/.ssh/YOUR_PEM.pem       \
	--bootstrap-version        12.5.1                    \
	--availability-zone        "$Region$AZ"              \
	--flavor                   "$Instance_Type"          \
	--ebs-size                 "$EBS_Size"               \
	--ebs-volume-type          "gp2"                     \
	--image                    "$AMI"                    \
	--ssh-key                  "YOUR_SSH_KEY"            \
	--region                   "$Region"                 \
	--iam-profile              "$IAM_Profile"            \
	--security-group-ids       "$Security_Group"         \
	--subnet                   "$Subnet"                 \
	--tags                     "Name=$Name,Run List=$Run_List,Client=$Client,Environment=$Environment,OS=$OS,Purge=$Purge_Date" \
	--environment              "$Environment"            \
	--fqdn                     "$FQDN"                   \
	--run-list                 "$Run_List"               \
	#{"--json-attributes '{ \"#{instance[:apps].downcase}\": { \"hostname\": \"#{instance[:hn]}\" } }'" if json_bool}"
