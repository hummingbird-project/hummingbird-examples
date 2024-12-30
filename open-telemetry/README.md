# OpenTelemetry

Integrate with OpenTelemetry using [swift-otel](https://github.com/swift-otel/swift-otel).

## Server App

The example has three routes to test

- GET / : returns "Hello!"
- GET /test/{param} : returns text including {param}
- POST /wait?time=value : Add a child span and wait for period defined by time query parameter

## Docker compose

The example also comes with a docker-compose file that starts up an OTel collector to collect metrics and traces from the application. This is then forwarded onto Prometheus and Jager instances. You can view the metrics from the Prometheus endpoint `http://localhost:9090`. You can view the traces from the Jaeger endpoint `http://loaclhost:16686`. You can start all of these using

```
docker compose up
```

Everything is stored in shared volumes so data will persist between docker compose sessions.

### Grafana

There is also a Grafana service included that will take results from both the Prometheus and Jaeger services. The Grafana endpoint is `http://localhost:3000`. When stating up Grafana it will ask for a username and password. You can use `admin` for both.
