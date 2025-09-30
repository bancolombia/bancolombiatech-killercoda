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
  |     |       ├── README.md
  |     |       ├── kustomization.yaml
  |     ├── events/
  |     |       ├── README.md
  |     |       ├── kustomization.yaml
  |     ├── kustomization.yaml
LICENSE
README.md
```

Cada `kustomization.yaml` expuesto en la estructura, especifica los manifiestos que se desean relacionar dentro del flujo GitOps y cuentan con la siguiente estructura:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- <carpeta>
- <manifiesto>.yaml
```

## 2. Argo Server

Todas las herramientas dentro del ecosistema de Argo cuentan con una UI interactiva que facilita la configuración de algunas operaciones. En el presente demo, ya está configurada y habilitada la consola de Argo CD. Podrás acceder a la UI haciendo [click aquí]({{TRAFFIC_HOST1_80}}).

![](./images/init.png)

Figura 1. UI de Argo CD.

Las credenciales de conexión son:

* __Username:__ admin
* __Password:__ ejecuta el siguiente comando para conocer la contraseña:

```bash
echo "MinIO password = $(k get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
```{{exec}}

## 3. Configuración de Argo CD

Llegados a este punto, ya tenemos acceso al Argo Server y tenemos listo el repositorio. Lo único que debemos hacer es relacionar el repositorio con Argo CD. Lo podremos hacer a través de la UI, como se muestra en la Figura 2.

