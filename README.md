# Docker Compose Playground

Curated Docker Compose definitions for quickly standing up common infrastructure stacks (observability, API Gateways, local Kubernetes, etc.). Each stack lives in its own folder so you can run exactly what you need without extra scaffolding.

## Prerequisites

- Docker Engine with the Compose plugin (v2) installed.
- Enough local disk space for container volumes (some stacks persist databases or registry layers).

## How to Use

1. `cd` into the folder that contains the stack you want to run.
2. Review the stack-specific README to learn about required secrets, environment variables, or exposed ports.
3. Start it with `docker compose up -d --force-recreate` (unless the stack README states otherwise).
4. Tear down with `docker compose down -v` once you are done testing.

## Stack Catalog

| Stack | Path | Description | Default Ports / Notes |
| --- | --- | --- | --- |
| Grafana | [`grafana/docker-compose.yml`](grafana/docker-compose.yml) | Single Grafana instance with the admin password set to `admin`. Useful for pointing at any Prometheus endpoint running on your host (see datasource tip inside `grafana/README.md`). | Exposes Grafana on `localhost:9001`. Adds `host.docker.internal` entry so dashboards can reach services on the host. |
| Prometheus | [`prometheus/docker-compose.yml`](prometheus/docker-compose.yml) | Prometheus server reading its configuration from the bundled `prometheus/` folder. Lifecycle endpoints are enabled so you can hot-reload rules. | Exposes Prometheus UI/API on `localhost:9000`. Mounts `./prometheus` into the container for rules and scrape configs. |
| Kong + Postgres + Konga | [`kong/docker-compose.yml`](kong/docker-compose.yml) | Production-like Kong API Gateway wired to Postgres for state and bundled with the Konga UI. Requires secrets for database password and JWT token. | Listen ports: `8000/8443` (proxy), `8001/8002` (admin), `5432` (Postgres), `1337` (Konga). Create `POSTGRES_PASSWORD` and `TOKEN_SECRET` files before running. |
| k3s + Istio lab | [`k8s/istio/docker-compose.yaml`](k8s/istio/docker-compose.yaml) | Spins up a lightweight k3s cluster with an Istio control plane, Helm bootstrapper, and in-cluster container registry. Ideal for experimenting with Istio ingress and observability add-ons locally. | Set `KUBECONFIG`, `K3S_API_PORT`, `INGRESS_HTTP_PORT`, `INGRESS_HTTPS_PORT` as needed (defaults shown inside the compose file). Follow [`k8s/istio/README.md`](k8s/istio/README.md) for install/teardown, validation, and registry usage tips. |

## Adding More Stacks

When contributing a new Compose definition:

- Place it in its own folder with a descriptive name (e.g., `postgres/`, `open-telemetry/`).
- Include a short `README.md` explaining prerequisites, configuration, and common commands.
- Update this root README with a new entry under “Stack Catalog”.

## License

This repository is distributed under the [MIT License](LICENSE).
