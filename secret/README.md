# Secrets

- A secret is an object that contains small amount of sensitive data such as password, a token, or a key. Such information might otherwise be put in a Pod specification or in a container image.
- Secrets can be created independently of the Pod that use them, there is less risk of the Secret (and its data) being exposed during the workflow of creating, viewing, and editing Pods.
- Kubernetes and applications that run inside your cluster, can also take additional precautions with secrets, such as avoiding writing sensitive data to nonvolatile storage.
- Secrets are similar to ConfigMaps but are specially intended to hold confidential data.

## Uses for Secrets:
You can use secrets for purposes such as the following:
- Set environment variable for a container
- Provide credentials such as SSH keys or passwords to Pods
- Allow the kubelet to pull container images from private registry.

### Use case: dotfiles in a secret volume
- You can make your data `hidden` by defining a key that begins with a dot. This key represents a dotfile or "hidden" file.
- For example, when the following Secret is mounted into a volume, `secret-volume`, the volume will contain a single file, called `.secret-file` and the `dotfile-test-container` wil hae this file present at the path `/etc/secret-volume/.secret-file`.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dotfile-secret
data:
  .secret-file: REFUQUJBU0VfUEFTU1dPUkQ6IFBhMTUzMzF3MHJkQDEyMwo=

---

apiVersion: v1
kind: Pod
metadata:
  name: dotfile-secret-pod
spec:
  containers:
    - name: dotfile-test-container
      image: busybox
      command:
        - "/bin/sh"
        - "-c"
        - "ls -la"
      volumeMounts:
        - mountPath: /etc/secret-volume
          name: secret-volume
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: dotfile-secret
```

### Use case: Secret visible to one container in a Pod

- Consider a program that needs to handle HTTP requests, do some complex business logic, and then sign some messages with an HMAC.
- Because it has complex application logic, there might be an unnoticed remote file reading exploit in the server, which could expose the private key to an attacker.
- This could be divided into two processes in two containers: a frontend container which handles user interaction and business logic, but which cannot see the private key; and a signer container that can see the private key, and responds to simple signing requests from the frontend.

### Alternatives to Secrets
Rater than using a Secret to protect confidential data, you can pick from alternatives.
- If your cloud-native component needs to authenticate to another application that you know is running with the same kubernetes cluster, you can use a *ServiceAccount* and its tokens to identify your client.
- There are third-party tools that you can run, either with or outside your cluster, that manage sensitive data. For example, a service that Pods access over HTTPS, that reveals a Secret if the client correctly authenticates (ex: with a ServiceAccount token)
- For authentication, you can implement a custom signer for X.509 certificates, and use *CertificateSigningRequests* to let that custom signer issue certificate to Pods that need them.
- You can use a device plugin to expose node-local encryption hardware to a specific Pod. Foe example, you can schedule trusted Pods onto nodes that provide a Trusted Platform Module, configured out-of-band.

## Types of Secrets
- When creating a Secret, you can specify its type using the `type` filed of the Secret resource, or certain equivalent kubectl command line flags
- The secret type is used to facilitate programmatic handling of the secret data
- Kubernetes provides several built-in types for some common usage scenarios. These types vary in terms of the validations performed and the constraints kubernetes imposes on them.
  - `Opaque`: arbitrary user-defined data
  - `kubernetes.io/service-account-token`: Service Account Token
  - `kubernetes.io/dockercfg`: serialized ~/.dockercfg file
  - `kubernetes.io/dockerconfigjson`: serialized ~/.dockerconfig.json file
  - `kubernetes.io/basic-auth`: Credentials for basic authentication
  - `kubernetes.io/ssh-auth`: Credentials for ssh authentication
  - `kubernetes.io/tls`: data for a TLS client or server
  - `bootstrap.kubernetes.io/token`: bootstrap token data
- You can define and use your own Secret type by assigning a non-empty string as the `type` value for a Secret object (an empty string is treated as an `Opaque` type)
- If you are defining a type of Secret that's for public use, follow the convention and structure the Secret type to have your domain name before the name, separated by a `/`. For example: `cloud-hosting.example.net/cloud-api-credentials`


### Opaque Secrets
- `Opaque` is the default secret type if you don't explicitly specify a type in a Secret manifest. When you create a Secret using `kubectl`, you must use the `generic` subcommand to indicate it an `Opaque` Secret type.
- Example:
    ```commandline
    controlplane:~$ kubectl create secret generic empty-secret
    secret/empty-secret created
    
    controlplane:~$ kubectl get secret
    NAME           TYPE     DATA   AGE
    empty-secret   Opaque   0      6s
    ```
- The `DATA` column shows the number of data items stored in the secret. In this case, `0` means you have created an empty set.

### Service Account token secret
- A `kubernetes,io/service-account-token` type of Secret is used to store a token credentials that identifies a ServiceAccount. This is a legacy mechanism that provides long-lived ServiceAccount credentials to Pods.
- In Kubernetes V1.22 and later, the recommended approach is to obtain a short-lived, automatically rotating ServiceAccount token by using the `TokenRequest` API instead.
- When using this Secret type, you need to ensure that the `kubernetes.io/service-account.name` annotation is set to an existing ServiceAccount name.
- If you are creating both the ServiceAccount and Secret, the ServiceAccount should be created first.
- After the Secret is created, a Kubernetes controller fills in some other filed such as the `kubernestes.io/service-account.uid` annotation, and the `token` key in the data field which is populated with an authentication token.

```yaml
apiVersion: v1
metadata:
  name: secret-sa
  annotations:
    kubernetes.io/service-account.name: "sa-name"
type: kubernetes.io/service-account-token
data:
  extra: dGVzdAo=
