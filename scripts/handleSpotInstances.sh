#!/bin/bash
#Thanks to https://devopsideas.com/automate-ebs-volume-snapshot/

function help () {
   echo "help:
   Launch Spot Instance By using TAG. It finds the Last AMI snapshot, Requires Zone, Optional TargetGroup for ELB, and overBid ( It calculates the biggest price for the past 4 hours plus this setting default is 0.002).
   --launchSpot=tag-value --instancetype=m1.small --volumetype=standard|gp2(optional) --zone=us-east-1e  (optional) --keypair=UseYourKey --targetgroup=arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/my-targets/73e2d6bc24d8a067 --overbid=0.003 --securitygroups='securitygroupID1,securitygroupID2' --userdata='yourBase64EncodedScript'
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
    --targetgroup=*)
      TARGET="${i#*=}"
      ;;
    --userdata=*)
      USERDATA="${i#*=}"
      ;;
    --overbid=*)
      OVERBID="${i#*=}"
      ;;
    --instancetype=*)
      INSTANCE_TYPE="${i#*=}"
      ;;
    --volumetype=*)
      VOLUME_TYPE="${i#*=}"
      ;;
    --keypair=*)
      KEYPAIR="${i#*=}"
      ;;
    --securitygroups=*)
      SECURITYGROUPS="${i#*=}"
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
function prepareVariables () {
   #Tricky Part, take the last four hours max_price bidding, and adds 0.002 cents.
     if [ -z "$OVERBID" ];then
      OVERBID=0.0002
     fi
     if [ -z "$VOLUME_TYPE" ];then
       VOLUME_TYPE='gp2' 
     fi
     if [ -z "$KEYPAIR" ];then
       KEYPAIR='' 
     else
       KEYPAIR="\"KeyName\": \"$KEYPAIR\","
     fi
     maxiumPriceLastFourHours=$(aws ec2 describe-spot-price-history --availability-zone "$ZONE" --product-description "Linux/UNIX" --instance-types $INSTANCE_TYPE --start-time "$(date --date="@$(($(date +%s) - 14400))" "+%Y-%m-%dT-%H:%M:%S")"|jq -r '.SpotPriceHistory[].SpotPrice'|sort -u|tail -n1)
     bidPrice=$(python -c "print $maxiumPriceLastFourHours+$OVERBID")
   # Ends Tricky Bid Calculation.
   #Other variables.
     userdata=""
     if [ -z $USERDATA ];then
        echo "No user data defined"
     else
       userdata=",\"UserData\":\"$USERDATA\""
     fi
     if [ -z $SECURITYGROUPS ];then
        echo "No security groups defined"
     else
       securityGroups=",\"SecurityGroupIds\":[\"$SECURITYGROUPS\"]"
     fi
}

function launchSpot () {
     prepareVariables
     echo "finding newest AMI for provided TAG:$TAG for performing $ACTION"
     newestAMI=$(aws ec2 describe-images --filters Name=image-type,Values=machine Name=is-public,Values=false Name=name,Values="*$TAG*" | jq '.[]|max_by(.CreationDate)|.ImageId'|sed 's/\"//g')
     
     if [ "$newestAMI" == "null" ];then echo "AMI not found with TAG: $TAG" ; echo "failure" ; exit ; fi
     
     echo "Launching a $INSTANCE_TYPE VolumeType $VOLUME_TYPE TAG $TAG AMI $newestAMI bidPrice $bidPrice Zone $ZONE"
     #Echo finding the subnet ID for a given Zone
     vpcID=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=$ZONE" | jq -r .Subnets[].SubnetId)
     spotReq=$(aws ec2 request-spot-instances --spot-price "$bidPrice" --instance-count 1 --type "one-time" --launch-specification " 
	       {$KEYPAIR \"ImageId\":\"$newestAMI\",
	       \"InstanceType\": \"$INSTANCE_TYPE\",
         \"BlockDeviceMappings\": [ 
           {
             \"DeviceName\": \"/dev/sda1\",
             \"Ebs\": { 
               \"VolumeType\": \"$VOLUME_TYPE\" 
             } 
           } 
         ],
	       \"SubnetId\":\"$vpcID\" $userdata $securityGroups }"|jq .SpotInstanceRequests[].SpotInstanceRequestId| sed 's/"//g')
     if [ -z "$TARGET" ];then
       echo " Request $spotReq subbmited"
     else
       echo " Waiting for the spot request to launch an instance"
       sleep 15
       spotInstanceID=$(aws ec2 describe-spot-instance-requests --spot-instance-request-ids $spotReq |jq .SpotInstanceRequests[].InstanceId|sed 's/\"//g')
       echo " Waiting until the instance $spotInstanceID is running ok"
       aws ec2 wait instance-status-ok --instance-ids $spotInstanceID
       echo "registering $spotInstanceID into $TARGET group"
       aws elbv2 register-targets --target-group-arn $TARGET --targets Id=$spotInstanceID
       echo aws elbv2 register-targets --target-group-arn $TARGET --targets Id=$spotInstanceID
       aws ec2 create-tags --resources $spotInstanceID --tags Key=Name,Value="$TAG auto-spot"
     fi
     
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
