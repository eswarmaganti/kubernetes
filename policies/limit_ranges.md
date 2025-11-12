# Limit Ranges

- By default, containers run with unbound compute resources on a Kubernetes cluster.
- Using Kubernetes resource quotas, administrators can restrict consumption and creation of cluster resources (such as CPU time, memory, and persistent storage) within a specified namespace.
- Within a namespace, a Pod can consume as much CPU and memory as is allowed by the Resource Quotas that apply to that namespace. As an administrator you might also be concerned about making sure that a single object cannot monopolize all available resources within a namespace.

- **A `LimitRange` is a policy to constrain the resource allocations (limits and requests) that you can specify for each applicable object kind (such as Pod or PersistentVolumeClaim) in a namespace**.
- A *LimitRange* provides constraints that can:
  - Enforce minimum and maximum compute resources usage per Pod or Container in a namespace.
  - Enforce minimum and maximum storage request per PersistentVolumeClaim in a namespace.
  - Enforce a ratio between request and limit for a resource in a namespace.
  - Set default request/limit for compute resources in a namespace and automatically inject them to Containers at runtime.
- Kubernetes constrains resource allocations to Pods in a particular namespace whenever there is at least on LImitRange object in that namespace.
- The name of a LimitRange object must be a valid DNS subdomain name.

## Constraints on  resource limits and requests
- The administrator creates a LimitRange in a namespace
- Users create objects in that namespace, such as Pods or PersistentVolumeClaims.
- First, the LimitRange admission controller applies default request and limit values for all Pods (and their containers) that do not set compute resources requirements.
- Second, the LimitRange tracks usage to ensure it does not exceed resource minimum, maximum and ratio defines in ant LimitRange persent in the namespace.
- *If you attempt to create or update an object that violates a LimitRange constraint, your request to the API server will fail with an HTTP status code `403 Forbidden` and a message explaining the constraint that has been violated.*
- *If you add a LimitRange in a namespace that applies to compute-related resources such as `cpu` and `memory`, you must specify requests and limits for those values. Otherwise, the system may reject the Pod creation.*
- *LimitRange validations occur only at Pod admission stage, not on running Pods. If you add or modify a LimitRange, the Pods that already exist in that namespace continue unchanged.*
- If two or more LimitRange objects exists in the namespace, it is not deterministic which default value will be applied.

## LimitRange and admission checks for Pods
- A LimitRange does not check the consistency of the default values it applies. This means that a default value for the limit that is set by LimitRange may be less than the request value specified for the container in the spec that a client submits to the API server. If that happens the Pod will not be schedulable.
- For example, you define a LimitRange with below manifest

    ```yaml
    apiVersion: v1
    kind: LimitRange
    metadata:
      name: cpu-resource-constraint
      namespace: test
    spec:
      limits:
        - type: Container
          default: # this section defines the default limits
            cpu: 500m
          defaultRequest: # this section defines the default requests
            cpu: 500m
          max: # max and min define the limit ranges
            cpu: "1"
          min:
            cpu: 100m
    ```
  
