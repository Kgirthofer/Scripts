#!/bin/bash

arr=($(aws ec2 describe-instances --filters "Name=tag-key,Values=Purge" --output table  | grep  InstanceId | awk '{print $4}'))
date=`date +"%m-%d-%y"`
echo "Today's date is $date: Basing purge date on this"
for index in "${!arr[@]}"
do
#  launch_time="$(aws ec2 describe-instances --instance-ids ${arr[index]} --output table | grep LaunchTime | awk '{print $4}')"
#  launch_time_rel=${launch_time:0:10}
#  echo ${launch_time_rel}
  purge_time="$(aws ec2 describe-instances --instance-ids ${arr[index]} --output table | grep Purge | awk '{print $4}')"
  server_name="$(aws ec2 describe-instances --instance-ids ${arr[index]} --output text | grep Name | awk '{print $3 $4}')"
  if [ "${purge_time}" = "24h" ]; then
    printf "found 24h purge for server %s (%s) - deleting instance \n" ${server_name} ${arr[index]}
    aws ec2 terminate-instances --instance-ids ${arr[index]}
  elif [ "${purge_time}" = "${date}" ]; then
    printf "found date purge for server %s (%s) - deleteing \n" ${server_name} ${arr[index]}
    aws ec2 terminate-instances --instance-ids ${arr[index]
  elif [ "${purge_time}" = "||||" ]; then
    printf "Server %s (%s) has no purge date - will never be purged \n" ${server_name} ${arr[index]}
  else
    printf "Server %s (%s) has a purge date of %s and will not be deleted today \n" ${server_name} ${arr[index]} ${purge_time}
  fi
done
