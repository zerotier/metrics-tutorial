#!/bin/bash

set -euxo pipefail

docker-compose down -v

rm -f config/prometheus/prometheus.yml
