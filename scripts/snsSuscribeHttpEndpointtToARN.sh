#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ] ;then
       echo "Please execute indicating topoc and endpoint I.E $0 arn:aws:sns:us-east-1:4333333334f5:events http://$(hostname)/events/update"
       exit
fi
/usr/bin/aws sns subscribe --topic-arn "$1"  --protocol http --notification-endpoint "$2"