```

- After creating the Secret, wait for the kubernetes to populate the token key in the `data` filed.

### Docker Config Secrets
- If you are creating a Secret to store credentials for accessing a container image registry, you must use one of the following `type` values for that Secret:
  - `kubernetes.io/dockercfg`: stores a serialized `~/.dockercfg` which is the legacy format for configuring Docker command line. The Secret data filed contains a `.dockercfg` key whose value is the content of base64 encoded `~/.dockercfg` file.
  - `kubernetes.io/dockerconfigjson`: stores a serialized JSON that follows the same format rules as the `~/.docker/config.json` file, which is a new format for `~/.dockercfg`. The Secret data filed must contain a `.dockerconfigjson` key for which the value is the content of base64 encoded `~/.docker/config.json` file.
  - Below is the example of a `kubernetes.io/dockercfg`

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: secret-dockercfg
    type: kubernetes.io/dockercfg
    data:
      .dockercfg: |
        eyJhdXRocyI6eyJodHRwczovL2V4YW1wbGUvdjEvIjp7ImF1dGgiOiJvcGVuc2VzYW1lIn19fQo=
    ```
- When you create Docker config secrets using a manifest, the API server checks whether the expected key exists in the `data` filed, and it verifies if the value provided can be parsed as a valid JSON. The API Server doesn't validate if the JSON actually is a Docker config file.
- You can also use kubectl to create a Secret for accessing a container registry, such as when you don;t have a Docker configuration file:
    ```commandline
    kubectl create secret docker-registry secret-tiger-docker \
      --docker-email=tiger@acme.example \
      --docker-username=tiger \
      --docker-password=pass1234 \
      --docker-server=my-registry.example:5000
    ```
- This command creates a secret of type `kubernetes.io/dockerconfigjson`, Retrieve the `.data.dockerconfigjson` filed from the secret and decode the value

    ```json
    {
      "auths": {
        "my-registry.example:5000": {
          "username": "tiger",
          "password": "pass1234",
          "email": "tiger@acme.example",
          "auth": "dGlnZXI6cGFzczEyMzQ="
        }
      }
    }
    ```


### Basic Authentication Secret
- The `kubernetes.io/basic-auth` type is provided for strong credentials needed for basic authentication. When using this Secret type, the data filed of the Secret must contain one of the following two keys:
  - `username`: the username for authentication
  - `password`: the password or token for authentication
- Both values for the above two keys are base64 encoded strings. You can alternatively provide the clear text content using the `stringData` filed in the Secret manifest.
- The following is the example of basic auth secret

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: basic-auth-secret
    type: kubernetes.io/basic-auth
    stringData:
      username: admin
      password: pass123
    ```

### SSH authentication secrets
- The builtin type `kubernetes.io/ssh-auth` is provided for storing data used in SSH authentication. When using this Secret type, you will have to specify a `ssh-privatekey` key-value pair in the `data` (or `stringData`) filed as SSH credential to use.
- The following manifest is an example of a Secret used for SSH public/private ket authentication:

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: secret-ssh-auth
    type: kubernetes.io/ssh-auth
    data:
      ssh-privatekey: |
        UG91cmluZzYlRW1vdGljb24lU2N1YmE=
    ```
- The SSH authentication Secret type is provided only for convenience. You can create an `Opaque` type for credentials used for SSH authentication.
- However, using the defined and public secret type (`kubernetes.io/ssh-auth`) helps other people to understand the purpose of your secret, and sets a convention for what key name to expect.

### TLS Secrets
- The `kubernetes.io/tls` Secret type is for storing a certificate and its associated key that are typically use for TLS.
- One common use for TLS Secrets is to configure encryption in transit for an ingress, but you can also use it with other resources or directly in your workload.
- When using this type of Secret, the `tls.key` and the `tls.crt` key must be provided in the `data` (or `stringData`) field of the Secret configuration, although the API server doesn't actually validate the values of each key.

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: tls-secret
    type: kubernetes.io/tls
    data:
      # values are base64 encoded
      tls.crt: "<CERTIFICATE_BASE64>"
      tls.key: "<CERT_KEY_BASE_64"
    ```

### Bootstrap token secrets
- The `bootstrap.kubernetes.io/token` Secret type is for tokens used during the node bootstrap process. It stores tokens used to sign well-known ConfigMaps.
- A bootstrap token Secret is usually created in the `kube-system` namespace and named in the form `bootstrap-token-<token-id>` where `<token-id>` is a 6 character string of token ID.
- As a kubernetes manifest,a bootstrap token Secret might look like the following:

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: bootstrap-token-5emitj
      namespace: kube-system
    type: bootstrap.kubernetes.io/token
    data:
      auth-extra-groups: c3lzdGVtOmJvb3RzdHJhcHBlcnM6a3ViZWFkbTpkZWZhdWx0LW5vZGUtdG9rZW4=
      expiration: MjAyMC0wOS0xM1QwNDozOToxMFo=
      token-id: NWVtaXRq
      token-secret: a3E0Z2lodnN6emduMXAwcg==
      usage-bootstrap-authentication: dHJ1ZQ==
      usage-bootstrap-signing: dHJ1ZQ==
    ```
- A bootstrap token Secret has the following keys specified under `data`:
  - `token-id` (required): A random 6 character string as the token identifier
  - `token-secret` (required): A random 16 character string as the actual token Secret.
  - `description` (Optional): A human-readable string that describes what the token is used for
  - `expiration` (Optional): An absolute UTC time using RFC339 specifying when the token should be expired.
  - `usage-bootstarp-<usage>`: A boolean flag indicating additional usage for the bootstrap token.
  - `auth-extra-groups`: A comma-separated list of group names that will be authenticated as in addition to the `system:bootstrappers` group.