- Example: Lets create a Pod that requests CPU resources of 700m but no limit.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: test
      name: test-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: 700m
    ```
- We wil first create a `test` namespace and deploy the limit range `cpu-resource-constraint`. Then we will test the Pod `test-pod` will be created or not by deploying the Pod spec.

    ```commandline
    controlplane:~$ kubectl create namespace test
    namespace/test created
    controlplane:~$ 
    controlplane:~$ kubectl get namespaces
    NAME                 STATUS   AGE
    default              Active   18d
    kube-node-lease      Active   18d
    kube-public          Active   18d
    kube-system          Active   18d
    local-path-storage   Active   18d
    test                 Active   7s
    
    controlplane:~$ kubectl apply -f limit-range.yaml 
    limitrange/cpu-resource-constraint created
    controlplane:~$ kubectl get limitrange -n test
    NAME                      CREATED AT
    cpu-resource-constraint   2025-11-07T00:27:53Z
    controlplane:~$ kubectl describe limitrange/cpu-resource-constraint -n test
    Name:       cpu-resource-constraint
    Namespace:  test
    Type        Resource  Min   Max  Default Request  Default Limit  Max Limit/Request Ratio
    ----        --------  ---   ---  ---------------  -------------  -----------------------
    Container   cpu       100m  1    500m             500m           -
    controlplane:~$ 
    
    
    controlplane:~$ kubectl apply -f test-pod.yaml 
    The Pod "test-pod" is invalid: spec.containers[0].resources.requests: Invalid value: "700m": must be less than or equal to cpu limit of 500m
    ```

- If we deploy the Pod, it fails with error `spec.containers[0].resources.requests: Invalid value: "700m": must be less than or equal to cpu limit of 500m`
- If we set both requests and limits as shown below and deploy the Pod, no errors will be observed.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: test
      name: test-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: 700m
            limits:
              cpu: 700m
    ```
- Try to redeploy the Pod, we will observe no error's this time.
    ```commandline
    controlplane:~$ kubectl apply -f test-pod.yaml 
    pod/test-pod created
    controlplane:~$ kubectl get pod/test-pod -n test
    NAME       READY   STATUS    RESTARTS   AGE
    test-pod   1/1     Running   0          13s
    ```
  
## Example resource constraints
Example of policies that could be created using LimitRange are:
- In a 2 node cluster with a capacity of 8 Gib RAM and 16 cores, constrain Pods in a namespace to request 100m of CPU with a max limit of 500m for CPU and request 200Mi for memory with a max limit of 600Mi for memory.
- Define default CPU limit and request to 150m and memory default request to 300Mi for containers started with no cpu and memory requests in their specs.

In the case where the total limits of the namespace is less than the sum of the Pods/Containers, there may be contention for resources. In this case, the Containers or Pods will not be created.

<hr/>

## Configure Minimum and Maximum CPU Constraints for a Namespace

Define a range of valid CPU resource limits for a namespace, so that every new Pod in that namespace falls within the range you configure.

### Create a namespace
Create a namespace so that the resources you create in this exercise are isolated from the rest of the cluster

```commandline
controlplane:~$ kubectl create namespace cpu-constraints
namespace/cpu-constraints created
controlplane:~$ kubectl get namespace/cpu-constraints
NAME              STATUS   AGE
cpu-constraints   Active   14s
```

### Crate a LimitRange Object and a Pod

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-constraints
spec:
  limits:
    - max: 
        cpu: "800m"
      min: 
        cpu: "200m"
      type: Container
```

```commandline
controlplane:~$ kubectl apply -f cpu-limit-range.yaml -n cpu-constraints 
limitrange/cpu-constraints created
controlplane:~$ kubectl get limitrange -n cpu-constraints 
NAME              CREATED AT
cpu-constraints   2025-11-08T23:51:12Z
```

- When we view the detailed information about the LimitRange object created, The output shows the minimum and maximum CPU constraints as expected. But notice that even through you didn't specify default values in the configuration file for the LimitRange, they were created automatically.

    ```yaml
    controlplane:~$ kubectl get limitrange -n cpu-constraints -o=yaml
    apiVersion: v1
    items:
    - apiVersion: v1
      kind: LimitRange
      metadata:
        annotations:
          kubectl.kubernetes.io/last-applied-configuration: |
            {"apiVersion":"v1","kind":"LimitRange","metadata":{"annotations":{},"name":"cpu-constraints","namespace":"cpu-constraints"},"spec":{"limits":[{"max":{"cpu":"800m"},"min":{"cpu":"200m"},"type":"Container"}]}}
        creationTimestamp: "2025-11-08T23:51:12Z"
        name: cpu-constraints
        namespace: cpu-constraints
        resourceVersion: "10266"
        uid: dff84606-9a4f-400d-82e7-0039f78da72d
      spec:
        limits:
        - default:
            cpu: 800m
          defaultRequest:
            cpu: 800m
          max:
            cpu: 800m
          min:
            cpu: 200m
          type: Container
    kind: List
    metadata:
      resourceVersion: ""
    ```

- Now whenever you create a Pod in the *cpu-constraints* namespace kubernetes performs these steps:
  - If any container in that Pod does not specify its own CPU request and limit to that container.
  - Verify that every container in that Pod specified a CPU request that is greater than or equal to 200m
  - Verify that every container in that Pod specifies a CPU limit that is less than or equal to 800m

- `Example 1`: The below Pod manifest specifies a container with CPU request 500m and a CPU limit 800m. These specify the minimum and maximum CPU constraints imposed by the LimitRange for this namespace

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: cpu-demo-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "500m"
            limits:
              cpu: "800m"
    ```

