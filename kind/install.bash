#! /bin/bash

echo "🔵 Kind Version: "
kind --version
printf "\n"
echo "🔵 Kubectl Version:"
kubectl version
printf "\n"

echo "🔵 Pulling the running clusters"
kind get clusters
cluster=(kind get clusters)
printf "\n"

if [ -z "$cluster" ]; then
  echo "🚀 Applying the cluster.yaml to create the cluster"
  kind create cluster --config cluster.yaml
else
  echo "🔵 $cluster Cluster is already running"
fi

echo "🔵 Using the kind-cluster context"
kubectl config use-context kind-$(kind get clusters)


echo "🚀 Setup Nginx Gateway Fabric"
printf "\n"

echo "✅ Install the Gateway API Resources"
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.0" | kubectl apply -f -

printf "\n"

echo "🔵 Listing the CRDs installed"
kubectl get crd
printf "\n"

echo "✅ Install the Nginx Gateway Fabric using Helm"
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
printf "\n"

echo "✅ List the available resources in the nginx-gateway namespace"
kubectl get all -n nginx-gateway
printf "\n"

echo "👏 Successfully configured the Cluster"