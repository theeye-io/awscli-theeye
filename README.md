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
### EBS Handle - Volume Backup / Snapshots deletion / Attach snapshot as a new volume
*Volume Backup
```sh
docker run -it --rm\ 
 -e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
 -e AWS_SECRET_ACCESS_KEY=XXXXXXXXXXX \
 -e AWS_DEFAULT_REGION=us-east-1 \  
 quay.io/theeye/awscli:latest scripts/handleEBS.sh --backup=BWS-Private*
```


*Snapshots Cleanup.Remove snapshots older than 5 days.:
```sh
docker run -it --rm \ 
-e AWS_ACCESS_KEY_ID=XXXXXXX \ 
-e AWS_SECRET_ACCESS_KEY=XXXXXXXXX \
-e AWS_DEFAULT_REGION=us-east-1 \
quay.io/theeye/awscli-theeye:latest scripts/handleEBS.sh --delete=BWS-P* --days=1
```

*Create volume from saved snapshot and attach to instance
```sh
docker run -it --rm\
-e AWS_ACCESS_KEY_ID=XXXXXXXXXXX \
-e AWS_SECRET_ACCESS_KEY=XXXXXXXX \
-e AWS_DEFAULT_REGION=us-east-1 \
  quay.io/theeye/awscli-theeye:latest scripts/handleEBS.sh --attach=BWS-Private* --instance=Instance-ID
```


### Bonus Tracks:

## Persist Configuration, and mount your path inside the docker for scripting purpouses 

```sh
docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/src -w /src\
  quay.io/theeye/awscli-theeye:latest configure --profile PROFILE_NAME
```
