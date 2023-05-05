
```sh
docker run -d \
  --name fluentd \
  -p 24224:24224 \
  -p 24224:24224/udp \
  -v `pwd`/logs:/fluentd/log \
  fluentd:v1.16-1
```

