#nginx ingress-controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

#external-secrets
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \

#MinIO
kubectl create ns argo-artifacts
helm install argo-artifacts oci://registry-1.docker.io/bitnamicharts/minio --set fullnameOverride=argo-artifacts --set namespaceOverride=argo-artifacts

kubectl -n argo-artifacts rollout status --watch --timeout=600s deployment/argo-artifacts-console
kubectl -n argo-artifacts port-forward --address 0.0.0.0 svc/argo-artifacts-console 9090:9090 > /dev/null &
#helm repo add minio https://charts.min.io/ # official minio Helm charts
#helm repo update
#helm install argo-artifacts minio/minio --set service.type=LoadBalancer --set fullnameOverride=argo-artifacts


