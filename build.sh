#! /bin/sh

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --output type=local,dest=./dist \
   -t haproxy-static:3.3 .