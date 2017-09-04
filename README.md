* [`Based on`](https://github.com/comodal/alpine-aws-cli/blob/master/Dockerfile) FROM alpine:edge

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
  theeye-io-team/awscli-theeye:latest
```

## Persist Configuration

```sh
docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/data\
 -w /data\
  theeye-io-team/awscli-theeye:latest configure --profile PROFILE_NAME
```

### Shell Alias

```sh
alias aws="docker run -i -t --rm\
 -v $HOME/.aws:/home/aws/.aws\
 -v $PWD:/data\
 -w /data\
  theeye-io-team/awscli-theeye:latest "
```
