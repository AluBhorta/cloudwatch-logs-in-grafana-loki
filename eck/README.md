# ECK

```sh
# operator
kubectl create -f https://download.elastic.co/downloads/eck/2.7.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.7.0/operator.yaml


# ns
k create ns eck

# es
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.7.1
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false

spec:
  nodeSets:
  - name: default
    count: 1
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 5Gi
        storageClassName: standard
EOF


# kibana
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 8.7.1
  count: 1
  elasticsearchRef:
    name: quickstart
  http:
    service:
      spec:
        type: LoadBalancer    
EOF
```


- ingress/http access for kibana
  - https://github.com/elastic/cloud-on-k8s/issues/2118
