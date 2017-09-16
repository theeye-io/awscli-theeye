* [`Based on Comodal Repository`](https://github.com/comodal/alpine-aws-cli/blob/master/Dockerfile) FROM alpine:edge 

This is an alpine aws-cli with theeye integration, that way you can launch you aws-cli commands from any theeye managed host with docker installed.
Also you can activate the docker's theeye-agent installed in this Docker. That way you can split your users-roles by limiting their automations to this docker container.


Status:
[![Docker Repository on Quay](https://quay.io/repository/theeye/awscli-theeye/status "Docker Repository on Quay")](https://quay.io/repository/theeye/awscli-theeye) 

## Supported Tags

* [`latest`](https://github.com/comodal/alpine-aws-cli/blob/master/Dockerfile) FROM alpine:edge

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
    
```sh --backup=tag-value IE:  --backup prod* ``` 
    
    Delete all snapshots older than 7 days by default, It requires a snapshot tag
    
```sh --delete=tag-value (optional) --days=NUMBER IE:  --delete=prod* --days=3 ``` 
    
    Attach the last snapshot as a volume to an instance, requieres id-instance and snapshot tag. By default It creates a gp2 volume type.
    
  ```sh --attach=tag-value --instance=instance-id``` 
    
    Create an AMI from the last snapshot, requires a tag. Optional an instance-name
```sh  --create=tag-value (optional) --instance=aNewAMIName ``` 
    
    *Remove all unused Volumes
  ```sh --remove=Region , I.E --remove=us-east-1 ```

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
 --launchSpot=tag-value --instancetype=m1.small --zone=us-east-1e  (optional) --keypair=UseYourKey --targetgroup=arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/my-targets/73e2d6bc24d8a067 --overbid=0.003 --userdata='yourBase64EncodedScript'

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
