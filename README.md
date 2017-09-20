* [`Based on Comodal Repository`](https://github.com/comodal/alpine-aws-cli/blob/master/Dockerfile) FROM alpine:edge 

This is an alpine based docker image with aws-cli installed created to provide aws-cli's commands and scripts easily and optionally from [theeye.io] (https://theeye.io).

Status: [![Docker Repository on Quay](https://quay.io/repository/theeye/awscli-theeye/status "Docker Repository on Quay")](https://quay.io/repository/theeye/awscli-theeye) 

# Problem

## First issue
I wasn't able to find out an easy way for auto-scaling spot instances.
AWS allows me to create an auto-scaling group which handles spot instances downtimes by relaunching them whith your preferred settings until your bid offer is below the market price then your spot instance is going to be shut down and your auto-scaling group becomes unusable.

## Second issue

While I was working on a BTC (Bitcoind) devops I find out that it takes at least 3 days to by full synced with the blockchain, and considering BTC requirements provide it with a three load balanced nodes would become expensive, so if I can start from a less than 24hs. snapshot and running this H.A using spot instances I would be repaying my job in three months.

## Third issue
I tried to snapshot the running instances but it cause an instance interruption that sometimes forces me to resync the local bitcoin "database" and that situation was unacceptable.

# Solution

I wrote some uggly bash scripting for performing these daily tasks:

* 1 - Volume snapshots from AMI tags.
* 2 - AMI creation from 1-
* 3 - Volume, Snapshots and AMIs Housekeeping.
* 4 - TargetGroups monitoring.
* 5-  SpotInstance launch with bid calculation.
 
Finally I put all this thing to orchestate by adding the monitor defined in *4 into [Theeye](https://theeye.io) and handling It's events to execute *5. Also tasks 1 to 3 were scheduled.



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
### EBS Handle - Supports serveral actions such as: Volume Backup / Snapshots deletion / Attach snapshot as a new volume / 

### Create an AMI from Snapshot and Cleanup unused Volumes

usage: I.E for Volume Backup

```sh
docker run -it --rm\ 
 -e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
 -e AWS_SECRET_ACCESS_KEY=XXXXXXXXXXX \
 -e AWS_DEFAULT_REGION=us-east-1 \  
 quay.io/theeye/awscli:latest scripts/handleEBS.sh --backup=BWS-Private*
```

### Other valids usages:

* Snapshot all volumes for instances that matches,It requires an instance tag

```sh 
scripts/handleEBS.sh --backup=tag-value IE:  --backup prod* 
``` 
    
* Delete all snapshots older than 7 days by default, It requires a snapshot tag
    
```sh 
scripts/handleEBS.sh --delete=tag-value (optional) --days=NUMBER IE:  --delete=prod* --days=3 
``` 
    
* Attach the last snapshot as a volume to an instance, requieres id-instance and snapshot tag. By default It creates a gp2 volume type.
    
```sh 
scripts/handleEBS.sh --attach=tag-value --instance=instance-id
``` 
    
* Create an AMI from the last snapshot, requires a tag. Optional an instance-name

```sh
 scripts/handleEBS.sh  --create=tag-value --volumesize=400 (in GB)  (optional) --instance=aNewAMIName 
``` 
    
 * Remove all unused Volumes

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

## Monitor Healthy instances for a given targetGroup and desired instances
bash targetGroups.sh arn:aws:elasticloadbalancing:us-east-1:xxxxxx:targetgroup/xxxxxx/xxxxx 3

## Clean Up unused AMIs
```sh
docker run -it --rm\
-e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
-e AWS_SECRET_ACCESS_KEY=XXXXXXXX \
-e AWS_DEFAULT_REGION=us-east-1 \
  quay.io/theeye/awscli-theeye:latest scripts/handleAMIs.sh --delete=Prod* --days=3
```

### Bonus Tracks:

## Persist Configuration, and mount your path inside the docker for scripting purpouses 

```sh
docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/src -w /src\
  quay.io/theeye/awscli-theeye:latest configure --profile PROFILE_NAME
```
