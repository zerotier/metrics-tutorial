#!/bin/bash

set -euo pipefail

_=$(jq --version)
if [ $? != 0 ]; then
  echo "Missing 'jq' in path; exiting"
fi

CTRL_CONTAINER=metrics-tutorial-zerotier-1
WEB_CONTAINER=metrics-tutorial-webhost-1

PROM_CONFIG_PATH=./config/prometheus/prometheus.yml

get_zt_node_id() {
  CONTAINER=$1
  echo $(docker exec $CONTAINER zerotier-cli info | cut -d ' ' -f 3)
}

get_zt_token() {
  CONTAINER=$1
  TOKEN_KIND=${2:='metrics'}
  TOKEN_PATH="/var/lib/zerotier-one/${TOKEN_KIND}token.secret"

  echo $(docker exec $CONTAINER cat $TOKEN_PATH)
}

get_zt_ipaddr() {
  CONTAINER=$1
  NWID=$2

  echo $(docker exec $CONTAINER zerotier-cli get $NWID ip | egrep '^\d\d\d.')
}

export CTRL_NODE_ID=$(get_zt_node_id $CTRL_CONTAINER)
export WEB_NODE_ID=$(get_zt_node_id $WEB_CONTAINER)

export CTRL_METRICS_TOKEN=$(get_zt_token $CTRL_CONTAINER 'metrics')
export CTRL_ADMIN_TOKEN=$(get_zt_token $CTRL_CONTAINER 'auth')
export WEB_METRICS_TOKEN=$(get_zt_token $WEB_CONTAINER 'metrics')

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

NETWORK_INFO=$(docker exec $CTRL_CONTAINER curl -H "X-ZT1-Auth: $CTRL_ADMIN_TOKEN" \
  -d "$NETWORK_CONFIG_JSON" \
  http://localhost:9993/controller/network/${CTRL_NODE_ID}______)

NETWORK_ID=$(echo "$NETWORK_INFO" | jq -r .nwid)
docker exec $CTRL_CONTAINER zerotier-cli join $NETWORK_ID
docker exec $WEB_CONTAINER zerotier-cli join $NETWORK_ID

export CTRL_ZT_IPADDR=$(get_zt_ipaddr $CTRL_CONTAINER $NETWORK_ID)
export WEB_ZT_IPADDR=$(get_zt_ipaddr $WEB_CONTAINER $NETWORK_ID)

PROM_CONFIG=$(cat <<END
scrape_configs:
- job_name: zt-controller
  honor_labels: true
  scrape_interval: 15s
  static_configs:
  - targets:
    - $CTRL_CONTAINER:9993
    labels:
      group: zerotier-one
      node_id: $CTRL_NODE_ID
      network_id: $NETWORK_ID
  authorization:
    credentials: $CTRL_METRICS_TOKEN
- job_name: webhost
  honor_labels: true
  scrape_interval: 15s
  static_configs:
  - targets:
    - $WEB_CONTAINER:9993
    labels:
      group: zerotier-one
      node_id: $WEB_NODE_ID
      network_id: $NETWORK_ID
  authorization:
    credentials: $WEB_METRICS_TOKEN
END)

echo "$PROM_CONFIG" > $PROM_CONFIG_PATH
docker cp $PROM_CONFIG_PATH metrics-tutorial-prometheus-1:/prometheus/prometheus.yml
sleep 1
docker-compose restart prometheus

HOST_INFO=$(cat <<END
controller:
  node_id: $CTRL_NODE_ID
  zt_ip: $CTRL_ZT_IPADDR
webhost:
  node_id: $WEB_NODE_ID
  zt_ip: $WEB_ZT_IPADDR
END)

echo "$HOST_INFO"