- We will try to deploy the Pod and view its details

    ```commandline
    controlplane:~$ kubectl apply -f cpu-demo-pod.yaml -n cpu-constraints 
    pod/cpu-demo-pod created
    controlplane:~$ kubectl get pods -n cpu-constraints 
    NAME           READY   STATUS              RESTARTS   AGE
    cpu-demo-pod   0/1     ContainerCreating   0          10s
    controlplane:~$ kubectl get pods -n cpu-constraints 
    NAME           READY   STATUS    RESTARTS   AGE
    cpu-demo-pod   1/1     Running   0          17s
    ```
- `Example 2`: **Attempt to create a Pod that exceeds the maximum CPU limit constraint.** The below manifest specifies a container request CPU of 500m and a CPU limit of 1.5 
    
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: cpu-demo-pod-2
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "500m"
            limits:
              cpu: "1.5"
    ```
- When we try to deploy the Pod, we will see the below error `403 Forbidden`

    ```commandline
    controlplane:~$ kubectl apply -f cpu-demo-pod-2.yaml -n cpu-constraints 
    Error from server (Forbidden): error when creating "cpu-demo-pod-2.yaml": pods "cpu-demo-pod-2" is forbidden: maximum cpu usage per Container is 800m, but limit is 1500m
    ```

- `Example 3`: **Attempt to create a Pod that doesn't meet the minimum CPU request.** The below manifest specifies a container spec with CPU request of 100m and a CPU limit of 800m

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: cpu-demo-pod-3
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "100m"
            limits:
              cpu: "800"
    ```

- When we try to deploy the pod, we will see the below error. Thr output shows that the Pod does not get created, because it defines an unacceptable container.

    ```commandline
    controlplane:~$ kubectl apply -f cpu-demo-pod-3.yaml -n cpu-constraints 
    Error from server (Forbidden): error when creating "cpu-demo-pod-3.yaml": pods "cpu-demo-pod-3" is forbidden: minimum cpu usage per Container is 200m, but request is 100m
    ```

- `Example 4`: **Create a Pod that doesn't specify any CPU request or limit.** The below manifest specifies a container that doesn't specify any cpu request or limit values.

- When we deploy the Pod and see the yaml output, It shows that the Pod's single container has a CPU request of 800m and a CPU limit of 800m.

    ```commandline
    controlplane:~$ kubectl apply -f cpu-demo-pod-4.yaml -n cpu-constraints 
    pod/cpu-demo-pod-4 created
    
    controlplane:~$ kubectl get pods -n cpu-constraints 
    NAME             READY   STATUS    RESTARTS   AGE
    cpu-demo-pod-4   1/1     Running   0          86s
    
    controlplane:~$ kubectl get pods -n cpu-constraints -o yaml | yq '.items[0].spec.containers[0].resources'
    limits:
      cpu: 800m
    requests:
      cpu: 800m
    ```

- These default values are get assigned to the container because the container doesn't specify its own CPU request and limit, the control plane applied the default request and limit from the LimitRange for this namespace.

---

