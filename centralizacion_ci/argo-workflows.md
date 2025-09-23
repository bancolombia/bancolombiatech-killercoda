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

## 2. Argo Server

Similar a Argo CD, Argo Workflows también cuenta con una UI que mejora la experiencia del desarrollador (DevEx). Puedes acceder a la consola haciendo [click aquí]({{TRAFFIC_HOST1_2746}}).

### 2.1. Configuración RBAC



## 3. Cluster Templates

Nuestra misión detrás de esta iniciativa es disminuir la carga cognitiva de los equipos de desarrollo en la gestión de pipelines. Lo anterior quiere decir que requerimos consturir pipelines de uso transversal, que impacte la mayoría de los proyectos de software y que evite la necesidad de que los equipos los gestionen por sí mismo; pero, a su vez, que les permita acceder a los logs del pipeline para identificar si existe alguna oportunidad de mejora de su parte.

Para lograrlo, crearemos `ClusterWorkflowTemplates`, que se tratan de CRDs de K8s con los que podemos generalizar la lógica de pipelines y replicarla en cualquier proyecto de software dentro del clúster. A modo de ejemplo, crearemos el pipeline convencional descrito en la Figura 2.

![](./images/pipeline.png)

Figura 2. Pipeline CI.

Como se aprecia en la Figura 2, el pipeline consiste de los siguientes _steps_:

1. __Git clone:__ inicia con la clonación del repositorio de interés. 
2. __Testing:__ ejecuta el set de test unitarios. Normlamente, se envía a un producto externo, vía API's para la ejecución de análisis estático de código.
3. __Security check:__ ejecuta escaneo de vulnerabilidades de código.
4. __Nuevo artefacto:__ genera y publica un nuevo artefacto versionado del desarrollo.

El template que reune todos los steps numerados con anterioridad se puede apreciar a continuación:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ci-pipeline
  namespace: argo
spec:
  entrypoint: pipeline
  serviceAccountName: ci-runner-sa
  onExit: notify
  arguments:
    parameters:
      - name: repo_url             
      - name: revision             
      - name: context_dir          
      - name: image                
      - name: image_tag            
  volumes:
    - name: workspace
      emptyDir: {}
  templates:
    - name: pipeline
      dag:
        tasks:
          - name: clone
            templateRef:
                name: workflow-clone-template
                template: git-clone
                clusterScope: true
          - name: deps
            template: install-deps
            dependencies: [clone]
          - name: lint
            template: lint
            dependencies: [deps]
          - name: test
            template: test
            dependencies: [deps]
          - name: build-image
            template: build-image
            dependencies: [lint, test]
```{{copy}}

### 3.1. Git clone

Para la clonación del repositorio, usaremos un contenedor cuya imagen base esté basada en `git`. El template se puede apreciar a continuación.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: workflow-clone-template
spec:
  templates:
  - name: git-clone
    inputs:
      parameters:
      - name: message
    container:
      image: busybox
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```{{copy}}

