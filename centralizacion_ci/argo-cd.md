# Argo CD

Usaremos Argo CD para que nuestra estrategia de centralización esté basada en GitOps, lo que permitirá que todos los templates de pipelines sean manejados y configurados desde el repositorio Git.

## 1. Repositorio

Para empezar, necesitaremos crear un repositorio que contendrá las definiciones y manifiestos de K8s. En este demo, usaremos GitHub, pero cualquier otro Git provider es válido. 

El repositorio podría tomar cualquier nombre. Sólo tendrás que compartir la información del repo y el token como variables de entorno:

```bash
export GITHUB_USERNAME=<username>
```{{copy}}

```bash
export GITHUB_TOKEN=<token>
```{{copy}}

```bash
export GITHUB_REPO=<repo_name>
```{{copy}}

Ahora, procederemos a hacer un clon del repo. El clon ya está configurado con tus credenciales, por lo que podrás hacer operaciones de `git push` sin problemas.

```bash
git clone https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$GITHUB_REPO
```{{exec}}

### 1.1. Adecuación del repositorio

Ahora, vamos a clonar el repositorio y brindar una estructura base para organizar el proyecto. Se recomienda la siguiente estructura:

```text
<repo>/
  ├── argo/
  |     ├── workflows/
  |     |       ├── ns.yaml
  |     |       ├── kustomization.yaml
  |     ├── events/
  |     |       ├── ns.yaml
  |     |       ├── kustomization.yaml
  |     ├── kustomization.yaml
LICENSE
README.md
```

Para relacionar el repo con Argo CD, debemos relacionar cada `kustomization.yaml` con los manifiestos de K8s que deseamos desplegar. El `argo/kustomization.yaml` quedaría de la siguiente forma:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- events/
- workflows/
```{{copy}}

Esta configuración conecta las definiciones de ArgoCD con las de Workflows y Events.

### 1.1. Workflows

Para Argo Workflows, el `argo/workflows/kustomization.yaml` quedaría de la siguiente forma:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ns.yaml
```{{copy}}

Procederemos a definir el namespace principal a través del siguiente manifiesto:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argo
spec: {}
status: {}
```{{copy}}

### 1.2. Events

Para Argo Events, el `argo/events/kustomization.yaml` quedaría de la siguiente forma:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ns.yaml
```{{copy}}

Procederemos a definir el namespace principal a través del siguiente manifiesto:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argo-events
spec: {}
status: {}
```{{copy}}

## 2. Argo Server

Todas las herramientas dentro del ecosistema de Argo cuentan con una UI interactiva que facilita la configuración de algunas operaciones. En el presente demo, ya está configurada y habilitada la consola de Argo CD. Podrás acceder a la UI haciendo [click aquí]({{TRAFFIC_HOST1_80}}).

![](./images/init.png)

Figura 1. UI de Argo CD.

Las credenciales de conexión son:

* __Username:__ admin
* __Password:__ ejecuta el siguiente comando para conocer la contraseña:

```bash
echo "ArgoCD password = $(k get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
```{{exec}}

## 3. Configuración de Argo CD

Llegados a este punto, ya tenemos acceso al Argo Server y tenemos listo el repositorio. Lo único que debemos hacer es relacionar el repositorio con Argo CD. Lo podremos hacer a través de la UI, como se muestra en las Figuras 2, 3 y 4.

![](./images/argocd-init.png)

Figura 2. Configuración de _"NEW APP"_ - Parte 1.

Como se aprecia en la Figura 2, iniciamos definiendo la metadata de la configuración en Argo CD. Para nuestro caso:

* __Application Name:__ centralizador-ci
* __Project Name:__ default
* __Sync Policy:__ Automatic

![](./images/argocd-repo.png)

Figura 3. Configuración del repositorio.

Luego, relacionamos el repositorio que queremos vincular con nuestro cluster. También, debemos definir la referencia del clúster, que para nuestro caso sería:

* __Cluster URL:__ https://kubernetes.default.svc
* __Namespace:__ default

Esto último lo que hará que todo objeto de K8s que no tenga namespace declarado, tome por valor `default`.

![](./images/argocd-res.png)

Figura 4. Resultado de las definiciones de los namespaces.

Si todo salió de manera exitosa, obtendremos el resultado mostrado en la Figura 4. Adicional, puedes corroborarlo ejecutando el siguiente comando:

```bash
k get ns
```{{exec}}

Si todo es correcto, verás la existencia de los namespaces `argo` y `argo-events`, que es donde existirán los objetos que construiremos de Argo Workflows y Argo Events, respectivamente.