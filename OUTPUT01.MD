--
././README.md
--
# Ory Kratos, Keto, and Oathkeeper with Kubernetes

This example show how create an SSO and ACL system with the Ory stack and
Kubernetes.

Many thanks to [@pngouin](https://github.com/pngouin) for the the
[original example](https://github.com/pngouin/k8s-ory-example) 🙌

## Overview

This example uses the
[kratos-selfservice-ui-node](https://github.com/ory/kratos-selfservice-ui-node),
a fork of [mailslurper](https://github.com/pngouin/mailslurper) and a
[react-admin app](https://github.com/pngouin/react-admin-ory) for the _admin_
page.

![schema](_assets/diagram.png) _(This is an outline and does not exactly reflect
the reality of how the stack works)_

## Develop

### Prerequisites

- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kustomize](https://kubernetes-sigs.github.io/kustomize/installation/)

### Run locally

```bash
$ minikube start
$ minikube addons enable ingress

# Create all resources
$ ./build.sh | kubectl apply -f -

# waits for Keto to be ready and add policies
$ ./add-keto-policies.sh | kubectl apply -f -
$ kubectl get ingress
NAME               CLASS    HOSTS            ADDRESS        PORTS   AGE
fake-smtp-server   <none>   mail.test.info   192.168.XXX.XXX   80      119s
oathkeeper         <none>   ory.test.info    192.168.XXX.XXX   80      119s

# add ingress to the hosts file
$ sudo bash -c 'cat << EOF >> /etc/hosts
# ORY Minikube SSO stack
192.168.XXX.XXX    mail.test.info
192.168.XXX.XXX    ory.test.info
EOF'

```

Open your browser and navigate to `http://ory.test.info/panel/welcome` and
`http://mail.test.info`.

Go to `http://ory.test.info/panel/` and create an account. You can validate your
email on http://mail.test.info. When you create an account you have to add the
role `user` or `admin`. Only the admin role has the right to access the admin
react app.

| URL                                | Description                                               |
| :--------------------------------- | :-------------------------------------------------------- |
| http://ory.test.info/panel/welcome | User app for create an account, login, other              |
| http://ory.test.info/admin/        | Admin react app, you need the role `admin` to access      |
| http://mail.test.info              | Local mail panel, you will receive mail confirmation here |

## Contribute

Feel free to
[open a discussion](https://github.com/ory/examples/discussions/new) to provide
feedback or talk about ideas, or
[open an issue](https://github.com/ory/examples/issues/new) if you want to add
your example to the repository or encounter a bug. You can contribute to Ory in
many ways, see the
[Ory Contributing Guidelines](https://www.ory.sh/docs/ecosystem/contributing)
for more information.
--
--
././fake-smtp-server/ingress.yaml
--
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fake-smtp-server
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: mail.test.info
      http:
        paths:
          - path: /admin/(.*)
            pathType: Prefix
            backend:
              service:
                name: fake-smtp-server-admin
                port:
                  number: 4437
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: fake-smtp-server-ui
                port:
                  number: 4436
--
--
././fake-smtp-server/service-admin.yaml
--
apiVersion: v1
kind: Service
metadata:
  name: fake-smtp-server-admin
  namespace: default
  labels:
    app.kubernetes.io/name: fake-smtp-server
spec:
  type: ClusterIP
  ports:
    - port: 4437
      targetPort: http-mail-admin
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: fake-smtp-server
--
--
././fake-smtp-server/deployment.yaml
--
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fake-smtp-server
  namespace: default
  labels:
    app.kubernetes.io/name: fake-smtp-server
  annotations:
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: fake-smtp-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: fake-smtp-server
      annotations:
    spec:
      volumes:
        - name: config
          configMap:
            name: mailslurper-config
        - name: cert
          secret:
            secretName: mailslurper-cert
      containers:
        - name: fake-smtp-server
          image: "pingouin/mailslurper:latest"
          imagePullPolicy: Always
          command: ["./mailslurper"]
          args: ["--config", "/etc/config/config.json"]
          volumeMounts:
            - name: config
              mountPath: /etc/config
              readOnly: true
            - name: cert
              mountPath: /etc/cert
              readOnly: true
          ports:
            - name: smtp
              containerPort: 1025
              protocol: TCP
            - name: http-mail-ui
              containerPort: 4436
              protocol: TCP
            - name: http-mail-admin
              containerPort: 4437
              protocol: TCP
--
--
././fake-smtp-server/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment.yaml
  - service-smtp.yaml
  - service-ui.yaml
  - service-admin.yaml
  - ingress.yaml

secretGenerator:
  - name: mailslurper-cert
    files:
      - mailslurper-cert.pem=secrets/mailslurper-cert.pem
      - mailslurper-key.pem=secrets/mailslurper-key.pem

configMapGenerator:
  - name: mailslurper-config
    files:
      - config.json=config/config.json
--
--
././fake-smtp-server/service-ui.yaml
--
apiVersion: v1
kind: Service
metadata:
  name: fake-smtp-server-ui
  namespace: default
  labels:
    app.kubernetes.io/name: fake-smtp-server
spec:
  type: ClusterIP
  ports:
    - port: 4436
      targetPort: http-mail-ui
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: fake-smtp-server
--
--
././fake-smtp-server/service-smtp.yaml
--
apiVersion: v1
kind: Service
metadata:
  name: mail-smtp
  namespace: default
  labels:
    app.kubernetes.io/name: fake-smtp-server
spec:
  type: ClusterIP
  ports:
    - port: 1025
      targetPort: smtp
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: fake-smtp-server
--
--
././selfservice-ui/service.yaml
--
# Source: kratos/templates/service-admin.yaml
apiVersion: v1
kind: Service
metadata:
  name: selfservice
  namespace: default
  labels:
    app.kubernetes.io/name: selfservice
spec:
  type: ClusterIP
  ports:
    - port: 4455
      targetPort: selfservice
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: selfservice
--
--
././selfservice-ui/deployment.yaml
--
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selfservice
  namespace: default
  labels:
    app.kubernetes.io/name: selfservice
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: selfservice
  template:
    metadata:
      labels:
        app.kubernetes.io/name: selfservice
    spec:
      containers:
        - name: selfservice-ui
          image: "oryd/kratos-selfservice-ui-node:v0.9.0-alpha.3"
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: selfservice-ui-env
          ports:
            - name: selfservice
              containerPort: 4455
              protocol: TCP
--
--
././selfservice-ui/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment.yaml
  - service.yaml

configMapGenerator:
  - name: selfservice-ui-env
    envs:
      - config/selfservice-ui.env
--
--
././kratos/sa.yaml
--
# Source: kratos/templates/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-kratos
  labels:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
    app.kubernetes.io/version: "v0.9.0-alpha.3"
--
--
././kratos/service-admin.yaml
--
# Source: kratos/templates/service-admin.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-kratos-admin
  namespace: default
  labels:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
    app.kubernetes.io/version: "v0.9.0-alpha.3"
spec:
  type: ClusterIP
  ports:
    - port: 4434
      targetPort: http-admin
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
--
--
././kratos/deployment.yaml
--
# Source: kratos/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-kratos
  namespace: default
  labels:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
    app.kubernetes.io/version: "v0.9.0-alpha.3"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kratos
      app.kubernetes.io/instance: test-kratos
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kratos
        app.kubernetes.io/instance: test-kratos
        app.kubernetes.io/version: "v0.9.0-alpha.3"
    spec:
      initContainers:
        - name: kratos-automigrate
          image: "oryd/kratos:v0.9.0-alpha.3"
          imagePullPolicy: IfNotPresent
          command: ["kratos"]
          args:
            [
              "migrate",
              "sql",
              "-e",
              "--yes",
              "--config",
              "/etc/config/kratos.yaml",
            ]
          volumeMounts:
            - name: kratos-config-volume
              mountPath: /etc/config
              readOnly: true
          env:
            - name: DSN
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: dsn
            - name: SECRETS_DEFAULT
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: secretsDefault
            - name: SECRETS_COOKIE
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: secretsCookie
      volumes:
        - name: kratos-config-volume
          configMap:
            name: kratos-config
        - name: kratos-identity-schema
          configMap:
            name: kratos-identity
      automountServiceAccountToken: true
      serviceAccountName: test-kratos
      containers:
        - name: kratos
          image: "oryd/kratos:v0.9.0-alpha.3"
          imagePullPolicy: IfNotPresent
          command: ["kratos"]
          args:
            [
              "serve",
              "all",
              "--dev",
              "--config",
              "/etc/config/kratos.yaml",
              "--watch-courier",
            ]
          volumeMounts:
            - name: kratos-config-volume
              mountPath: /etc/config
              readOnly: true
            - name: kratos-identity-schema
              mountPath: /etc/config/identity/
              readOnly: true
          env:
            - name: DSN
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: dsn
            - name: SECRETS_DEFAULT
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: secretsDefault
            - name: SECRETS_COOKIE
              valueFrom:
                secretKeyRef:
                  name: kratos-secret
                  key: secretsCookie
          ports:
            - name: http-admin
              containerPort: 4434
              protocol: TCP
            - name: http-public
              containerPort: 4433
              protocol: TCP
          livenessProbe:
            failureThreshold: 5
            httpGet:
              path: /admin/health/alive
              port: http-admin
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            failureThreshold: 5
            httpGet:
              path: /admin/health/ready
              port: http-admin
            initialDelaySeconds: 30
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 100
--
--
././kratos/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment.yaml
  - service-admin.yaml
  - service-public.yaml
  - sa.yaml

secretGenerator:
  - name: kratos-secret
    envs:
      - secrets/kratos.env

configMapGenerator:
  - name: kratos-config
    files:
      - kratos.yaml=config/kratos.yaml
  - name: kratos-identity
    files:
      - identity.schema.json=config/identity.schema.json
--
--
././kratos/service-public.yaml
--
# Source: kratos/templates/service-public.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-kratos-public
  namespace: default
  labels:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
    app.kubernetes.io/version: "v0.9.0-alpha.3"
spec:
  type: ClusterIP
  ports:
    - port: 4433
      targetPort: http-public
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: kratos
    app.kubernetes.io/instance: test-kratos
--
--
././kratos/config/kratos.yaml
--
version: v0.9.0-alpha.3
dsn: fromEnv
serve:
  public:
    base_url: http://ory.test.info/.ory/kratos/public/
    cors:
      enabled: true
  admin:
    base_url: http://test-kratos-admin:4434/

session:
  cookie:
    domain: ory.test.info
  whoami:
    required_aal: highest_available

selfservice:
  default_browser_return_url: http://ory.test.info/panel/welcome
  allowed_return_urls:
    - http://ory.test.info/panel/welcome

  methods:
    link:
      enabled: true
    password:
      enabled: true
    totp:
      enabled: true
      config:
        issuer: ory.test.info
    lookup_secret:
      enabled: true
    webauthn:
      enabled: true
      config:
        rp:
          id: test.info
          origin: http://ory.test.info
          display_name: ory.test.info

  flows:
    error:
      ui_url: http://ory.test.info/panel/error

    settings:
      required_aal: highest_available
      ui_url: http://ory.test.info/panel/settings
      privileged_session_max_age: 15m

    recovery:
      enabled: true
      ui_url: http://ory.test.info/panel/recovery

    verification:
      enabled: true
      ui_url: http://ory.test.info/panel/verification
      after:
        default_browser_return_url: http://ory.test.info/panel/welcome

    logout:
      after:
        default_browser_return_url: http://ory.test.info/panel/login

    login:
      ui_url: http://ory.test.info/panel/login
      lifespan: 10m

    registration:
      lifespan: 10m
      ui_url: http://ory.test.info/panel/registration
      after:
        password:
          hooks:
            - hook: session

log:
  level: debug
  format: text
  leak_sensitive_values: true

secrets:
  cookie:
    - 4159f931cce7cc16d5c17814d76686d960d6ee40675faca165067eb1faa9bd4fa9beb9e1a2a689b2003355ae5746a283bf591f34dbc0e4d8f4a0685e754455b3
  cipher:
    - Vf2nS{+jwj"{U:BHLZ4V/Mz.As)]uKQ'

ciphers:
  algorithm: xchacha20-poly1305

hashers:
  argon2:
    parallelism: 24
    memory: 128MB
    iterations: 5
    salt_length: 16
    key_length: 16

identity:
  default_schema_id: default
  schemas:
    - id: default
      url: file:///etc/config/identity/identity.schema.json

courier:
  smtp:
    connection_uri: smtps://kratos:kratos@mail-smtp:1025/?skip_ssl_verify=true&legacy_ssl=true
--
--
././postgresql/postgresql.yaml
--
---
# Source: postgresql/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgresql
  labels:
    app.kubernetes.io/name: postgresql
    helm.sh/chart: postgresql-10.3.11
    app.kubernetes.io/instance: postgresql
    app.kubernetes.io/managed-by: Helm
  namespace: default
type: Opaque
data:
  postgresql-password: "MnU5T2ppb0YxNg=="
---
# Source: postgresql/templates/initialization-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-init-scripts
  labels:
    app.kubernetes.io/name: postgresql
    helm.sh/chart: postgresql-10.3.11
    app.kubernetes.io/instance: postgresql
    app.kubernetes.io/managed-by: Helm
  namespace: default
data:
  my_init_script.sql: |
    CREATE DATABASE keto;
    CREATE USER keto WITH ENCRYPTED PASSWORD 'keto';
    GRANT ALL PRIVILEGES ON DATABASE keto TO keto;
    CREATE DATABASE kratos;
    CREATE USER kratos WITH ENCRYPTED PASSWORD 'kratos';
    GRANT ALL PRIVILEGES ON DATABASE kratos TO kratos;
---
# Source: postgresql/templates/svc-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-headless
  labels:
    app.kubernetes.io/name: postgresql
    helm.sh/chart: postgresql-10.3.11
    app.kubernetes.io/instance: postgresql
    app.kubernetes.io/managed-by: Helm
    # Use this annotation in addition to the actual publishNotReadyAddresses
    # field below because the annotation will stop being respected soon but the
    # field is broken in some versions of Kubernetes:
    # https://github.com/kubernetes/kubernetes/issues/58662
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
  namespace: default
spec:
  type: ClusterIP
  clusterIP: None
  # We want all pods in the StatefulSet to have their addresses published for
  # the sake of the other Postgresql pods even before they're ready, since they
  # have to be able to talk to each other in order to become ready.
  publishNotReadyAddresses: true
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
  selector:
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/instance: postgresql
---
# Source: postgresql/templates/svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  labels:
    app.kubernetes.io/name: postgresql
    helm.sh/chart: postgresql-10.3.11
    app.kubernetes.io/instance: postgresql
    app.kubernetes.io/managed-by: Helm
  annotations:
  namespace: default
spec:
  type: ClusterIP
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
  selector:
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/instance: postgresql
    role: primary
---
# Source: postgresql/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql-postgresql
  labels:
    app.kubernetes.io/name: postgresql
    helm.sh/chart: postgresql-10.3.11
    app.kubernetes.io/instance: postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/component: primary
  annotations:
  namespace: default
spec:
  serviceName: postgresql-headless
  replicas: 1
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/instance: postgresql
      role: primary
  template:
    metadata:
      name: postgresql
      labels:
        app.kubernetes.io/name: postgresql
        helm.sh/chart: postgresql-10.3.11
        app.kubernetes.io/instance: postgresql
        app.kubernetes.io/managed-by: Helm
        role: primary
        app.kubernetes.io/component: primary
    spec:
      affinity:
        podAffinity:

        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: postgresql
                    app.kubernetes.io/instance: postgresql
                    app.kubernetes.io/component: primary
                namespaces:
                  - "default"
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:

      securityContext:
        fsGroup: 1001
      containers:
        - name: postgresql
          image: docker.io/bitnami/postgresql:11.11.0-debian-10-r24
          imagePullPolicy: "IfNotPresent"
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
          securityContext:
            runAsUser: 1001
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: POSTGRESQL_PORT_NUMBER
              value: "5432"
            - name: POSTGRESQL_VOLUME_DIR
              value: "/bitnami/postgresql"
            - name: PGDATA
              value: "/bitnami/postgresql/data"
            - name: POSTGRES_USER
              value: "postgres"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql
                  key: postgresql-password
            - name: POSTGRESQL_ENABLE_LDAP
              value: "no"
            - name: POSTGRESQL_ENABLE_TLS
              value: "no"
            - name: POSTGRESQL_LOG_HOSTNAME
              value: "false"
            - name: POSTGRESQL_LOG_CONNECTIONS
              value: "false"
            - name: POSTGRESQL_LOG_DISCONNECTIONS
              value: "false"
            - name: POSTGRESQL_PGAUDIT_LOG_CATALOG
              value: "off"
            - name: POSTGRESQL_CLIENT_MIN_MESSAGES
              value: "error"
            - name: POSTGRESQL_SHARED_PRELOAD_LIBRARIES
              value: "pgaudit"
          ports:
            - name: tcp-postgresql
              containerPort: 5432
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -U "postgres" -h 127.0.0.1 -p 5432
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 6
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - -e
                - |
                  exec pg_isready -U "postgres" -h 127.0.0.1 -p 5432
                  [ -f /opt/bitnami/postgresql/tmp/.initialized ] || [ -f /bitnami/postgresql/.initialized ]
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 6
          volumeMounts:
            - name: custom-init-scripts
              mountPath: /docker-entrypoint-initdb.d/
            - name: dshm
              mountPath: /dev/shm
            - name: data
              mountPath: /bitnami/postgresql
              subPath:
      volumes:
        - name: custom-init-scripts
          configMap:
            name: postgresql-init-scripts
        - name: dshm
          emptyDir:
            medium: Memory
            sizeLimit: 1Gi
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "8Gi"
--
--
././postgresql/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - postgresql.yaml
--
--
././oathkeeper/deployment-controller.yaml
--
# Source: oathkeeper/templates/deployment-controller.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-oathkeeper
  namespace: default
  labels:
    app.kubernetes.io/name: oathkeeper
    app.kubernetes.io/version: "v0.38.25-beta.1"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: oathkeeper
  template:
    metadata:
      labels:
        app.kubernetes.io/name: oathkeeper
        app.kubernetes.io/version: "v0.38.25-beta.1"
    spec:
      volumes:
        - name: oathkeeper-config-volume
          configMap:
            name: oathkeeper-config
        - name: oathkeeper-rules-volume
          configMap:
            name: oathkeeper-rules
        - name: oathkeeper-secrets-volume
          secret:
            secretName: oathkeeper-jwk
      containers:
        - name: oathkeeper
          image: "oryd/oathkeeper:v0.38.25-beta.1"
          imagePullPolicy: IfNotPresent
          command:
            ["oathkeeper", "serve", "--config", "/etc/config/config.yaml"]
          env:
            - name: MUTATORS_ID_TOKEN_CONFIG_JWKS_URL
              value: "file:///etc/secrets/mutator.id_token.jwks.json"
          volumeMounts:
            - name: oathkeeper-config-volume
              mountPath: /etc/config
              readOnly: true
            - name: oathkeeper-rules-volume
              mountPath: /etc/rules
              readOnly: true
            - name: oathkeeper-secrets-volume
              mountPath: /etc/secrets
              readOnly: true
          ports:
            - name: oath-api
              containerPort: 4456
              protocol: TCP
            - name: oath-proxy
              containerPort: 4455
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health/alive
              port: oath-api
          readinessProbe:
            httpGet:
              path: /health/ready
              port: oath-api
--
--
././oathkeeper/ingress.yaml
--
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oathkeeper
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: ory.test.info
      http:
        paths:
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: test-oathkeeper-proxy
                port:
                  number: 4455
--
--
././oathkeeper/service-api.yaml
--
---
# Source: oathkeeper/templates/service-api.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-oathkeeper-api
  namespace: default
  labels:
    app.kubernetes.io/name: oathkeeper
    app.kubernetes.io/version: "v0.38.25-beta.1"
spec:
  type: ClusterIP
  ports:
    - port: 4456
      targetPort: oath-api
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: oathkeeper
--
--
././oathkeeper/test-connection.yaml
--
# Source: oathkeeper/templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "test-oathkeeper-test-connection"
  namespace: default
  labels:
    app.kubernetes.io/name: oathkeeper
    app.kubernetes.io/version: "v0.38.25-beta.1"
  annotations:
    "helm.sh/hook": test-success
spec:
  containers:
    - name: liveness-probe
      image: busybox
      command: ["wget"]
      args: ["http://test-oathkeeper-api:4456/health/alive"]
    - name: readiness-probe
      image: busybox
      command: ["wget"]
      args: ["http://test-oathkeeper-api:4456/health/ready"]
  restartPolicy: Never
--
--
././oathkeeper/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment-controller.yaml
  - service-api.yaml
  - service-proxy.yaml
  - ingress.yaml

secretGenerator:
  - name: oathkeeper-jwk
    files:
      - mutator.id_token.jwks.json=secrets/mutator.id_token.jwks.json

configMapGenerator:
  - name: oathkeeper-rules
    files:
      - access-rules.yaml=config/access-rules.yaml
  - name: oathkeeper-config
    files:
      - config.yaml=config/config.yaml
--
--
././oathkeeper/config/access-rules.yaml
--
- id: "ory:kratos:public"
  upstream:
    preserve_host: true
    url: "http://test-kratos-public:4433"
    strip_path: /.ory/kratos/public
  match:
    url: "http://ory.test.info/.ory/kratos/public/<**>"
    methods:
      - GET
      - POST
      - PUT
      - DELETE
      - PATCH
  authenticators:
    - handler: noop
  authorizer:
    handler: allow
  mutators:
    - handler: noop

- id: "ory:kratos:admin"
  upstream:
    preserve_host: true
    url: "http://test-kratos-admin:4434/admin/"
    strip_path: /.ory/kratos/private
  match:
    url: "http://ory.test.info/.ory/kratos/private/<**>"
    methods:
      - GET
      - POST
      - PUT
      - DELETE
      - PATCH
  authenticators:
    - handler: cookie_session
  authorizer:
    handler: remote_json
    config:
      remote: http://keto-api:4456/check
      payload: |
        {
          "namespace": "access",
          "object": "administration",
          "relation": "access",
          "subject_id": "{{print .Extra.identity.traits.role }}"
        }
  mutators:
    - handler: id_token

- id: "ory:kratos-admin-ui-node:protected"
  upstream:
    preserve_host: true
    url: "http://admin-ui:3000"
    strip_path: /admin
  match:
    url: "http://ory.test.info/admin/<**>"
    methods:
      - GET
  authenticators:
    - handler: cookie_session
  authorizer:
    handler: remote_json
    config:
      remote: http://keto-api:4456/check
      payload: |
        {
          "namespace": "access",
          "object": "administration",
          "relation": "access",
          "subject_id": "{{print .Extra.identity.traits.role }}"
        }
  mutators:
    - handler: id_token
  errors:
    - handler: redirect
      config:
        to: http://ory.test.info/panel/welcome

- id: "ory:kratos-selfservice-ui-node:anonymous"
  upstream:
    preserve_host: true
    url: "http://selfservice:4455"
    strip_path: /panel
  match:
    url: "http://ory.test.info/panel/<{welcome,registration,verification,recovery,login,**.css,**.js,**.png}{/,}>"
    methods:
      - GET
  authenticators:
    - handler: anonymous
  authorizer:
    handler: allow
  mutators:
    - handler: noop

- id: "ory:kratos-selfservice-ui-node:protected"
  upstream:
    preserve_host: true
    url: "http://selfservice:4455"
    strip_path: /panel
  match:
    url: "http://ory.test.info/panel/<{debug,panel,settings}>"
    methods:
      - GET
  authenticators:
    - handler: cookie_session
  authorizer:
    handler: remote_json
    config:
      remote: http://keto-api:4456/check
      payload: |
        {
          "namespace": "access",
          "object": "application",
          "relation": "access",
          "subject_id": "{{print .Extra.identity.traits.role }}"
        }
  mutators:
    - handler: id_token
  errors:
    - handler: redirect
      config:
        to: http://ory.test.info/panel/welcome
--
--
././oathkeeper/config/config.yaml
--
log:
  level: debug
  format: json

serve:
  proxy:
    port: 4455
    cors:
      enabled: true
      allowed_origins:
        - "*"
      allowed_methods:
        - POST
        - GET
        - PUT
        - PATCH
        - DELETE
      allowed_headers:
        - Authorization
        - Content-Type
      exposed_headers:
        - Content-Type
      allow_credentials: true
      debug: true
  api:
    port: 4456

errors:
  fallback:
    - json
  handlers:
    redirect:
      enabled: true
      config:
        to: http://ory.test.info/panel/welcome
        when:
          - error:
              - unauthorized
              - forbidden
            request:
              header:
                accept:
                  - text/html
    json:
      enabled: true
      config:
        verbose: true

access_rules:
  matching_strategy: glob
  repositories:
    - file:///etc/rules/access-rules.yaml

authenticators:
  anonymous:
    enabled: true
    config:
      subject: guest
  cookie_session:
    enabled: true
    config:
      check_session_url: http://test-kratos-public:4433/sessions/whoami
      preserve_path: true
      extra_from: "@this"
      subject_from: "identity.id"
      only:
        - ory_kratos_session
  noop:
    enabled: true

authorizers:
  allow:
    enabled: true
  remote_json:
    enabled: true
    config:
      remote: http://keto-api:4456/check
      payload: |
        {
          "subject": "{{ print .Subject }}",
          "resource": "{{ printIndex .MatchContext.RegexpCaptureGroups 0 }}"
        }

mutators:
  noop:
    enabled: true
  id_token:
    enabled: true
    config:
      issuer_url: http://ory.test.info/panel/
      jwks_url: file:///etc/config/oathkeeper/id_token.jwks.json
      claims: |
        {
          "session": {{ .Extra | toJson }}
        }
--
--
././oathkeeper/service-proxy.yaml
--
---
# Source: oathkeeper/templates/service-proxy.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-oathkeeper-proxy
  namespace: default
  labels:
    app.kubernetes.io/name: oathkeeper
    app.kubernetes.io/version: "v0.38.25-beta.1"
spec:
  type: ClusterIP
  ports:
    - port: 4455
      targetPort: oath-proxy
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: oathkeeper
--
--
././admin-ui/ingress.yaml
--
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: admin-ui-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: admin-ui.test.info
      http:
        paths:
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: admin-ui
                port:
                  number: 3000
--
--
././admin-ui/service.yaml
--
# Source: kratos/templates/service-admin.yaml
apiVersion: v1
kind: Service
metadata:
  name: admin-ui
  namespace: default
  labels:
    app.kubernetes.io/name: admin-ui
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: admin-ui
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: admin-ui
--
--
././admin-ui/deployment.yaml
--
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
  namespace: default
  labels:
    app.kubernetes.io/name: admin-ui
  annotations:
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: admin-ui
  template:
    metadata:
      labels:
        app.kubernetes.io/name: admin-ui
      annotations:
    spec:
      volumes:
        - name: script-volume
          configMap:
            name: admin-ui-script
            defaultMode: 0777
      containers:
        - name: admin-ui
          image: "pingouin/react-admin-kratos:latest"
          imagePullPolicy: Always
          envFrom:
            - configMapRef:
                name: admin-ui-env
          ports:
            - name: admin-ui
              containerPort: 80
              protocol: TCP
          volumeMounts:
            - name: script-volume
              mountPath: /docker-entrypoint.d/40-rename.sh
              subPath: 20-rename.sh
--
--
././admin-ui/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml

configMapGenerator:
  - name: admin-ui-env
    envs:
      - config/admin-ui.env
  - name: admin-ui-script
    files:
      - 20-rename.sh=config/rename.sh
--
--
././kubernetes-skooner.yaml
--
kind: Deployment
apiVersion: apps/v1
metadata:
  name: skooner
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: skooner
  template:
    metadata:
      labels:
        k8s-app: skooner
    spec:
      containers:
      - name: skooner
        image: ghcr.io/skooner-k8s/skooner:stable
        ports:
        - containerPort: 4654
        livenessProbe:
          httpGet:
            scheme: HTTP
            path: /
            port: 4654
          initialDelaySeconds: 30
          timeoutSeconds: 30
      nodeSelector:
        'kubernetes.io/os': linux

---
kind: Service
apiVersion: v1
metadata:
  name: skooner
  namespace: kube-system
spec:
  ports:
    - port: 80
      targetPort: 4654
  selector:
    k8s-app: skooner
--
--
././keto/keto-job/job.yaml
--
apiVersion: batch/v1
kind: Job
metadata:
  name: keto-add-policies
spec:
  template:
    metadata:
      name: keto-add-policies
    spec:
      volumes:
        - name: keto-access-policy-volume
          configMap:
            name: keto-access-policy
      containers:
        - name: keto-add-policies
          image: oryd/keto:v0.8.0-alpha.2
          args: ["relation-tuple", "create", "/policies/access-policy.json"]
          volumeMounts:
            - name: keto-access-policy-volume
              mountPath: /policies/access-policy.json
              subPath: access-policy.json
          env:
            - name: KETO_WRITE_REMOTE
              value: keto-api:4457
            - name: KETO_READ_REMOTE
              value: keto-api:4456
      restartPolicy: Never
--
--
././keto/keto-job/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - job.yaml

configMapGenerator:
  - name: keto-access-policy
    files:
      - access-policy.json=config/relation-tuples/admin-access.json
--
--
././keto/sa.yaml
--
# Source: keto/templates/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-keto
  labels:
    app.kubernetes.io/name: keto
    app.kubernetes.io/instance: test-keto
    app.kubernetes.io/version: "v0.8.0"
--
--
././keto/service.yaml
--
# Source: kratos/templates/service-admin.yaml
apiVersion: v1
kind: Service
metadata:
  name: keto-api
  namespace: default
  labels:
    app.kubernetes.io/name: keto
spec:
  type: ClusterIP
  ports:
    - port: 4456
      targetPort: keto-read-api
      protocol: TCP
      name: http-keto-read-api
    - port: 4457
      targetPort: keto-write-api
      protocol: TCP
      name: http-keto-write-api
  selector:
    app.kubernetes.io/name: keto
--
--
././keto/deployment.yaml
--
# Source: keto/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-keto
  namespace: default
  labels:
    app.kubernetes.io/name: keto
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: keto
      app.kubernetes.io/instance: test-keto
  template:
    metadata:
      labels:
        app.kubernetes.io/name: keto
        app.kubernetes.io/instance: test-keto
    spec:
      serviceAccountName: test-keto
      automountServiceAccountToken: true
      volumes:
        - name: keto-config-volume
          configMap:
            name: keto-config
      initContainers:
        - name: keto-automigrate
          image: "oryd/keto:v0.8.0-alpha.2"
          imagePullPolicy: IfNotPresent
          command: ["keto"]
          args: ["migrate", "up", "-y", "--config", "/etc/config/keto.yaml"]
          volumeMounts:
            - name: keto-config-volume
              mountPath: /etc/config
              readOnly: true
          env:
            - name: DSN
              valueFrom:
                secretKeyRef:
                  name: keto-secret
                  key: dsn
      containers:
        - name: keto
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 100
          image: "oryd/keto:v0.8.0-alpha.2"
          imagePullPolicy: IfNotPresent
          command: ["keto"]
          args: ["serve", "--config", "/etc/config/keto.yaml"]
          volumeMounts:
            - name: keto-config-volume
              mountPath: /etc/config
              readOnly: true
          env:
            - name: DSN
              valueFrom:
                secretKeyRef:
                  name: keto-secret
                  key: dsn
          ports:
            - name: keto-write-api
              containerPort: 4457
              protocol: TCP
            - name: keto-read-api
              containerPort: 4456
              protocol: TCP
            - name: http-metrics
              containerPort: 4468
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health/alive
              port: keto-write-api
            failureThreshold: 5
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: keto-write-api
            failureThreshold: 5
            initialDelaySeconds: 30
            periodSeconds: 10
--
--
././keto/kustomization.yaml
--
kind: Kustomization
apiVersion: kustomize.config.k8s.io/v1beta1

resources:
  - deployment.yaml
  - service.yaml
  - sa.yaml

secretGenerator:
  - name: keto-secret
    envs:
      - secrets/keto.env

configMapGenerator:
  - name: keto-config
    files:
      - keto.yaml=config/keto.yaml
--
--
././keto/config/keto.yaml
--
version: v0.8.0-alpha.2

dsn: fromEnv

namespaces:
  - id: 0
    name: access

serve:
  metrics:
    port: 4468
    host: 0.0.0.0
  read:
    port: 4456
    host: 0.0.0.0
  write:
    port: 4457
    host: 0.0.0.0

log:
  level: debug
--
