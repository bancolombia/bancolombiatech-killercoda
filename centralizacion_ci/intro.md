# Centralización CI

En el presente demo, accederás a las configuraciones base de las herramientas de _Argo Project_ para habilitar una estrategia de centralización de pipelines basada en GitOps. Para lograrlo, exploraremos específicamente:

* __Argo CD:__ habilita GitOps para la gestión de configuraciones desde repositorios Git.
* __Argo Events:__ automatización _"event-driven"_ que vincula la gestión de eventos con clústers de Kubernetes. Nos permitirá detectar operaciones de `push` y `pull-request` en el repositorio para la activación de pipelines.
* __Argo Workflows:__ gestiona la lógica interna de los pipelines a través de objetos de Kubernetes.

__IMPORTANTE:__ espera a que termine la instalación de paquetes antes de continuar.

__Creado por:__ Juan David Argüello Plata ([LinkedIn Profile](https://www.linkedin.com/in/jdarp/))