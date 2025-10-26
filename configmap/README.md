# ConfigMap

## What are Kubernetes ConfigMaps
- Kubernetes ConfigMaps are builtin Kubernetes API Objects that store your applications non-sensitive key-value config data. 
- ConfigMaps allow you to keep config values separate from your code and container images. Values can be Strings or Base64-encoded binary data.
- ConfigMaps are intended to store relatively small amounts of simple data. The total size of a ConfigMap object must be less than 1MB. If you need to store data, you should split your configuration into multiple ConfigMaps or consider using a separate database or key-value store

## What is a Kubernetes ConfigMap used for?
- A kubernetes ConfigMap us used to provide configuration values to applications in a way that is decoupled from application code. It allows you to externalize environment-specific settings, such as a database hostname or IP addresses, without modifying the container image.
- ConfigMaps are ideal when application deployments require settings that may change independently of code updates.
- ConfigMaps also supports pre-configuration =: users can create them before deploying an application, customize the behaviour without altering the deployment process.

## Where are ConfigMaps stored in Kubernetes?
- Kubernetes stores ConfigMaps in its etcd datastore. You shouldn't directly edit etcd data; instead use the Kubernetes API Server and kubectl to create and manage your ConfigMaps.

## How to use Kubernetes ConfigMaps
- ConfigMaps are regular Kubernetes API Objects, you can create them using YAML manifest files
- They require top-level `data` field that defines the key-value config pairs to store. Key can only contain alphanumeric characters and the `.`, `-`, and `_` symbols.

### Using `data` & `binaryData` fields
- When we use `data` filed, the ConfigMap values must be strings
- ConfigMaps also support binary data within separate `binaryData` field. BinaryValues need to be Base64-encoded

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: demo-config
    data:
      database_host: "192.168.10.1"
      debug_mode: "1"
      log_level: "verbose"
    ```

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: demo-config-bin
    binaryData:
      file_name: RGVtbwo=
    ```
- You can also use `data` & `binaryData` in a single ConfigMap, but each key can only appear once -- either in `data` or in `binaryData`

### Listing & Inspecting ConfigMaps
- You can use `kubectl get` command to list the ConfigMaps that are already created

    ```commandline
    
    controlplane:~$ kubectl get configmap
    NAME               DATA   AGE
    demo-bin-config    1      23s
    demo-config        3      23s
    ```

- To inspect the key-value pairs within a ConfigMap, use `kubectl describe`

    ```commandline
    
    controlplane:~$ kubectl describe configmap/demo-config 
    Name:         demo-config
    Namespace:    default
    Labels:       <none>
    Annotations:  <none>
    
    Data
    ====
    database_host:
    ----
    192.168.10.1
    
    debug_mode:
    ----
    1
    
    log_level:
    ----
    verbose
    
    
    BinaryData
    ====
    
    Events:  <none>
    ```

- The ConfigMap content is visible under `Data` & `BinaryData` headings
- To get the ConfigMap data as JSON, you can use below command

    ```commandline
    
    controlplane:~$ kubectl get configmap/demo-config -o jsonpath={.data} | jq
    {
      "database_host": "192.168.10.1",
      "debug_mode": "1",
      "log_level": "verbose"
    }
    ```
  
### Mounting ConfigMaps into Pod as environment variables
- Once you've created a ConfigMap, you can consume it within your Pods. You can access all or part of a ConfigMap as environment variables, command line arguments, or mounted files.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      containers:
        - name: app
          image: busybox:latest
          command:
            - "/bin/sh"
            - "-c"
            - "printenv"
          envFrom:
            - configMapRef:
                name: demo-config
    ```

- The `envFrom` field instructs Kubernetes to create environment variables from the sources nested within it. The `ConfigMapRef` refer to a ConfigMap by its name and selects all its key-value pairs.
- Deploy the above pod and we can view the pod environment 

    ```commandline
    controlplane:~$ kubectl apply -f demo-pod.yaml 
    pod/demo-pod created
    
    controlplane:~$ kubectl logs pod/demo-pod 
    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_PORT=tcp://10.96.0.1:443
    HOSTNAME=demo-pod
    SHLVL=1
    HOME=/root
    KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    debug_mode=1
    KUBERNETES_PORT_443_TCP_PORT=443
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    log_level=verbose
    KUBERNETES_SERVICE_PORT_HTTPS=443
    KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
    KUBERNETES_SERVICE_HOST=10.96.0.1
    PWD=/
    database_host=192.168.10.1
    ```
  
- Sometimes a Pod won't require access to all the values contained in a ConfigMap. For example, you have another pod which only utilizes the `log_level` value from our demo ConfigMap.
- The `env.valueFrom` syntax can be used instead of `envFrom` for this usecase. It lets you select individual keys in a ConfigMap. Keys can also rename to a different environment variables

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      containers:
        - name: app
          image: busybox:latest
          command:
            - "/bin/sh"
            - "-c"
            - "printenv"
          env:
            - name: logging_mode
              valueFrom:
                configMapKeyRef:
                  name: demo-config
                  key: log_level
    ```