## Configure Minimum and Maximum Memory Constraints for a Namespace
Define a range of valid memory resource limits for a namespace, So that every Pod in that namespace falls within range you configure.

### Create a namespace
- Crate a namespace so that the resources you create in this exercise are isolated from the rest of the cluster.

    ```commandline
    controlplane:~$ kubectl create namespace memory-constraints
    namespace/memory-constraints created
    
    controlplane:~$ kubectl get namespaces/memory-constraints
    NAME                 STATUS   AGE
    memory-constraints   Active   14s
    controlplane:~$ 
    ```

### Crete a LimitRange Object and a Pod
- The below is the example of LimitRange Object
    
    ```yaml
    apiVersion: v1
    kind: LimitRange
    metadata:
      name: memory-constraints
    spec:
      limits:
        - type: Container
          min:
            memory: "500Mi"
          max:
            memory: "1Gi"
    ```
- Deploy the LimitRange object and view the details
    ```commandline
    controlplane:~$ kubectl apply -f memory-constraints.yaml -n memory-constraints 
    limitrange/memory-constraints created
    controlplane:~$ kubectl get limitrange/memory-constraints -n memory-constraints 
    NAME                 CREATED AT
    memory-constraints   2025-11-09T00:33:13Z
    
    controlplane:~$ kubectl get limitrange/memory-constraints -n memory-constraints  -o yaml | yq '.spec'
    limits:
      - default:
          memory: 1Gi
        defaultRequest:
          memory: 1Gi
        max:
          memory: 1Gi
        min:
          memory: 500Mi
        type: Container
    ```

- Now, whenever you deploy a Pod in the `memory-constraints` namespace, kubernetes performs the below steps
  - If any container in that Pod does not specify its own memory request and limit, the control plane assigns the default memory request and limit to that container
  - Verify that every container in that Pod request at least 500MiB of memory
  - Verify that every container in that Pod requests not more than 1GiB of memory.
- `Example 1`: **Create a container which memory requests and limits are in the range.** The below manifest specifies a Pod defines a container requests 600MiB of memory and limits 800MiB of memory.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: memory-demo-pod
    spec:
      containers:
        - name: nginx
          image: nginx
          resources:
            requests:
              memory: "600Mi"
            limits:
              memory: "800Mi"
    ```
- Deploy the pod and verify whether it's running or not

    ```commandline
    controlplane:~$ kubectl apply -f demo-memory-pod.yaml -n memory-constraints 
    pod/memory-demo-pod created
    controlplane:~$ 
    controlplane:~$ kubectl get pod/memory-demo-pod -n memory-constraints 
    NAME              READY   STATUS              RESTARTS   AGE
    memory-demo-pod   0/1     ContainerCreating   0          4s
    controlplane:~$ kubectl get pod/memory-demo-pod -n memory-constraints 
    NAME              READY   STATUS              RESTARTS   AGE
    memory-demo-pod   0/1     ContainerCreating   0          8s
    controlplane:~$ kubectl get pod/memory-demo-pod -n memory-constraints 
    NAME              READY   STATUS    RESTARTS   AGE
    memory-demo-pod   1/1     Running   0          21s
    ```
- The below output shows the container within that Pod has a memory request of 600Mi and memory limit of 800 Mi. These satisfy the constraints imposed by the LimitRange for this namespace.
    
    ```commandline
    controlplane:~$ kubectl get pod/memory-demo-pod -n memory-constraints  -o yaml | yq '.spec.containers[0].resources'
    limits:
      memory: 800Mi
    requests:
      memory: 600Mi
    ```
  
- `Example 2`: **Attempt to create a Pod that exceeds the maximum memory constraint.** The below container manifest specifies a memory request of 800Mi and a memory limit of 1.5 Gi.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: memory-demo-pod-2
    spec:
      containers:
        - name: nginx
          image: nginx
          resources:
            requests:
              memory: "800Mi"
            limits:
              memory: "1.5Gi"
    ```

