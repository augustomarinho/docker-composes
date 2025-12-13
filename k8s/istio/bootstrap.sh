#!/bin/bash

set -o errexit ; set -o nounset; set -o pipefail

echo "Bootstrap sequence started, waiting 30s for the API server to settle..."
sleep 30

cp /opt/kubeconfig/kubeconfig.yaml /root/
echo "kubeconfig.yaml configured"

kubectl config set-cluster default --server=https://k3s-server:6443 --insecure-skip-tls-verify
echo "K8s cluster URL configured"

echo "Installing Istio from https://istio.io/latest/docs/setup/install/helm/"

echo "Adding Istio in Helm Repository"
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
echo "Istio configured as a Helm Repository"

echo "Installing Istiod"
kubectl create namespace istio-system 2>/dev/null || echo "Namespace istio-system already exists"
helm install istio-base istio/base -n istio-system --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --wait
echo "Istiod installed"

echo "Creating Istio Ingress"
kubectl create namespace istio-ingress 2>/dev/null || echo "Namespace istio-ingress already exists"
helm install istio-ingress istio/gateway -n istio-ingress --wait
echo "Istio Ingress created"

echo "Istio installed"

echo "Installing Gateway API CRDs"
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
{ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl apply -f -; }
echo "Gateway API CRDs installed"

echo "Installing Kiali"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/kiali.yaml

echo "Installing Prometheus"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml

echo "Installing Grafana"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/grafana.yaml

echo "Installing DemoApp"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/httpbin/httpbin.yaml

echo "Exposing Grafana, Prometheus and Kiali"
export INGRESS_HOST=$(kubectl -n istio-ingress get service istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_DOMAIN=${INGRESS_HOST}.nip.io

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: grafana-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 80
      name: http-grafana
      protocol: HTTP
    hosts:
    - "grafana.${INGRESS_DOMAIN}"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grafana-vs
  namespace: istio-system
spec:
  hosts:
  - "grafana.${INGRESS_DOMAIN}"
  gateways:
  - grafana-gateway
  http:
  - route:
    - destination:
        host: grafana
        port:
          number: 3000
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: kiali-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 80
      name: http-kiali
      protocol: HTTP
    hosts:
    - "kiali.${INGRESS_DOMAIN}"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: kiali-vs
  namespace: istio-system
spec:
  hosts:
  - "kiali.${INGRESS_DOMAIN}"
  gateways:
  - kiali-gateway
  http:
  - route:
    - destination:
        host: kiali
        port:
          number: 20001
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: prometheus-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingress
  servers:
  - port:
      number: 80
      name: http-prom
      protocol: HTTP
    hosts:
    - "prometheus.${INGRESS_DOMAIN}"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: prometheus-vs
  namespace: istio-system
spec:
  hosts:
  - "prometheus.${INGRESS_DOMAIN}"
  gateways:
  - prometheus-gateway
  http:
  - route:
    - destination:
        host: prometheus
        port:
          number: 9090
EOF
echo "Grafana, Prometheus and Kiali exposed"

echo "Installing Gateway to access DemoApp"
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  # The selector matches the ingress gateway pod labels.
  # If you installed Istio using Helm following the standard documentation, this would be "istio=ingress"
  selector:
    istio: ingress
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /get
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
EOF

echo "K8s local configured"
