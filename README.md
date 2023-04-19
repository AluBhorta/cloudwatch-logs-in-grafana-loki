
```sh
helm repo add grafana https://grafana.github.io/helm-charts

helm repo update

kubectl create namespace grafana-loki-stack

helm install loki-stack grafana/loki-stack \
  --namespace grafana-loki-stack \
  -f grafana-loki-stack/values.yaml

helm install grafana grafana/grafana -n grafana-loki-stack

kubectl port-forward service/grafana 3000:80 -n grafana-loki-stack

# then, configure grafana to use loki
```



```
i have a set of apps that store logs to cloudwatch. i want the logs to be accessible and queries using grafana/loki which would run on my eks cluster, using s3 as storage. consider using promtail or fluent-bit as log processor. i want to make sure the timestamp's on my cloudwatch logs match correctly on the logs in grafana. what's the simplest set of steps to achieve this?
```
