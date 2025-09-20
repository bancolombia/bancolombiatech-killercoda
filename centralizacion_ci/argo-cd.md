# Argo CD

Usaremos Argo CD para que nuestra estrategia de centralización esté basada en GitOps, lo que permitirá que todos los templates de pipelines sean manejados y configurados desde el repositorio Git.

## 1. Repositorio

Para empezar, necesitaremos crear un repositorio. En este demo, usaremos GitHub, pero cualquier otro Git provider es válido. 

El repositorio podría tomar cualquier nombre. Ahora, sólo tendrás que compartir la información del repo y el token como variables de entorno:

```bash
export GIT_REPO=<nombre_del_repo>
```

```bash
export GITHUB_TOKEN=<token>
```

## 2. Argo Server

Todas las herramientas dentro del ecosistema de Argo cuentan con una UI interactiva que facilita la configuración de algunas operaciones. En la presente sección, habilitaremos y accederemos a la consola de Argo CD.

Por default, Argo Server está configurado para correr con https. Esta configuración es inviable con Killercoda, por lo que ejecutaremos el siguiente comando para que funcione con __http__.

```bash
kubectl patch deployment \
  argocd-server \
  --namespace argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [
  "argocd-server",
  "--insecure"
  ]}]'
```

Con este cambio, necesitamos esperar hasta que el servidor vuelva a ser desplegado:

```bash
kubectl -n argocd rollout status --watch --timeout=600s deployment/argocd-server
```

Ahora, podremos liberar el Argo Server ejecutando el siguiente comando:

```bash
kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 80:80 > /dev/null &
```{{exec}}

Finalmente, podrás acceder a la UI haciendo [click aquí]({{TRAFFIC_HOST1_80}}). Si en este punto, has hecho todo bien, deberías poder ver la consola de Argo, parecido a como se muestra en la Figura 1.

![](./images/init.png)

Las credenciales de conexión son:

* __Username:__ admin
* __Password:__ ejecuta el siguiente comando para conocer la contraseña:

```bash
k get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```


## 3. Configuración de Argo CD

Llegados a este punto, ya tenemos acceso al Argo Server y tenemos listo el repositorio. Lo único que debemos hacer es relacionar el repositorio con Argo CD, como se muestra a continuación:

