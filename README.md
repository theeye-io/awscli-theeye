* [`Based on Comodal Repository`](https://github.com/comodal/alpine-aws-cli/blob/master/Dockerfile) FROM alpine:edge 

This is an alpine aws-cli with [theeye] (https://theeye.io) integration, for providing an easy way to launch your aws-cli commands or provided scripts from any docker machine.
Also you can activate the docker's theeye-agent installed in this Docker. That way you can split your users-roles by limiting their automations to this docker container.


Status: [![Docker Repository on Quay](https://quay.io/repository/theeye/awscli-theeye/status "Docker Repository on Quay")](https://quay.io/repository/theeye/awscli-theeye) 

#Problem
##First issue
I wasn't able to find an easy way for auto-scaling spot instances.
AWS allows me to create an auto-scaling group and It works fine if the spot instance suddenly stops but when if the bid for that instance rises, my spot instances shutdowns and auto-scaling group stops working.
##Second issue
While I was working on a BTC (Bitcoin) which takes at least 3 days to by full synced I faced I need a good backup, that way I can handle a BTC H.A by using spot instances and If some spot instance goes down I only need one or two ours to get it online again.
##Third issue
I tried to snapshot running instances but stoping and starting bitcoind service wasn't a good solution.

#Solution
##I wrote several scripts for performing Daily tasks such as:

*1 - Volume snapshots from AMI tags.
*2 - AMI creation from 1-
*3 - Volume, Snapshots and AMIs Housekeeping.

##Also I created a customized monitor for watching instances inside targetgroup
##Then I created a onetime spotInstance launcher with bid calculation, that way I always get the spot Instances I need to be working.
##Finally I schedule those tasks, I create that monitor and put everything togeter on [Theeye](https://theeye.io)


## Oneshot Docker Run

```sh
docker run -i -t --rm\
 -e AWS_ACCESS_KEY_ID=\
 -e AWS_SECRET_ACCESS_KEY=\
 -e AWS_DEFAULT_REGION=us-east-1\
 -v $PWD:/data\
 -w /data\
  quay.io/theeye/awscli-theeye:latest
```


## Operations supported by custom scripting
### EBS Handle - Supports serveral actions such as: Volume Backup / Snapshots deletion / Attach snapshot as a new volume / Create an AMI from Snapshot and Cleanup unused Volumes

usage: I.E for Volume Backup
```sh
docker run -it --rm\ 
 -e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
 -e AWS_SECRET_ACCESS_KEY=XXXXXXXXXXX \
 -e AWS_DEFAULT_REGION=us-east-1 \  
 quay.io/theeye/awscli:latest scripts/handleEBS.sh --backup=BWS-Private*
```

other valids usages:

    Snapshot all volumes for instances that matches,It requires an instance tag
```sh 
scripts/handleEBS.sh --backup=tag-value IE:  --backup prod* 
``` 
    
    Delete all snapshots older than 7 days by default, It requires a snapshot tag
    
```sh 
scripts/handleEBS.sh --delete=tag-value (optional) --days=NUMBER IE:  --delete=prod* --days=3 
``` 
    
    Attach the last snapshot as a volume to an instance, requieres id-instance and snapshot tag. By default It creates a gp2 volume type.
    
```sh 
scripts/handleEBS.sh --attach=tag-value --instance=instance-id
``` 
    
    Create an AMI from the last snapshot, requires a tag. Optional an instance-name
```sh
 scripts/handleEBS.sh  --create=tag-value (optional) --instance=aNewAMIName 
``` 
    
    *Remove all unused Volumes
```sh 
  scripts/handleEBS.sh --remove=Region , I.E --remove=us-east-1 
```

## Handle Spot Instances
```sh
docker run -it --rm\
-e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
-e AWS_SECRET_ACCESS_KEY=XXXXXXXX \
-e AWS_DEFAULT_REGION=us-east-1 \
  quay.io/theeye/awscli-theeye:latest scripts/handleSpotInstances.sh --launchSpot=YourTag* --instancetype=c3.large --zone=us-east-1e --keypair=YourKey --overbid=0.001
```

other available settings:
```sh
 scripts/handleSpotInstances.sh  --launchSpot=tag-value --instancetype=m1.small --zone=us-east-1e  (optional) --keypair=UseYourKey --targetgroup=arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/my-targets/73e2d6bc24d8a067 --overbid=0.003 --userdata='yourBase64EncodedScript'
```

## Clean Up unused AMIs
```sh
docker run -it --rm\
-e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
-e AWS_SECRET_ACCESS_KEY=XXXXXXXX \
-e AWS_DEFAULT_REGION=us-east-1 \
  quay.io/theeye/awscli-theeye:latest scripts/handleAMIs.sh --launchSpot=YourTag* --instancetype=c3.large --zone=us-east-1e --keypair=YourKey --overbid=0.001
```



### Bonus Tracks:

## Persist Configuration, and mount your path inside the docker for scripting purpouses 

```sh
docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/src -w /src\
  quay.io/theeye/awscli-theeye:latest configure --profile PROFILE_NAME
```
