# setup log generator

You can modify the `deployment.yaml` manifest to include the log-generating script inline and use Fluent Bit to export logs to CloudWatch.

First, create a `fluent-bit-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        Off
        Log_Level     info
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Tag               app.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name           kubernetes
        Match          app.*
        Kube_URL       https://kubernetes.default.svc:443
        Kube_CA_File   /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log      On
        K8S-Logging.Parser On
        K8S-Logging.Exclude On

    [OUTPUT]
        Name              cloudwatch_logs
        Match             app.*
        region            ap-south-1  
        log_group_name    /freelance-client/10/sample-log-generator
        auto_create_group On

  parsers.conf: |
    [PARSER]
        Name         docker
        Format       json
        Time_Key     time
        Time_Format  %Y-%m-%dT%H:%M:%S.%LZ
```

Update the `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
    spec:
      serviceAccountName: cw-logger-sa
      containers:
      - name: log-generator
        image: alpine
        env:
        - name: LOG_INTERVAL
          value: "10"  # Adjust this value to the desired log interval in seconds
        command:
        - /bin/sh
        - -c
        - |
          set -e
          while true; do
            UUID=$(cat /proc/sys/kernel/random/uuid)
            TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
            echo "hi from ${UUID} at ${TIMESTAMP}"
            sleep ${LOG_INTERVAL}
          done
      - name: fluent-bit
        image: fluent/fluent-bit:1.8.9
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        emptyDir: {}
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
```

Apply the manifests:

```bash
kubectl apply -f fluent-bit-configmap.yaml
kubectl apply -f deployment.yaml
```

This configuration will use Fluent Bit to collect logs from the `log-generator` container and send them to the specified CloudWatch log group and log stream. Make sure to update the `region`, `log_group_name`, and `log_stream_name` in the `fluent-bit-configmap.yaml` file according to your requirements.