- If we deploy this pod, we could see the `logging_level` environment variable printed in pod logs

    ```commandline
    
    ontrolplane:~$ kubectl apply -f demo-pod2.yaml 
    pod/demo-pod2 created
    
    controlplane:~$ kubectl logs pod/demo-pod2 
    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_PORT=tcp://10.96.0.1:443
    HOSTNAME=demo-pod2
    SHLVL=1
    HOME=/root
    KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    KUBERNETES_PORT_443_TCP_PORT=443
    logging_mode=verbose
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    KUBERNETES_SERVICE_PORT_HTTPS=443
    KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
    KUBERNETES_SERVICE_HOST=10.96.0.1
    PWD=/
    ```
  
### Mounting ConfigMaps into Pods as commandline arguments
- ConfigMap values can be interpolated into a container's command line arguments by first referencing the relevant ConfigMap key as an environment variable:
- This technique allows you to change the command that's run when your container start, based on the current content of your ConfigMap. It supports scenarios where your ap expects configuration to be supplied directly to its process upon startup.

    ```yaml
    
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      containers:
        - name: app
          image: demo-app:latest
          command:
            - "demo-app"
            - "--database-host"
            - "$(DATABASE_HOST)"
          env:
            - name: DATABASE_HOST
              valueFrom:
                configMapKeyRef:
                  key: database_host
                  name: demo-config
    ```

### Mounting ConfigMaps into Pods as Volumes
- Environment Variables and commandline arguments can become unwieldy when you have many different values, or values containing a large amount of data.
- ConfigMaps can be mounted as volumes instead, allowing your app to read its config values from files within the container's filesystem.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      containers:
        - name: app
          image: busybox:latest
          command:
            - "/bin/sh"
            - "-c"
            - "ls -l /etc/app-config"
          volumeMounts:
            - mountPath: /etc/app-config
              name: config
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: demo-config
    ```

- When we deploy the pod, the logs show the output from configured command `/bin/sh -c ls -l /etc/app-config`. The command confirms there are three files within the directory, corresponding to the keys in ConfigMap.

    ```commandline
    
    controlplane:~$ kubectl apply -f demo-pod-cm-vol.yaml 
    pod/demo-pod created
    
    controlplane:~$ kubectl get pod/demo-pod
    NAME       READY   STATUS      RESTARTS   AGE
    demo-pod   0/1     Completed   0          10s
    
    controlplane:~$ kubectl logs pod/demo-pod 
    total 0
    lrwxrwxrwx    1 root     root            20 Oct 26 23:26 database_host -> ..data/database_host
    lrwxrwxrwx    1 root     root            17 Oct 26 23:26 debug_mode -> ..data/debug_mode
    lrwxrwxrwx    1 root     root            16 Oct 26 23:26 log_level -> ..data/log_level
    ```
  
### Using immutable ConfigMaps
- The ConfigMaps we've created so far have been mutable, you can modify them at any time by adding, changing and removing keys.
- In practice, many applications are configured once and expected to stay in the same configuration throughout their lifetime.
- ConfigMaps can be marked as immutable to facilitate this usecase. An immutable ConfigMap cannot be edited, and you'll see an error if you try to apply changes.
- This enhances safety by preventing accidental modification or deletion of ConfigMap keys that your app depends on. This improves performance of your cluster by significantly reducing load on kube-apiserver, by closing watches for ConfigMaps marked as immutable.
- To create an immutable ConfigMap, set the filed `immutable: true`.

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: nginx-config
    data:
      nginx.conf: |
        events {}
    
        http{
          server{
            listen 443 ssl;
        
            ssl_certificate /etc/nginx/ssl/tls.crt;
            ssl_certificate_key /etc/nginx/ssl/tls.key;
        
            root /usr/share/nginx/html;
            index index.html;
        
            location / {
              try_files $uri /index.html;
            }
          }
        }
    immutable: true
    ```

## ConfigMap Limitations
A ConfigMap in kubernetes has several limitations, particularly around size, data types, mounting, and versioning.
- **Size Limits**: The total size of a ConfigMap, include all keys and values, is limited to 1MiB. This limit is enforced because ConfigMaps are stored in etcd, which has performance and stability constraints. An excessive size or number of ConfigMaps can lead to etcd degradation.
- **Data type restrictions**: ConfigMaps store only string data as key-value pairs. If you need to store structured or non-string data type (JSON, integers, booleans) they must be manually serialized to strings
- **Mounting Limitations**: When mounted as volumes, each key is presented as a separate file in the container filesystem. This approach is subjected to the filesystem limitation such as inode count, maximum filename length, and directory path length.
- **Versioning and Updates**: ConfigMaps do not support versioning or automatic change propagation. Changes don't automatically update environment variables or files inside running pods. For mounted volumes, changes might be reflected depending on runtime behaviour, but applications must explicitly reload them. For environment variables, a pod restart is required