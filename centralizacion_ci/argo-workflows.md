# Argo Workflows

Es una herramienta para la gestión la orquestación paralela de _jobs_ en Kubernetes. Está diseñado para ejecutar cada step a través de técnicas de contenerización y DAG. 

## 1. Estructura del repositorio

Antes de empezar, recordemos la estructura base de nuestro repositorio:

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

Todos los manifiestos de K8s de Argo Workflows que vamos a gestionar los crearemos en el path: `argo/workflows`.

## 2. Argo Server + Prerrequisitos

Similar a Argo CD, Argo Workflows también cuenta con una UI que mejora la experiencia del desarrollador (DevEx). Puedes acceder a la consola haciendo [click aquí]({{TRAFFIC_HOST1_2746}}).

### 2.1. MinIO

MinIO es un _"Object Storage"_ similar, y compatible, a AWS S3. Sirve para almacenar objetos (blobs) de cualquier tipo. En nuestro caso, lo usaremos para almacenar los artefactos reutilizables derivados de la ejecución de pipelines.

Para acceder a la consola de MinIO, puedes hacer [click aquí]({{TRAFFIC_HOST1_9090}}).

Las credenciales de conexión son:

* __Username:__ admin
* __Password:__ ejecuta el siguiente comando para conocer la contraseña:

```bash
echo "MinIO password = $(k get secret -n argo-artifacts argo-artifacts -o jsonpath="{.data.root-password}" | base64 -d)"
```{{exec}}

Ahora, entraremos al servicio y crearemos un bucket que llamaremos `pipeline-artifacts-bucket`, que será donde almacenaremos nuestros artefactos.

#### 2.1.1 Configuración en Argo

Ahora que tenemos nuestro _Object Storage_ y un bucket registrado, debemos relacionarlo con Argo para que, cada vez que se cree un artefacto, lo almacene allí. Para ello, debemos crear el siguiente `ConfigMap` que se relacionará con los pipelines ejecutados de forma automática.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: artifact-repositories
  namespace: argo
  annotations:
    workflows.argoproj.io/default-artifact-repository: default-artifact-repository
data:
  default-artifact-repository: |
    s3:
      bucket: pipeline-artifacts-bucket
      endpoint: argo-artifacts.argo-artifacts.svc.cluster.local:9000
      insecure: true
      accessKeySecret:
        name: minio-creds
        key: accesskey
      secretKeySecret:
        name: minio-creds
        key: secretkey
```{{copy}}

Requeriremos usar nuestro token de GitHub, configurado en la sección anterior, para clonar los repositorios de interés. Para ello, lo registraremos como un secreto del clúster a través del siguiente comando:

```bash
k create secret generic -n argo github-creds --from-literal=username=$GITHUB_USERNAME --from-literal=token=$GITHUB_TOKEN
```{{exec}}

### 2.2. Configuración RBAC

La ejecución de `Workflows` emplea un `serviceaccount` para su ejecución. Si no se especifica, usará el valor por `default`. En condiciones normales, esto no funcionará dado que las últimas versiones de Kubernetes emplean el __principio de mínimos privilegios__. Debido a ello, es necesario configurar un `serviceaccount` por cada `namespace` que contenga los permisos necesarios para la ejecución de sus opearciones.

En nuestro caso, configuraremos el siguiente `serviceaccount` y `namespace`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: inversion
spec: {}
status: {}
```{{copy}}

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argo-workflow
  namespace: inversion
```{{copy}}

Ahora, asociaremos el `ClusterRole` de `admin` de la siguiente forma:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: inversiones-admin
  namespace: inversion
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: argo-workflow
  namespace: inversion
```{{copy}}


## 3. Cluster Templates

Nuestra misión detrás de esta iniciativa es disminuir la carga cognitiva de los equipos de desarrollo en la gestión de pipelines. Lo anterior quiere decir que requerimos consturir pipelines de uso transversal, que impacte la mayoría de los proyectos de software y que evite la necesidad de que los equipos los gestionen por sí mismo; pero, a su vez, que les permita acceder a los logs del pipeline para identificar si existe alguna oportunidad de mejora de su parte.

Para lograrlo, crearemos `ClusterWorkflowTemplates`, que se tratan de CRDs de K8s con los que podemos generalizar la lógica de pipelines y replicarla en cualquier proyecto de software dentro del clúster. A modo de ejemplo, crearemos el pipeline convencional descrito en la Figura 2.

