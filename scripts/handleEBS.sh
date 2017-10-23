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
    Create an AMI from the last snapshot, requires a tag. Optional an instance-name
                 --create=tag-value --volumesize=400 (optional) --instance=aNewAMIName
    Remove all unused Volumes
                 --remove=Region , I.E --remove=us-east-1
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
      INSTANCENAME=$INSTANCEID #instance works for both id and name settings
    ;;
    --days=*)
      AGE="${i#*=}"
      if ! [[ $AGE =~ ^[0-9]+$ ]] ; then
        echo "Age is invalid Asuming default 7"
        AGE=7
      fi
    ;;
    --volumesize=*)
      VOLUMESIZE="${i#*=}"
      if ! [[ $VOLUMESIZE =~ ^[0-9]+$ ]] ; then
        echo "Volume Size is invalid Asuming default"
        VOLUMESIZE=""
      else
        VOLUMESIZE=",VolumeSize=$VOLUMESIZE"
      fi
    ;;
    --create=*)
      TAG="${i#*=}"
      ACTION=create
    ;;
    --remove=*)
      ZONE="${i#*=}"
      ACTION=remove
    ;;
#      *)
#      echo no arguments found
#      help
#      # unknown option
#     ;;
  esac
done

#functions
function backup_ebs () {
   
   echo "finding TAG:$TAG for performing $ACTION"
   flag=0 
   for instance in $(aws ec2 describe-instances --filters "Name=tag-value,Values=$TAG" | jq -r ".Reservations[].Instances[].InstanceId")
   do
     echo "$instance matches"
     volumes=$(aws ec2 describe-volumes --filter Name=attachment.instance-id,Values="$instance" | jq .Volumes[].VolumeId | sed 's/\"//g')
     
     for volume in $volumes
     do
       echo "Creating snapshot for $volume $(aws ec2 create-snapshot --volume-id "$volume" --description "$TAG ebs-backup-script")"
     done
    flag=1 
   done
   if [ $flag -eq 0 ];then 
	   echo "I was unable to find any suitable instance with the TAG:$TAG provided"
   fi
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
function createfrom_ebs () {
     echo "finding newest snapshot for provided TAG:$TAG for performing $ACTION"
     snapshot=$(aws ec2 describe-snapshots --filters Name=description,Values="$TAG ebs-backup-script" | jq '.[]|max_by(.StartTime)|.SnapshotId' | sed 's/\"//g')
     if [ -z $snapshot ];then
       echo "I was unable to find any suitable snapshot using $TAG"
     else
       INSTANCENAME="$INSTANCENAME-$(date +"%m_%d")" 
       echo "Creating instance $INSTANCENAME from Snapshot $snapshot"
     fi
     createAMI=$(aws ec2 register-image --name "$INSTANCENAME" --architecture x86_64  --virtualization-type hvm  --root-device-name "/dev/sda1" --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=$snapshot $VOLUMESIZE,VolumeType=gp2}")
     echo "Done Creating AMI from EBS $createAMI"
}

function remove_unused_volumes {
	for regions in $ZONE
	do
		for volumes in $(aws ec2 describe-volumes --region $ZONE --output text| grep available | awk '{print $9}' | grep vol| tr '\n' ' ')
		do
			echo "Deleting $volumes < "
			aws ec2 delete-volume --region $ZONE --volume-id $volumes
		done
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
"create")
  if [ -z "$INSTANCENAME" ];
  then
    echo "--instance=AMIName is undefined, using $TAG as default... "
    INSTANCENAME="$TAG-from-snapshot"
  fi
  createfrom_ebs
;;
"remove")
  remove_unused_volumes
;;
*)
  echo "Invalid Arguments: "
  echo "$@" 
  help "$@"
;;

esac 
