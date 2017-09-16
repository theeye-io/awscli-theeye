#!/bin/bash
#Thanks to https://devopsideas.com/automate-ebs-volume-snapshot/

function help () {
   echo "help:
   Launch Spot Instance By using TAG. It finds the Last AMI snapshot, Requires Zone, Optional TargetGroup for ELB, and overBid ( It calculates the biggest price for the past 4 hours plus this setting default is 0.002).
    Delete all snapshots older than 7 days by default, It requires a snapshot tag
                 --delete=tag-value (optional) --days=NUMBER IE: $1 --delete=prod* --days=3  
    "
   exit 1
}

#Params Stuff
for i in "$@"
do
  case $i in
    --delete=*)
      TAG="${i#*=}"
      ACTION=delete
    ;;
    --days=*)
      AGE="${i#*=}"
      if ! [[ $AGE =~ ^[0-9]+$ ]] ; then
        echo "Age is invalid Asuming default 7"
        AGE=7
      fi
    ;;
  esac
done

#functions
function delete_amis () {

  flag=0
  for instance in $(aws ec2 describe-images --filters Name=image-type,Values=machine Name=is-public,Values=false Name=name,Values="$TAG" | jq '.Images[].ImageId'|sed 's/\"//g')
  do
      echo "verifying $instance"

      AMICREATIONDATE="$(aws ec2 describe-images --image-ids $instance | jq '.Images[].CreationDate'|sed 's/\"//g' | cut -d T -f1 | sed 's/\"//g')"
      STARTDATE=$(date +%s)
      ENDDATE="$(date -d "$AMICREATIONDATE" +%s)"
      INTERVAL=$(( (STARTDATE - ENDDATE) / (60*60*24) ))

      if (($INTERVAL >= $AGE ))
      then
        echo "Deregistering AMI --> $instance wich is older than $AGE days"
	aws ec2 deregister-image --image-id $instance
      fi

  flag=1
  done
  
  if [ $flag -eq 0 ];then
    echo "I was unable to find any image by using $TAG as filter"
  fi
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

"delete")
  if [ -z $AGE ];
  then
    echo "--days not defined, asuming defaults which is 7"
    AGE=7
  fi
  delete_amis
;;


*)
  help "$@"
;;

esac 
