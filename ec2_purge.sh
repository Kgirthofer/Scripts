#!/bin/bash

arr=($(aws ec2 describe-instances --filters "Name=tag-key,Values=Purge" --output table  | grep  InstanceId | awk '{print $4}'))

for index in "${!arr[@]}"
do
  purge_time="$(aws ec2 describe-instances --instance-ids ${arr[index]} --output table | grep Purge | awk '{print $4}')"
  if [ "${purge_time}" = "24h" ]; then
    printf "found purge server - deleting %s \n" ${arr[index]}
    aws ec2 terminate-instances --instance-ids ${arr[index]}
  fi
done
