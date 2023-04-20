# hell

## get started

- setup env vars

```sh
export EKS_CLUSTER_NAME=eks-demo
export AWS_ACCOUNT=$(aws sts get-caller-identity --output text --query Account --output text)
```

- create eks cluster (if it doesn't exist yet)

- setup cni (eg. flannel)

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

- setup oidc provider

```sh
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve
```

- create storage bucket and iam role for loki with tf.

```sh
oidc_id=$(aws eks describe-cluster --name eks-demo --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

cd terraform

tf init

tf apply -var oidc_id=$oidc_id

cd ..
```

further [ref](https://github.com/grafana/loki/tree/main/production/terraform/modules/s3).

- deploy loki with helm (NOTE: update the bucket name, and the role arn in values)

```sh
k create ns monitoring

# update the loki-values with the bucket name

helm upgrade --install loki grafana/loki -n monitoring -f loki-values.yaml
```

- deploy grafana

```sh
helm upgrade --install grafana grafana/grafana -n monitoring -f grafana-values.yaml 
```

- deploy log forwarder eg. fluent-bit

- (optional) setup ingress controller

## clean up

in reverse order

```sh
# ...


eksctl delete addon --cluster $EKS_CLUSTER_NAME --name aws-ebs-csi-driver # --preserve

# ...
```
