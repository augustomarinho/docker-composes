# Spinning up another local cluster
1. Open a new shell (so the original cluster keeps its environment).
2. Pick a new kubeconfig directory plus different host ports:
   ```bash
   export KUBECONFIG_DIR=$PWD/cluster-b-kubeconfig
   export K3S_API_PORT=7443
   export INGRESS_HTTP_PORT=8080
   export INGRESS_HTTPS_PORT=8443
   docker compose --project-name cluster-b up -d --force-recreate
   ```
3. Watch the logs until Istio is ready:
   ```bash
   docker compose --project-name cluster-b logs -f helm-bastion
   ```
4. Point `KUBECONFIG` at the second cluster and verify it with `kubectl get nodes`.

# Connecting clusters
1. Merge kubeconfigs so `kubectl` and `istioctl` can reach both clusters:
   ```bash
   export CLUSTER_A_KUBECONFIG=$PWD/cluster-a-kubeconfig/kubeconfig.yaml
   export CLUSTER_B_KUBECONFIG=$PWD/cluster-b-kubeconfig/kubeconfig.yaml
   KUBECONFIG=$CLUSTER_A_KUBECONFIG:$CLUSTER_B_KUBECONFIG \
     kubectl config view --flatten > ~/.kube/multicluster
   export KUBECONFIG=~/.kube/multicluster
   kubectl config get-contexts
   ```
2. Exchange Istio control-plane secrets so each cluster can trust the other (replace context names with the values printed above):
   ```bash
   istioctl x create-remote-secret --context cluster-a --name cluster-a \
     | kubectl apply --context cluster-b -f -
   istioctl x create-remote-secret --context cluster-b --name cluster-b \
     | kubectl apply --context cluster-a -f -
   ```
3. Confirm that Istio discovers endpoints in both clusters by checking `istio-system` pods and the remote secrets (`kubectl get secrets -n istio-system --context cluster-a`).

# Tearing clusters down
```bash
docker compose --project-name cluster-a down -v
docker compose --project-name cluster-b down -v
```
