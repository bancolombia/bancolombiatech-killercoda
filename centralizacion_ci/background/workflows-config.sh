#argo-workflows
kubectl create ns argo-workflows
kubectl apply -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/install.yaml
kubectl -n argo-workflows wait deploy --all --for condition=Available --timeout 2m