![](./images/pipeline.png)

Figura 2. Pipeline de Build.

Como se aprecia en la Figura 2, el pipeline consiste de los siguientes _steps_:

1. __Git clone:__ inicia con la clonación del repositorio de interés. 
2. __Testing:__ ejecuta el set de test unitarios. Normlamente, se envía a un producto externo, vía API's para la ejecución de análisis estático de código.
3. __Security check:__ ejecuta escaneo de vulnerabilidades de código.
4. __Nuevo artefacto:__ genera y publica un nuevo artefacto versionado del desarrollo.

### 3.1. Git clone

Para la clonación del repositorio, usaremos un contenedor cuya imagen base pueda ejecutar operaciones `git`. El template se puede apreciar a continuación.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: git-clone-template
spec:
  templates:
  - name: git-clone
    inputs:
      parameters:
        - name: repo_url               
        - name: revision            
    container:
      image: alpine/git:2.45.2
      workingDir: /workspace
      volumeMounts:
        - name: workspace               
          mountPath: /workspace
      env:
        - name: GIT_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-creds        
              key: token
      command: [sh, -euxc]
      args:
        - |
          repo="{{inputs.parameters.repo_url}}"
          rev="{{inputs.parameters.revision}}"

          # inject token for HTTPS GitHub remotes
          if echo "$repo" | grep -q '^https://github.com/'; then
            repo="${repo/https:\/\//https:\/\/${GIT_TOKEN}@}"
          fi

          git clone --depth 1 --branch "$rev" "$repo" src
    outputs:
      artifacts:
        - name: repo
          path: /workspace/src
```{{copy}}

### 3.2. Calidad

Para la evaluación de la calidad y ejecución de reportes de cobertura. Para el correcto envío del reporte, tendremos que gestionar un token de autenticación (tipo PAT - _"Personal Access Token"_). Una vez lo tengamos, lo registraremos como variable de entorno a través del siguiente comando:

```bash
export SONAR_TOKEN=<token>
```{{copy}}

Ahora, crearemos el secreto del token de Sonar:

```bash
k create secret generic -n argo sonar-creds --from-literal=token=$SONAR_TOKEN
```{{exec}}

Finalmente, registraremos el template correspondiente.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: test-coverage-templates
spec:
  templates:
  - name: gradle-test-coverage
    inputs:
      artifacts:
      - name: clone
        path: /workspace/repo
      parameters:
      - name: project_dir           
    container:
      image: gradle:jdk21-corretto-al2023
      workingDir: /workspace/repo
      volumeMounts:
        - name: workspace               
          mountPath: /workspace
      env:
        - name: SONAR_TOKEN
          valueFrom:
            secretKeyRef:
              name: sonar-creds       
              key: token
      command: [sh, -euxc]
      args:
        - |
          cd {{inputs.parameters.project_dir}}
          ./gradlew clean test jacocoTestReport sonarqube --info
    outputs:
      artifacts:
        - name: reporte-cobertura
          path: /workspace/repo/{{inputs.parameters.project_dir}}/build/reports/jacoco/test/jacocoTestReport.xml
```{{copy}}

## 3.3. Análisis de seguridad

