#argo
kubectl create ns argo
kubectl apply -n argo -f https://github.com/argoproj/argo/releases/download/v3.7.2/install.yaml
kubectl -n argo wait deploy --all --for condition=Available --timeout 2m

kubectl -n argo wait deploy --all --for condition=Available --timeout 2m

#rbac
kubectl create serviceaccount argo-workflow -n argo

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: workflow-executor-rbac
rules:
  - apiGroups:
      - argoproj.io
    resources:
      - workflowtaskresults
    verbs:
      - create
      - patch
EOF

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-executor-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workflow-executor-rbac
subjects:
- kind: ServiceAccount
  name: argo-workflow
  namespace: argo
EOF

#argo server
kubectl patch deployment \
  argo-server \
  --namespace argo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server",
  "--secure=false"
]},
{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}
]'

kubectl -n argo rollout status --watch --timeout=600s deployment/argo-server

kubectl -n argo port-forward --address 0.0.0.0 svc/argo-server 2746:2746 > /dev/null &