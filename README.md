# grafana-loki-fluentd-eks

setup grafana-loki-fluentd stack on eks to analyze logs eg. from aws cloudwatch.

## get started

- setup env vars

  ```sh
  export EKS_CLUSTER_NAME=eks-demo
  export AWS_ACCOUNT=$(aws sts get-caller-identity --output text --query Account --output text)
  ```

- create eks cluster (if it doesn't exist yet)

  ```sh
  eksctl create cluster -f eksctl_cluster.yaml
  ```

- setup cni (eg. flannel)

  ```sh
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  ```

- setup csi (eg. ebs)

  ```sh
  eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $EKS_CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --role-only \
    --role-name AmazonEKS_EBS_CSI_DriverRole

  eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster $EKS_CLUSTER_NAME \
    --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force
  ```

- use terraform to create s3 bucket and iam resources:

  ```sh
  cd terraform

  tf init

  tf apply

  cd ..
  ```

- (optional) setup ingress controller

### deploy grafana-loki-fluentd stack with helm

make sure the `*-values.yaml` files are updated to suit your env.

- create ns:

  ```sh
  k create ns monitoring
  ```

- deploy loki

  ```sh
  helm upgrade --install loki grafana/loki -n monitoring -f loki-values.yaml
  ```

- deploy fluentd

  ```sh
  helm upgrade --install fluentd fluent/fluentd -n monitoring -f fluentd-values.yaml
  ```

- deploy grafana

  ```sh
  helm upgrade --install grafana grafana/grafana -n monitoring -f grafana-values.yaml
  ```

## clean up

in reverse order:

```sh
helm del fluentd grafana loki

# remove ingress controller (if installed)

# delete s3 bucket objects (warning: data loss)
aws s3 rm s3://$LOKI_S3_BUCKET_NAME --recursive

tf destroy

# remove the PVCs (warning: data loss)
k delete pvc -n monitoring --all

eksctl delete addon --cluster $EKS_CLUSTER_NAME --name aws-ebs-csi-driver

eksctl delete cluster -f eksctl_cluster.yaml
```

# notes

- `start_time` in fluentd can be used to specify the oldest logs to retrieve
  - note: loki must have `reject_old_samples: false` or a very large `reject_old_samples_max_age`
- make sure to use new PVCs or remove the old ones for loki. otherwise you might not get the expected data.
  - also consider deleting s3 bucket data

# refs

- https://grafana.com/docs/loki/latest/configuration
- https://github.com/fluent-plugins-nursery/fluent-plugin-cloudwatch-logs#in_cloudwatch_logs
- https://github.com/grafana/loki/tree/main/production/terraform/modules/s3