Para el escaneo de seguridad, utilizaremos [Trivy](https://github.com/aquasecurity/trivy) como herramienta base. 

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: security-check-templates
spec:
  templates:
  - name: trivy-scan
    inputs:
      artifacts:
      - name: clone
        path: /workspace/repo
      parameters:
      - name: project_dir           
    container:
      image: aquasec/trivy:0.66.0
      workingDir: /workspace/repo
      volumeMounts:
        - name: workspace               
          mountPath: /workspace
      command: [sh, -euxc]
      args:
        - |
          trivy fs {{inputs.parameters.project_dir}} -f json -o results.json
    outputs:
      artifacts:
        - name: security-results
          path: /workspace/repo/results.json
```{{copy}}

### 3.4. Artefacto final

En este punto, suponemos que la operación de `push` en el repositorio ha cumplido con los estándares de calidad y seguridad definidos. Por lo que procederemos con la creación del artefacto final versionado. Para nuestro caso de ejemplo, estamos hablando de un microservicio de Spring Boot cuyo artefacto final debe ser una __imagen Docker__.

Para ello, usaremos el registry público de __Docker Hub__ para almacenar el artefacto. Iniciaremos registrando las credenciales de nuestra cuenta de Docker Hub como variables de entorno:

```bash
export DOCKER_USERNAME=<username>
```{{copy}}

```bash
export DOCKER_TOKEN=<token>
```{{copy}}

Ahora, almacenaremos las credenciales como un secreto de K8s.

```bash
k create secret generic -n argo docker-creds --from-literal=username=$DOCKER_USERNAME --from-literal=token=$DOCKER_TOKEN
```{{exec}}

Finalmente, registraremos el template para generar el artefacto.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: final-artifact-templates
spec:
  templates:
  - name: podman-image
    inputs:
      artifacts:
      - name: clone
        path: /workspace/repo
      parameters:
      - name: project_dir
      - name: image_name
      - name: image_tag           
    container:
      image: ubuntu:24.04
      workingDir: /workspace/repo
      securityContext:
        privileged: true
      volumeMounts:
        - name: workspace               
          mountPath: /workspace
        - name: podman-lib
          mountPath: /var/lib/containers 
      command: [sh, -euxc]
      env:
        - name: DOCKERHUB_USERNAME
          valueFrom:
            secretKeyRef:
              name: docker-creds
              key: username
        - name: DOCKERHUB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: docker-creds
              key: token
      args:
        - |
          #Install Podman
          apt-get update
          apt-get -y install podman

          #Image build
          cd {{inputs.parameters.project_dir}}
          export IMAGE="$DOCKERHUB_USERNAME/{{inputs.parameters.image_name}}:{{inputs.parameters.image_tag}}"
          podman build -t $IMAGE .

          #Save Image
          podman save --format oci-archive --output /workspace/image-oci.tar "$IMAGE"

          #Image push
          podman login --username "$DOCKERHUB_USERNAME" --password "$DOCKERHUB_PASSWORD" docker.io
          podman push $IMAGE
    outputs:
      artifacts:
        - name: image-artifact
          path: /workspace/image-oci.tar
```{{copy}}

### 3.5. `Workflow` para testing

Para corroborar que todas los templates fueron debidamente configurados, ejecutaremos el siguiente Workflow en el repositorio de tu preferencia. Debe ser un desarrollo Java para que funcione y evalúe todos los _steps_. 

__Nota:__ el siguiente manifiesto no debes registrarlo en el repositorio administrativo. Este `Workflow` es sólo para corroborar la funcionalidad del pipeline y su integración con los templates anteriormente definidos. Se debe correr de manera manual, con un repositorio escogido por ti.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: pipeline-build-
  namespace: argo
spec:
  serviceAccountName: argo-workflow
  entrypoint: pipeline-build
  arguments:
    parameters:
      - name: repo_url
      - name: revision
      - name: project_dir
      - name: image_name
      - name: image_tag
  volumes:
    - name: workspace
      emptyDir: {}
    - name: podman-lib
      emptyDir: {}
  templates:
    - name: pipeline-build
      dag:
        tasks:
          - name: clone
            templateRef:
              name: git-clone-template
              template: git-clone
              clusterScope: true
            arguments:
              parameters:
                - name: repo_url
                  value: "{{workflow.parameters.repo_url}}"
                - name: revision
                  value: "{{workflow.parameters.revision}}"
          - name: test-coverage
            dependencies: [clone]
            templateRef:
              name: test-coverage-templates
              template: gradle-test-coverage
              clusterScope: true
            arguments:
              parameters:
                - name: project_dir
                  value: "{{workflow.parameters.project_dir}}"
              artifacts:
                - name: clone
                  from: "{{tasks.clone.outputs.artifacts.repo}}"
          - name: security-check
            dependencies: [clone]
            templateRef:
              name: security-check-templates
              template: trivy-scan
              clusterScope: true
            arguments:
              parameters:
                - name: project_dir
                  value: "{{workflow.parameters.project_dir}}"
              artifacts:
                - name: clone
                  from: "{{tasks.clone.outputs.artifacts.repo}}"
          - name: final-artifact
            dependencies: [test-coverage, security-check]
            templateRef:
              name: final-artifact-templates
              template: podman-image
              clusterScope: true
            arguments:
              parameters:
                - name: image_name
                  value: "{{workflow.parameters.image_name}}"
                - name: image_tag
                  value: "{{workflow.parameters.image_tag}}"
                - name: project_dir
                  value: "{{workflow.parameters.project_dir}}"
              artifacts:
                - name: clone
                  from: "{{tasks.clone.outputs.artifacts.repo}}"
```{{copy}}