- When we deploy the Pod, we will see the operation is Forbidden. The below output shows the Pod doesn't get created, because it defines a container that requests more memory than is allowed.

```commandline
controlplane:~$ kubectl apply -f  memory-constraints-2.yaml -n memory-constraints 
Error from server (Forbidden): error when creating "memory-constraints-2.yaml": pods "memory-demo-pod-2" is forbidden: maximum memory usage per Container is 1Gi, but limit is 1536Mi
```

- `Example 3`: **Attempt to create a Pod that does not meet the minimum memory request**. The below container specifies a memory request of 100Mi and a memory limit of 800Mi
    
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: memory-demo-pod-3
    spec:
      containers:
        - name: nginx
          image: nginx
          resources:
            requests:
              memory: "100Mi"
            limits:
              memory: "800Mi"
    ```
- When we try to deploy the pod, we will see the operation is Forbidden. Here the container requests less memory than the enforced minimum.

    ```commandline
    controlplane:~$ kubectl apply -f memory-constraints-3.yaml -n memory-constraints 
    Error from server (Forbidden): error when creating "memory-constraints-3.yaml": pods "memory-demo-pod-3" is forbidden: minimum memory usage per Container is 500Mi, but request is 100Mi
    ```

- `Example 4:` **Create a Pod that does not specify any memory request or limit**. The below container doesn't specify any memory request or limit.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: memory-demo-pod-4
    spec:
      containers:
        - name: nginx
          image: nginx
    ```

- When we deploy the Pod, It's successfully deployed. Even though we didn't assign any resource specifications for memory. The cluster applied the default values to the Pod created.

    ```commandline
    controlplane:~$ kubectl apply -f memory-constraints-4.yaml -n memory-constraints 
    pod/memory-demo-pod-4 created
    controlplane:~$ kubectl get pod/memory-demo-pod-4 -n memory-constraints 
    NAME                READY   STATUS    RESTARTS   AGE
    memory-demo-pod-4   1/1     Running   0          12s
    
    controlplane:~$ kubectl get pod/memory-demo-pod-4 -n memory-constraints -o yaml | yq '.spec.containers[0].resources'
    limits:
      memory: 1Gi
    requests:
      memory: 1Gi
    ```

---

## Configure Default CPU requests and limits for a Namespace
Define a default CPU resource limits for a namespace, So that every new Pod in that namespace has a CPU resource limit configured.

### Create a namespace
- Create a namespace so that the resources you create in this exercise are isolated from the rest of your cluster.

    ```commandline
    controlplane:~$ kubectl create namespace default-cpu   
    namespace/default-cpu created
    controlplane:~$ kubectl get namespace/default-cpu 
    NAME          STATUS   AGE
    default-cpu   Active   12s
    ```
  
### Create a LimitRange Object and a Pod
- The below manifest specifies default CPU limit and default CPU request.

    ```yaml
    apiVersion: v1
    kind: LimitRange
    metadata:
      name: default-cpu-constraints
    spec:
      limits:
        - type: Container
          default:
            cpu: 1
          defaultRequest:
            cpu: 0.5
    ```
- Deploy the LimitRange Object in the namespace created.

    ```commandline
    controlplane:~$ kubectl apply -f default-cpu-constraints.yaml -n default-cpu 
    limitrange/default-cpu-constraints created
    controlplane:~$ 
    controlplane:~$ kubectl get limitrange/default-cpu-constraints -n default-cpu 
    NAME                      CREATED AT
    default-cpu-constraints   2025-11-10T00:14:07Z
    ```

