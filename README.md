# ZeroTier Observability Metrics Tutorial

## Preparation

```

$ docker-compose up -d
$ ./setup.sh

```

## Grafana Setup

Next, open `http://localhost:3000/` in your browser and follow the steps below to configure dashboards.

1. Login (admin/admin; set a new password or click 'skip')
2. Connections -> Data Sources -> New Data Source
3. Select 'Prometheus' (first option)
4. Set the prometheus server URL: `http://metrics-tutorial-prometheus-1:9090`
5. Click 'Save and test'; then 'Explore view'
6. 

## Cleanup

```

$ ./cleanup.sh

```