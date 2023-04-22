# grafana-loki-fluentd-eks

setup grafana-loki-fluentd stack on eks to analyze logs eg. from aws cloudwatch.

## get started 🚀

- setup env vars

  ```sh
  export EKS_CLUSTER_NAME=eks-demo
  export AWS_ACCOUNT=$(aws sts get-caller-identity --output text --query Account --output text)
  export K8S_NAMESPACE=monitoring-stack
  ```

- create eks cluster (if it doesn't exist yet)

  ```sh
  eksctl create cluster -f eksctl_cluster.yaml
  ```

- ensure oidc provider is associated

  ```sh
  eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve
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

- use terraform to create necessary aws resources like s3 bucket, iam roles, etc.:

  ```sh
  cd terraform

  tf init

  tf apply

  cd ..
  ```

  note the output values. you'll need them to update helm chart values.

- (optional) generate fake logs in cloudwatch:

  ```sh
  ./cw_logger.sh
  ```

- (optional) setup ingress controller

### deploy grafana-loki-fluentd stack with helm ☸️

- make sure the `*-values.yaml` files are updated to suit your env.

  minimum changes needed:

  - loki values
    - s3 bucket name
    - aws region
    - service account role arn

- create ns:

  ```sh
  k create ns $K8S_NAMESPACE
  ```

- deploy loki

  ```sh
  helm upgrade --install loki grafana/loki -n $K8S_NAMESPACE -f loki-values.yaml
  ```

- deploy fluentd

  - create an iam user in the AWS account that contains the log group with the following policy. make sure to replace the aws region, aws account and log group.
    ```json
    {
      "Statement": [
        {
          "Sid": "consumer",
          "Action": ["logs:DescribeLogStreams", "logs:GetLogEvents"],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:logs:<AWS_REGION>:<AWS_ACCOUNT>:log-group:<CW_LOG_GROUP>:*"
          ]
        }
      ],
      "Version": "2012-10-17"
    }
    ```
  - create access+secret key pair for the user
  - update the [fluentd-aws-secrets.yaml](./fluentd-aws-secrets.yaml) with your correct values
  - create the secret object:
    ```sh
    kubectl apply -n $K8S_NAMESPACE -f fluentd-aws-secrets.yaml
    ```
  - deploy helm chart

    ```sh
    helm upgrade --install fluentd fluent/fluentd -n $K8S_NAMESPACE -f fluentd-values.yaml
    ```

- deploy grafana

  ```sh
  helm upgrade --install grafana grafana/grafana -n $K8S_NAMESPACE -f grafana-values.yaml
  ```

- login to grafana on http://localhost:3000 with the password to get up and running!

  ```sh
  kubectl get secret -n $K8S_NAMESPACE grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

  kubectl port-forward -n $K8S_NAMESPACE service/grafana 3000:80
  ```

## clean up 🧹

in reverse order:

```sh
helm del fluentd grafana loki -n $K8S_NAMESPACE

# remove ingress controller (if installed)

# delete s3 bucket objects (warning: data loss)
aws s3 rm s3://$LOKI_S3_BUCKET_NAME --recursive

tf destroy

# remove the PVCs (warning: data loss)
k delete pvc -n $K8S_NAMESPACE --all

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
