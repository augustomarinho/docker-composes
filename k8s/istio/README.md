# Install kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv ./kubectl ~/.local/bin/kubectl
kubectl version --client
```

# Prepare environment
1. Ensure Docker with the Compose plugin is installed.
2. Decide where the cluster should write its kubeconfig and which host ports it should expose, then **export** the corresponding environment variables before running `docker compose`:
   ```bash
   export KUBECONFIG=$PWD/cluster-a-kubeconfig/kubeconfig.yaml
   export K3S_API_PORT=6443
   export INGRESS_HTTP_PORT=80
   export INGRESS_HTTPS_PORT=443
   ```
   If you omit any of these exports, the Compose file falls back to its defaults (`./cluster-a-kubeconfig`, `6443`, `80`, `443` respectively). The `cluster-a` portion matches the Compose project name supplied in the commands below (`docker compose --project-name cluster-a ...`), so keep them in sync if you pick a different project name.
3. The server now generates and stores the cluster token in its persistent volume, and the agent automatically mounts that volume read-only to retrieve `/var/lib/rancher/k3s/server/node-token`, so no manual `K3S_TOKEN` export is required. If you need the token to add additional nodes, grab it via `docker compose exec k3s-server cat /var/lib/rancher/k3s/server/node-token`.

# Bring up the first cluster
```bash
docker compose --project-name cluster-a up -d --force-recreate
```

Follow the bootstrap logs until the Istio add-ons finish:
```bash
docker compose --project-name cluster-a logs -f helm-bastion
```

# Use the kubeconfig
```bash
kubectl get nodes
```

# Validate Istio installation
Run after `helm-bastion` reports success:
```bash
curl -sv -HHost:httpbin.example.com "http://localhost:${INGRESS_HTTP_PORT:-80}/status/200"
```

# Access Grafana, Prometheus and Kiali
```bash
INGRESS_IP=$(kubectl -n istio-ingress get service istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana    http://grafana.${INGRESS_IP}.nip.io"
echo "Prometheus http://prometheus.${INGRESS_IP}.nip.io"
echo "Kiali      http://kiali.${INGRESS_IP}.nip.io"
```

# Tearing cluster down
```bash
docker compose --project-name cluster-a down -v
```

# Use the built-in local registry
A registry container is part of the Compose stack (port `5000` on the host, service name `local-registry`). Both the server and agent mount `registries.yaml`, so any Kubernetes image reference that points to `localhost:5000/...` will transparently hit the in-cluster registry.

Workflow:
```bash
docker tag <IMAGE-ID> localhost:5000/java-k8s-probes:1.0.0
docker push localhost:5000/java-k8s-probes:1.0.0
# deploy workloads that reference image: localhost:5000/java-k8s-probes:1.0.0
```
Because the registry runs on the same Docker network, k3s pulls the image without additional `ctr images import` commands.


# References
- Istio multi-cluster install: https://istio.io/latest/docs/setup/install/multicluster/
- Install Kiali: https://istio.io/latest/docs/ops/integrations/kiali/
- Install Prometheus: https://istio.io/latest/docs/ops/integrations/prometheus/
- Install Grafana: https://istio.io/latest/docs/ops/integrations/grafana/
- Expose observability UIs with Istio: https://istio.io/latest/docs/tasks/observability/gateways/
