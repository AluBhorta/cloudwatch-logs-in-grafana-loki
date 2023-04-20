
setup logging from eks containers to CW

ref: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html

- create new ns 

```
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml
```

- create new configmap

```sh
ClusterName=eks-demo
RegionName=ap-south-1
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
kubectl create configmap fluent-bit-cluster-info \
--from-literal=cluster.name=${ClusterName} \
--from-literal=http.server=${FluentBitHttpServer} \
--from-literal=http.port=${FluentBitHttpPort} \
--from-literal=read.head=${FluentBitReadFromHead} \
--from-literal=read.tail=${FluentBitReadFromTail} \
--from-literal=logs.region=${RegionName} -n amazon-cloudwatch
```

In this command, the FluentBitHttpServer for monitoring plugin metrics is on by default. To turn it off, change the third line in the command to FluentBitHttpPort='' (empty string) in the command.

Also by default, Fluent Bit reads log files from the tail, and will capture only new logs after it is deployed. If you want the opposite, set FluentBitReadFromHead='On' and it will collect all logs in the file system.

- deploy fluent bit (optimized)

```
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

---

# iam roles for service accounts in eks

https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html

## creating oidc provider for eks

get id:
oidc_id=$(aws eks describe-cluster --name my-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

check if already exists:
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

create if not:
eksctl utils associate-iam-oidc-provider --cluster my-cluster --approve

## associate service account

NOTE: create your own iam policy or iam role with the necessary permissions, and attach it to the command above with '--attach-policy-arn' or '--role-name' 

create the SA:
eksctl create iamserviceaccount \
	--name cw-logger-sa \ 
	--namespace default \
	--cluster eks-demo \ 
	--attach-policy-arn "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" \ 
	--approve






