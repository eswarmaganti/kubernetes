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
