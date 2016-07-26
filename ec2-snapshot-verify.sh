#!/bin/bash
export PATH=$PATH:/usr/local/bin:/usr/bin

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

# Set AWS account
aws_profile="default"
failing_volumes=()

# Get an array of servers
#servers=($(aws ec2 describe-instances --profile $aws_profile --output table | grep InstanceId | awk '{ print $4 }'))
servers=($(aws ec2 describe-instances --profile $aws_profile --output text --query Reservations[].Instances[].InstanceId))

## Putting the FUN in Functions ##

# Setup logfile and redirect stdout/stderr.
log_setup() {
    # Check if logfile exists and is writable.
    ( [ -e "$logfile" ] || touch "$logfile" ) && [ ! -w "$logfile" ] && echo "ERROR: Cannot write to $logfile. Check permissions or sudo access." && exit 1

    tmplog=$(tail -n $logfile_max_lines $logfile 2>/dev/null) && echo "${tmplog}" > $logfile
    exec > >(tee -a $logfile)
    exec 2>&1
}

# Log an event.
log() {
    echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}

# Verify the correct number of snapshots
verify_snapshots() {
  for volume_id in $1; do
    snapshot_list=($(aws ec2 describe-snapshots --profile $aws_profile --region $region --output=text --filters Name=volume-id,Values=$volume_id Name=tag-key,Values="CreatedBy" Name=tag-value,Values="AutomatedBackup" --query Snapshots[].SnapshotId))
    retention_days_in_seconds=$(date +%s --date "$3 days ago")
    printf "\tRetention Days: %s\n" "$3"
    if [ -z "$snapshot_list" ]
    then
      printf "\tVolume doesn't have any Autobackup snapshots!\n\n"
      failing_volumes+=($volume_id)
      continue
    fi
    if [ "${#snapshot_list[@]}" -ge "$node_days" ]
    then
      printf "\tNode has the correct number of snapshots, checking next server (if one exists)\n\n"
    else
      printf "\tNode does not have the correct number of snapshots - checking to see if it's a new node...\n"
      volume_attach_date=$(aws ec2 describe-volumes --profile $aws_profile --output text --volume-ids $volume_id --query Volumes[].CreateTime | cut -d. -f1)
      threashold_date=$(date +"%Y-%m-%dT%H:%M:%S" --date "$3 days ago")
      volume_attach_date_seconds=$(date +%s --date "$volume_attach_date days ago")
      printf "\t\tVolume Creation Date:\t\t%s\n\t\tThreashold Date:\t\t%s\n" "$volume_attach_date" "$threashold_date"
      if [ "$volume_attach_date_seconds" -lt "$retention_days_in_seconds" ] 
      then
        printf "\t\tVolume is failing snapshot threashold!\n\n"
        failing_volumes+=($volume_id)
      else
        printf "\t\tVolume is newer than threashold - no big deal\n\t\tVolume was created on %s\n\n" "$volume_attach_date"
      fi      
    fi
  done
}

# Gather an Array of all the volumes attached to the node
volume_attachments() {
  # Grab the region and then remove the AZ with sed
  region=$(aws ec2 describe-instances --profile $aws_profile --instance-ids $1 --output table | grep "Availability" | awk '{ print $4  }' |  sed -e 's/\([1-9]\).$/\1/g')
  # Grab a sweet sweet list of volumes and print it out
  volume_list=$(aws ec2 describe-volumes --profile $aws_profile --region $region --filters Name=attachment.instance-id,Values=$1 --query Volumes[].VolumeId --output text)
  printf "\tInstance has the following volume(s) attached\n\t\t%s\n" "$volume_list"
  # Need to continue to pass the information from the first loop
  verify_snapshots $volume_list $1 $2
}

# Find the correct number of retention days for the nodes and then do some other shit. 
# Need to call from this function because we want to keep it neat and organized
retention_days() {
  for index in "${!servers[@]}"
  do
    printf "Checking Retention Policy on Instance: %s\n" "${servers[index]}"
    # Lets query the chef server by instance ID and get the chef server's Node Name
    node_name=$(chef exec knife exec -E "nodes.find(:ec2_instance_id=> '${servers[index]}') { |node| puts node.name }")
    # Now that we have the Node Name, we can list the attribute and print out it's value
    # We have to check for null char because chef is stupid and prints silly format
    if [ -z "$node_name" ]
    then
      printf "\tThis server is not in chef! Breaking"
      continue
    fi
    node_days=$(chef exec knife node show $node_name -a delphic_snapshots.retention_days | awk '{ if($2!="") { print $2 } }')
    # If there's nothing set - we need to error out so we can add that manually.
    if [ -z "$node_days" ] 
    then
      printf "\tNode does not have retention days set! Erroring out after checking other servers\n"
    else
      printf "\tInstance is keeping snapshots for %s days.\n" "$node_days"
    fi
    # Pass the server ID into the function to get it's volume info
    volume_attachments ${servers[index]} $node_days
  done
}

check_errors() {
  if [ -z "$failing_volumes" ]
  then
    printf "\nAll Good"
  else
    printf "\n\nFailing Volumes:\n"
    printf "%s\n" "${failing_volumes[@]}"
    exit 1
  fi
}

# Testing


# Run Functions
retention_days
check_errors
