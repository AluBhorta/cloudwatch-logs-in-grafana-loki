## req

i want the logs in my cloudwatch log group 'example-lg' to be available on my grafana dashboard that has a loki data source. loki should use a s3 as it's persistent data store.
grafana, loki and fluent-bit are running on eks on a namespace grafana-loki-stack.
2 helm charts were installed: grafana/loki-stack (with fluent-bit set to true) & grafana/grafana.
what's the simplest solution? how does the persistent storage in s3 with loki work? simplify to someone unfamiliar with the stack.

## res

To achieve this setup, you need to follow these steps:

1. Configure Loki to use S3 as its storage backend: Update the `loki-stack` Helm chart's values.yaml file to include the S3 configuration. Add the following to the `loki` section:

   ```yaml
   config:
     schema_config:
       configs:
         - from: "2020-10-01"
           store: aws
           object_store: s3
           schema: v11
           index:
             prefix: index_
             period: 168h

     storage_config:
       aws:
         s3: s3://<your-region>/<your-bucket-name>
         dynamodb:
           dynamodb_url: dynamodb://<your-dynamodb-tablename>

   table_manager:
     retention_deletes_enabled: true
     retention_period: 336h
   ```

   Replace `<your-region>`, `<your-bucket-name>`, and `<your-dynamodb-tablename>` with the appropriate values for your S3 bucket and DynamoDB table. You also need to set AWS access and secret keys as environment variables within the Loki deployment in the EKS cluster.

2. Update the fluent-bit configuration: Edit the `loki-stack` Helm chart's values.yaml file to include the CloudWatch logs input plugin. Add the following to the `fluent-bit` section:

   ```yaml
   config:
     inputs: |
       [INPUT]
         Name cloudwatch_logs
         Tag example-lg
         Region <your-region>
         Log_group_name example-lg
         Log_stream_prefix example-
         storage.total_limit_size 100M
         Role_ARN arn:aws:iam::<your-account-id>:role/<your-role-name>
   ```

   Replace `<your-region>`, `<your-account-id>`, and `<your-role-name>` with the appropriate values for your AWS account.

3. Deploy the updated Helm chart: Apply the updated Helm chart by running the following command:

   ```bash
   helm upgrade --install loki-grafana grafana/loki-stack -f values.yaml --namespace grafana-loki-stack
   ```

4. Configure Grafana to use Loki as a data source: Log in to your Grafana dashboard and add a new data source. Select Loki, and set the URL to the appropriate endpoint for your Loki instance running in EKS (e.g., `http://loki:3100`).

That's it! Once you have completed the above steps, your logs from the CloudWatch log group `example-lg` will be available in Grafana with Loki as the data source, and Loki will use S3 for its persistent storage.

To simplify things for someone unfamiliar with the stack:

- Loki is a log aggregation system that stores your logs efficiently and allows you to query them using Grafana.
- Fluent-bit is a log processor and forwarder that collects logs from various sources and sends them to Loki.
- Grafana is a visualization and analytics tool that displays your logs and metrics in a dashboard.
- In this setup, Fluent-bit collects logs from CloudWatch, sends them to Loki, and Grafana visualizes the logs using Loki as a data source. Loki stores its data in Amazon S3 for persistent storage.
