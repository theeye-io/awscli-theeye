#!/bin/bash
#Thanks to https://devopsideas.com/automate-ebs-volume-snapshot/

function help () {
   echo "help:
    Snapshot all volumes for instances that matches,It requires an instance tag
                 --backup=tag-value IE: $1 --backup prod*  
    Delete all snapshots older than 7 days by default, It requires a snapshot tag
                 --delete=tag-value (optional) --days=NUMBER IE: $1 --delete=prod* --days=3  
    Attach the last snapshot as a volume to an instance, requieres id-instance and snapshot tag. By default It creates a gp2 volume type.
                 --attach=tag-value --instance=instance-id 
    "
   exit 1
}

#Params Stuff
for i in "$@"
do
  case $i in
    --backup=*)
      TAG="${i#*=}"
      ACTION=backup
      ;;
    --delete=*)
      TAG="${i#*=}"
      ACTION=delete
      ;;
    --attach=*)
      TAG="${i#*=}"
      ACTION=attach
      ;;
    --instance=*)
      INSTANCEID="${i#*=}"
      ;;
    --days=*)
      AGE="${i#*=}"
      if ! [[ $AGE =~ ^[0-9]+$ ]] ; then
        echo "Age is invalid Asuming default 7"
        AGE=7
            fi
      ;;
#   --default)
#     DEFAULT=YES
#     ;;
      *)
	   echo no arguments found
           help
      # unknown option
      ;;
  esac
done

#functions
function backup_ebs () {
   
   echo "finding TAG:$TAG for performing $ACTION"
   
   for instance in $(aws ec2 describe-instances --filters "Name=tag-value,Values=$TAG" | jq -r ".Reservations[].Instances[].InstanceId")
   do
     echo "$instance matches"
     volumes=$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values="$instance" | jq .Volumes[].VolumeId | sed 's/\"//g')
     
     for volume in $volumes
     do
       echo "Creating snapshot for $volume $(aws ec2 create-snapshot --volume-id "$volume" --description "$TAG ebs-backup-script")"
     done
     
   done
}

function attach_ebs () {
     echo "finding newest snapshot for provided TAG:$TAG for performing $ACTION"
     snapshot=$(aws ec2 describe-snapshots --filters Name=description,Values="$TAG ebs-backup-script" | jq '.[]|max_by(.StartTime)|.SnapshotId' | sed 's/\"//g')
     echo finding availability zone for "$INSTANCEID"
     echo "Todo Add IOPS before volume creation"
     availabilityZone=$(aws ec2 describe-instances --instance-ids "$INSTANCEID"|jq .Reservations[].Instances[].Placement.AvailabilityZone| sed 's/\"//g')
     volumeID=$(aws ec2 create-volume --region us-east-1 --availability-zone "$availabilityZone" --snapshot-id "$snapshot"  --volume-type gp2 --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=created from $TAG ebs-tag-script }]" |jq .VolumeId |sed 's/\"//g' )
     echo waiting for volume "$volumeID "to become available
     aws ec2 wait volume-available --volume-ids "$volumeID"
     aws ec2 attach-volume --volume-id "$volumeID" --instance-id "$INSTANCEID" --device /dev/sdn
     #aws ec2 mount snapshot. 
     echo Verifing Volumes
     aws ec2 describe-volumes --filter Name=attachment.instance-id,Values="$INSTANCEID" | jq .Volumes[].VolumeId | sed 's/\"//g'
}

function delete_snapshots () {

   for snapshot in $(aws ec2 describe-snapshots --filters Name=description,Values="$TAG ebs-backup-script" | jq .Snapshots[].SnapshotId | sed 's/\"//g')
   do
   
   SNAPSHOTDATE="$(aws ec2 describe-snapshots --filters Name=snapshot-id,Values="$snapshot" | jq .Snapshots[].StartTime | cut -d T -f1 | sed 's/\"//g')"
   STARTDATE=$(date +%s)
   ENDDATE="$(date -d "$SNAPSHOTDATE" +%s)"
   INTERVAL=$(( (STARTDATE - ENDDATE) / (60*60*24) ))
   
   if (($INTERVAL >= $AGE ))
   then
   echo "Deleting snapshot --> $snapshot"
   aws ec2 delete-snapshot --snapshot-id "$snapshot"
   fi
   
   done
}
##end functions

case $ACTION in

"backup")
  backup_ebs
;;

"delete")
  if [ -z $AGE ];
  then
    echo "-d | --days not defined, asuming defaults which is 7"
    AGE=7
  fi
  delete_snapshots
;;

"attach")
  if [ -z "$INSTANCEID" ];
  then
    echo "--instance=ID undefined, please pick one of these:"
    aws ec2 describe-instances | jq -r ".Reservations[].Instances[].InstanceId"
    exit 1
  fi
  attach_ebs
;;

*)
  help "$@"
;;

esac 
