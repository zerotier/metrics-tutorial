#!/bin/bash

set -euxo pipefail

ZT_CONTAINER=metrics-tutorial-zerotier-1
WEB_CONTAINER=metrics-tutorial-webhost-1

PROM_CONFIG_PATH=./config/prometheus/prometheus.yml

export ZT_METRICS_TOKEN=$(docker exec $ZT_CONTAINER \
    cat /var/lib/zerotier-one/metricstoken.secret)

export ZT_ADMIN_TOKEN=$(docker exec $ZT_CONTAINER \
    cat /var/lib/zerotier-one/authtoken.secret)

export ZT_NODE_ID=$(docker exec $ZT_CONTAINER \
    zerotier-cli info | cut -d ' ' -f 3)

NETWORK_CONFIG_JSON=$(cat <<END
{
  "name": "metrics-demo",
  "private": false,
  "ipAssignmentPools": [
    {
      "ipRangeStart": "10.10.0.1",
      "ipRangeEnd": "10.10.0.254"
    }
  ],
  "v4AssignMode": true
}
END)

NETWORK_INFO=$(docker exec $ZT_CONTAINER curl -H "X-ZT1-Auth: $ZT_ADMIN_TOKEN" \
  -d "$NETWORK_CONFIG_JSON" \
  http://localhost:9993/controller/network/${ZT_NODE_ID}______)

NETWORK_ID=$(echo "$NETWORK_INFO" | jq -r .nwid)
docker exec $ZT_CONTAINER zerotier-cli join $NETWORK_ID
docker exec $WEB_CONTAINER zerotier-cli join $NETWORK_ID

PROM_CONFIG=$(cat <<END
scrape_configs:
- job_name: zerotier-one
  honor_labels: true
  scrape_interval: 15s
  metrics_path: /metrics
  static_configs:
  - targets:
    - $ZT_CONTAINER:9993
    labels:
      group: zerotier-one
      node_id: $ZT_NODE_ID
  authorization:
    credentials: $ZT_METRICS_TOKEN
END)

echo "$PROM_CONFIG" > $PROM_CONFIG_PATH
docker cp $PROM_CONFIG_PATH metrics-tutorial-prometheus-1:/prometheus/prometheus.yml
sleep 1
docker-compose restart prometheus
