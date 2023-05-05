FROM fluentd:v1.16-1

USER root

# Install the plugins you need, separated by spaces.
RUN fluent-gem install fluent-plugin-cloudwatch-logs fluent-plugin-grafana-loki

USER fluent
