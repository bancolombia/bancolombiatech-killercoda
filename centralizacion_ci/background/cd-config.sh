#argo cd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#argo server
kubectl patch deployment \
  argocd-server \
  --namespace argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [
  "argocd-server",
  "--insecure"
  ]}]'

kubectl -n argocd rollout status --watch --timeout=600s deployment/argocd-server

kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 80:80 > /dev/null &