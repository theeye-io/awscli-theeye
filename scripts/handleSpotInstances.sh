#!/bin/bash
#Thanks to https://devopsideas.com/automate-ebs-volume-snapshot/

function help () {
   echo "help:
   Launch Spot Instance By using TAG. It finds the Last AMI snapshot, Requires Zone, Optional TargetGroup for ELB, and overBid ( It calculates the biggest price for the past 4 hours plus this setting default is 0.002).
    --launchSpot=tag-value --instancetype=m1.small --zone=us-east-1e  (optional) --keypair=UseYourKey --targetgroup=FAFAFA --overbid=0.003
    "
   exit 1
}

#Params Stuff
for i in "$@"
do
  case $i in
    --launchSpot=*)
      TAG="${i#*=}"
      ACTION=launchSpot
      ;;
    --zone=*)
      ZONE="${i#*=}"
      ;;
    --target=*)
      TARGET="${i#*=}"
      ;;
    --overbid=*)
      OVERBID="${i#*=}"
      ;;
    --instancetype=*)
      INSTANCE_TYPE="${i#*=}"
      ;;
    --keypair=*)
      KEYPAIR="${i#*=}"
      ;;
      *)
      echo no arguments found
      help
      # unknown option
      ;;
  esac
done

#functions
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
function launchSpot () {
     #Tricky Part, take the last four hours max_price bidding, and adds 0.002 cents.
     if [ -z "$OVERBID" ];then
	    OVERBID=0.0002
     fi
     if [ -z "$KEYPAIR" ];then
	     KEYPAIR='' 
     else
	     KEYPAIR="\"KeyName\": \"$KEYPAIR\","
     fi
     maxiumPriceLastFourHours=$(aws ec2 describe-spot-price-history --availability-zone "$ZONE" --product-description "Linux/UNIX" --instance-types r4.large --start-time "$(date --date="@$(($(date +%s) - 14400))" "+%Y-%m-%dT-%H:%M:%S")"|jq -r '.SpotPriceHistory[].SpotPrice'|sort -u|tail -n1)
     bidPrice=$(python -c "print $maxiumPriceLastFourHours+$OVERBID")
     # Ends Tricky Bid Calculation.
     echo "finding newest AMI for provided TAG:$TAG for performing $ACTION"
     newestAMI=$(aws ec2 describe-images --filters Name=image-type,Values=machine Name=is-public,Values=false Name=name,Values="$TAG" | jq '.[]|max_by(.CreationDate)|.ImageId'|sed 's/\"//g')
     echo DEBUG
     echo "Launcing a $INSTANCE_TYPE using AMI $newestAMI"
     #Echo finding the subnet ID for a given Zone
     vpcID=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=$ZONE" | jq -r .Subnets[].SubnetId)
     aws ec2 request-spot-instances --spot-price "$bidPrice" --instance-count 1 --type "one-time" --launch-specification "{$KEYPAIR \"ImageId\":\"$newestAMI\",\"InstanceType\": \"$INSTANCE_TYPE\",\"SubnetId\":\"$vpcID\"}"
     
}
##end functions

case $ACTION in

"launchSpot")
  if [ -z $ZONE ];
  then
    echo "--zone is not defined"
    exit 1
  fi
  if [ -z $INSTANCE_TYPE ];
  then
    echo "--instancetype is not defined"
    exit 1
  fi
  launchSpot
;;


*)
  help "$@"
;;

esac 
