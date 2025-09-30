En el presente demo, accederás a las configuraciones base de las herramientas de _Argo Project_ para habilitar una estrategia de centralización de pipelines basada en GitOps. Para lograrlo, exploraremos específicamente:

* __Argo CD:__ habilita GitOps para la gestión de configuraciones desde repositorios Git.
* __Argo Workflows:__ gestiona la lógica interna de los pipelines a través de objetos de Kubernetes.
* __Argo Events:__ automatización _"event-driven"_ que vincula la gestión de eventos con clústers de Kubernetes. Nos permitirá detectar operaciones de `push` y `pull-request` en el repositorio para la activación de pipelines.
* __MinIO:__ object storage Open Source compatible con AWS S3. Se emplea para el almacenamiento de los artefactos generados durante la ejecución de los pipelines.

__IMPORTANTE:__ espera a que termine la instalación de paquetes antes de continuar.

__Creado por:__ Juan David Argüello Plata ([LinkedIn](https://www.linkedin.com/in/jdarp/))