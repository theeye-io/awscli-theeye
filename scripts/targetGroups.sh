echo use by: $0 arnID numberOfDesiredInstances
if [ -z $1 ];then
	echo "Target group ARN wasnt defined"
	exit 1
fi
number=3
if [ -z $2 ];then
        echo "Number of healthy instances wasnt defined using 3 by default"
else 
number=$2
fi


healthyInstances=$(aws elbv2 describe-target-health --target-group-arn $1|jq .TargetHealthDescriptions[].TargetHealth.State|grep healthy|wc -l)
status="normal"
if [ $number -gt $healthyInstances ];then
 status="failure"
fi
echo "$healthyInstances are running at $1 TargetGroup"
echo "$status"

