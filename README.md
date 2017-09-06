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

## Persist Configuration

```sh
docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/data\
 -w /data\
  quay.io/theeye/awscli-theeye:latest configure --profile PROFILE_NAME
```

### Shell Alias

```sh
alias aws="docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/data\
 -w /data\
  quay.io/theeye/awscli-theeye:latest "
```

### Bonus Tracks:

*Backup Instance volumes by matching tag-name value:
```sh
docker run -it --rm\
 -e AWS_ACCESS_KEY_ID=\
 -e AWS_SECRET_ACCESS_KEY=\
 -e AWS_DEFAULT_REGION=us-east-1\
 -v $PWD:/data\
 -w /data\
  quay.io/theeye/awscli-theeye:latest scripts/volumeSnapshot.sh backup Prod*
```