- Now if we create a Pod in the namespace we created, and any container in that Pod does not specify its own values for CPU requests and limits, then the control plane applies the default values.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-cpu-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
    ```

- If we deploy the pod and see the yaml output the Pod's only container has a CPU request of 500m and a CPU limit of 1.

    ```commandline
    controlplane:~$ kubectl apply -f default-cpu-pod.yaml -n default-cpu 
    pod/default-cpu-pod created
    controlplane:~$ kubectl get pod/default-cpu-pod -n default-cpu 
    NAME              READY   STATUS    RESTARTS   AGE
    default-cpu-pod   1/1     Running   0          16s
    
    controlplane:~$ kubectl get pod/default-cpu-pod -n default-cpu -o yaml | yq  '.spec.containers[0].resources'
    limits:
      cpu: "1"
    requests:
      cpu: 500m
    ```

### `Example 1:` **Specify a container's limit, but not it's requests**

- The below is the example pod specification manifest

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-cpu-pod-2
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            limits:
              cpu: "1"
    ```
- If we deploy the above pod, What will be the container's requests value for CPU?

    ```commandline
    $ kubectl apply -f default-cpu-pod-2.yaml -n default-cpu
    pod/default-cpu-pod-2 created
    
    $ kubectl get pod/default-cpu-pod-2 -n default-cpu
    NAME                READY   STATUS    RESTARTS   AGE
    default-cpu-pod-2   1/1     Running   0          81s
    ```

- The below output shows that the container's CPU request is set to match the CPU limit. Notice that the container was not assigned the default CPU request value of "0.5".

    ```commandline
    $ kubectl get pod/default-cpu-pod-2 -n default-cpu -o yaml | yq '.spec.containers[0].resources'
    
    limits:
      cpu: "1"
    requests:
      cpu: "1"
    ```

### `Example 2`: **Specify a container's request, but not its limit**

- The below is the example pod specification manifest

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-cpu-pod-3
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "0.75"
    ```

- When we deploy the Pod, what will be the container's limit value?

    ```commandline
    $ kubectl apply -f default-cpu-pod-3.yaml -n default-cpu
    pod/default-cpu-pod-3 created
    $ kubectl get pod/default-cpu-pod-3 -n default-cpu 
    NAME                READY   STATUS    RESTARTS   AGE
    default-cpu-pod-3   1/1     Running   0          35s
    ```

- The below output shows that the container's CPU request is set to the value you specified at the time you created the Pod. However, the same container's CPU limit is set to `1`, which is the default CPU limit value for that namespace.
    
    ```commandline
    $ kubectl get pod/default-cpu-pod-3 -n default-cpu -o yaml | yq '.spec.containers[0].resources'
    limits:
      cpu: "1"
    requests:
      cpu: 750m
    ```

---

## Configure Default memory request and limits for a namespace
- Define a default memory resource limit for a namespace, so that every new Pod in that namespace has a memory resource limit configured.

- **Create a namespace**

    ```commandline
    $ kubectl create namespace default-memory
    namespace/default-memory created
    
    $ kubectl get namespace/default-memory
    NAME             STATUS   AGE
    default-memory   Active   9s
    ```

- **Create a LimitRange and a Pod**

    ```yaml
    apiVersion: v1
    kind: LimitRange
    metadata:
      name: default-memory-constraints
    spec:
      limits:
        - type: Container
          default:
            memory: 512Mi
          defaultRequest:
            memory: 256Mi
    ```
- Deploy the LimitRange Object in the `default-memory` namespace

    ```commandline
    $ kubectl apply -f memory-constraints.yaml -n default-memory
    limitrange/default-memory-constraints created
    
    $ kubectl get limitranges -n default-memory
    NAME                         CREATED AT
    default-memory-constraints   2025-11-11T02:25:18Z
    ```

- The below Pod spec will doesn't specify any resources values.
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-memory-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
    ```

- If we deploy the Pod and view the Pod specification, the resources are assigned with default values of the LimitRange object deployed in the namespace.

    ```commandline
    
    $ kubectl apply -f default-memory-pod.yaml -n default-memory 
    pod/default-memory-pod created
    
    $ kubectl get pod/default-memory-pod -n default-memory
    NAME                 READY   STATUS    RESTARTS   AGE
    default-memory-pod   1/1     Running   0          15s
    
    $ kubectl get pod/default-memory-pod -n default-memory -o yaml | yq '.spec.containers[0].resources'
    limits:
      memory: 512Mi
    requests:
      memory: 256Mi
    ```

### `Example 1:` **Specify a container memory limit but not request**
- The below is the example pod specification manifest

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-memory-pod-2
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            limits:
              memory: 1Gi
    ```

- Deploy the Pod and view the resources assigned to the Pod specification

    ```commandline
    
    $ kubectl apply -f default-memory-pod-2.yaml -n default-memory 
    pod/default-memory-pod-2 created
    
    $ kubectl get pod/default-memory-pod-2 -n default-memory 
    NAME                   READY   STATUS    RESTARTS   AGE
    default-memory-pod-2   1/1     Running   0          9s
    
    $ kubectl get pod/default-memory-pod-2 -n default-memory -o yaml | yq '.spec.containers[0].resources'
    limits:
      memory: 1Gi
    requests:
      memory: 1Gi
    ```

- The above output shows that the containers limits and requests  matched to the value of limits specified in the Pod specification but not the default value assigned to the LimitRange object deployed in the namespace.

### `Example 2:` **Specify container's requests but not its limits**

- The below is the example pod specification manifest
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: default-memory-pod-3
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              memory: 128Mi
    ```

- Deploy the Pod and view the resources assigned to it.

    ```commandline
    $ kubectl apply -f default-memory-pod-3.yaml -n default-memory 
    pod/default-memory-pod-3 created
    
    $ kubectl get pod/default-memory-pod-3 -n default-memory
    NAME                   READY   STATUS    RESTARTS   AGE
    default-memory-pod-3   1/1     Running   0          19s
    
    $ kubectl get pod/default-memory-pod-3 -n default-memory -o yaml | yq '.spec.containers[0].resources'
    limits:
      memory: 512Mi
    requests:
      memory: 128Mi
    ```

- The above output shows that the container is assigned with the memory requests value specified in its Pod specification but the limit value is assigned with the default value specified in the LimitRange object deployed in the namespace. 

---

## Limit Storage Consumption

### Scenario: Limiting Storage Consumption
The cluster admin is operating a cluster on behalf og a user population and the admin wants to control how much storage a single namespace can consume in order ro control cost.
The admin would like to limit
- The number of persistent volume claims in a namespace
- The amount of storage each claim can request
- The amount of cumulative storage the namespace can have

### LimitRange to limit requests for storage
- Adding a `LimitRange` to a namespace enforces storage requests sizes to a minimum and maximum.
- Storage is requested via `PersistentVolumeClaim`. The admission controller that enforces limit ranges will reject any PVC that is above or below the values set by the admin.
- In this example, a PVC requesting 10Gi of storage would be rejected because it exceeds the 2Gi max

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
spec:
  limits:
    - type: PersistentVolumeClaim
      min:
        storage: 1Gi
      max:
        storage: 2Gi
```
- Minimum storage requests are used when the underlying storage provider requires certain minimums. For example, AWS EBS volumes have a 1Gi minimum requirement.

### ResourceQuote to limit PVC Count and cumulative storage capacity
- Admins can limit the number of PVC's in a namespace as well as the cumulative capacity of those PVC's. New PVCs that exceeded either maximum value will be rejected.
- In this example, a 6th PVC in the namespace would be rejected because it exceeds the maximum count of 5.
- Alternatively a 5Gi maximum quota when combines with the 2Gi max limit above, cannot have 3 PVCs where each has 2Gi. That would be 6Gi requested for a namespace capped at 5Gi.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
spec:
  hard:
    persistentvolumeclaims: "5"
    requests.storage: "5Gi"
```

### Summary
- A LimitRange can put a ceiling on how much storage is requested while a ResourceQuota can effectively cap the storage consumed by a namespace through claim counts and cumulative storage capacity.