# Resource Quotas
- When several users or teams share a cluster with a fixed number of nodes, there is a concern that one team could use more than its fair share of resources.
- *Resource quotas* are a tool for administrators to address this concern
- A resource quota, defines by a ResourceQuota Object, provides constraints that limit aggregate resource consumption per namespace.
- A ResourceQuota can also limit the quantity of objects that can be created in a namespace by API kind, as well as the total amount of infrastructure resources that may be consumed by API objects found in that namespace.
- Note: Neither contention nor changes to the quota will affect already crated resources.

## How Kubernetes ResourceQuotas work
ResourceQuotas works like this:
- Different teams work in different namespaces. This separation can be enforced with RBAC or any other authorization mechanism.
- A Cluster administrator creates at least one ResourceQuota for each namespace.
  - To make sure the enforcement stays enforced, the cluster administrator should also restrict access to delete or update that ResourceQuota. For example by defining a `ValidatingAdmissionPolicy`.
- Users create resources (pods, services etc.) in the namespace, and the quota system tracks usage to ensure it does not exceed hard resource limits defines in a ResourceQuota.
  - You can apply scope to a ResourceQuota to limit where it applies,
- If creating or updating resource violates a quota constraint, the control plane rejects that request with HTTP status code `403 Forbidden`. The error includes a message explaining the constraint that would have been violated.
- If quotas are enabled in namespaces for resources such as `cpu` and `memory`, users myst specify requests or limits for those values when they define Pod; otherwise, the quota system may reject pod creation.
- You often do not create Pods directly; for example, you more usually create a workload management object such as a Deployment. If you create a Deployment that tries to use more resources than are available, the creation of Deployment succeeds, but the Deployment may not be able to get all the Pods it manages to exist. 

The name of a ResourceQuota object must be a valid DNS subdomain name
Example of policies that could be crated using namespaces and quotas are:
- In a cluster with a capacity of 32GiB RAM, 16 cores, let Team A use 20GiB and 10cores, let Team B use 10GiB and 4 cores, and hold 2GiB and 2 cores in reserve for future allocation.
- Limit the testing namespace to using 1 core and 1GiB RAM. let the production namespace use any amount.

## Enabling Resource Quota
- ResourceQuota support is enabled by default for many Kubernetes distributions. It is enabled when the API server `--enable-admission-plugins=` flag gas `ResourceQuota` as one of its arguments.
- A resource quota is enforced in a particular namespace when there is a ResourceQuota in that namespace.

## Types of resource quota
- The ResourceQuota mechanism lets you enforce different kinds of limits. This section describes the types of limit that you can enforce.

### Quota for infrastructure resources
You can limit the total sum of compute resources that can be requested in a given namespace.
The following resource types are supported

-  `limits.cpu`: Across all pods in a non-terminal state, the sum of CPU limits cannot exceed this value.
- `limits.memory`: Across all pods in a non-terminal state, the sum of memory limits cannot exceed this value.
- `requests.cpu`: Across all pods in a non-terminal state, the sum of CPU requests cannot exceed this value.
- `requests.memory`: Across all pods in a non-terminal state, the sum of memory requests cannot exceed this value.
- `hugepages-<size>`: Across all pods in a non-terminal state, the number of huge page requests of the specified size cannot exceed this value.
- `cpu`: Same as `requests.cpu`
- `memory`: same as `requests.memory`

### Quota for extended resources
- As overcommit is not allowed for extended resources, it makes no sense to specify both `requests` and `limits` for the same extended resource in a quota. So for extended resources, only quota items with prefix `requests.` are allowed.
- Take the GPU resources as an example, if the resource name is `nvidia.com/gpu`, and you want to limit the total number of GPUs requested in a namespace to 4, you can define a quota as follows
  - `requests.nvidia.com/gpu: 4`

### Quota for storage
- You can limit the total sum of storage for volumes that can be requested in a given namespace.
- In addition, you can limit consumption of storage resources based on associated StorageClass.

- `requests.storage`: Across all persistent volume claims, the sum of storage requests cannot exceed this value.
- `persistentvolumeclaims`: The total number of `PersistentVolumeClaims` that can exist in the namespace
- `<storage-class-name>.storageclass.storage.k8s.io/requests.storage`: Across all persistent volume claims associated with the `<storage-class-name>`, the sum of storage requests cannot exceed this value.
- `<storage-class-name>.storageclass.storage.k8s.io/peristentvolumeclaims`: Across all persistent volume claims associated with the `<storage-class-name>`, the total number of persistent volume claims that can exist in the namespace.

For example, if you want to quota storge with `gold` StorageClass separate from `bronze` StorageClass, you can define a quota as follows:
- `gold.storageclass.storage.k8s.io/requests.storage: 500Gi`
- `bronze.storageclass.storage.k8s.io/requests.storage: 100Gi`

### Quota for local ephemeral storage
- When using a CRI container runtime, container logs will count against the ephemeral storage quota. This can result in the unexpected eviction of pods that have exhausted their storage quota.

- `requests.ephemeral-storage`: Across all pods in the namespace, the sum of local ephemeral storage requests cannot exceed this value.
- `limit.ephemeral-storage`: Across all pods in the namespace, the sum of local ephemeral storage limits cannot exceed this value.
- `ephemeral-storage`: Same as `requests.ephemeral-storage`

### Quota on object count
- You can set quota for the total number of one particular resource kind in the kubernetes API, using the following syntax:
  - `count/<resource>.<group>` for resources from non-core API groups
  - `count/<resource>` for resources from the core API group
- For example, the PodTemplate API is in the core API group and so if you want to limit the number of PodTemplate objects in a namespace, you use `count/podtemplates`.
- These types of quotas are useful to protect against of control plane storage. For example, you may want to limit the number of Secrets in a server given their large size. Too many Secrets in a cluster can actually prevent servers and controllers from starting. You can set a quota for jobs to protect against a poorly configured CronJob. CronJob that create too many jobs in a namespace can lead to a denial of service. 
- ResourceQuota works only for objects stored and managed inside kubernetes, the control plane can see, count and enforce limits on them
  - kubernetes built-in resources (Pods, PVCs, Deployments etc.)
  - CustomResourceDefinitions (CRDs) that run fully inside the kube-apiserver.
- ResourceQuota doesn't work for custom APIs added using the Aggregation Layer, These APIs are served by external API server, not by kube-apiserver. Because the core control plane cannot see or track those resources, it cannot enforce quota on them.

#### Generic Syntax
- This is a list of common examples of object kinds that you may want to put under object count quota, listed by the configuration string that you would use.
  - `count/pods`
  - `count/persistentvolumeclaims`
  - `count/services`
  - `count/secrets`
  - `count/configmaps`
  - `count/deployments.apps`
  - `count/replicasets.apps`
  - `count/statefulsets.apps`
  - `count/jobs.batch`
  - `count/cronjobs.batch`

#### Specialized Syntax
- There is another syntax only to set the same type of quota, that only works for certain API kinds. The following types are supported:

    - `configmaps`: The total number of ConfigMaps that can exist in the namespace
    - `persistentvolumeclaims`: The total number of PersistentVolumeClaims that can exist in the namespace
    - `pods`: The total number of Pods in a non-terminal state that can exist in the namespace. A pod is in terminal state of `.status.phase` in `Failed` or `Succeeded` is true.
    - `replicationcontrolers`: The total number of Replication Controllers that can exist in the namespace 
    - `resourcequotas`: The total number of ResourceQuotas that can exist in the namespace
    - `services`: The total number of Services that can exist in the namespace
    - `services.loadbalancers`: The total number of Services of type LoadBalancer that can exist in the namespace.
    - `services.nodeports`: The total number of NodePorts allocated to Services of type NodePort or LoadBalancer that can exist in the namespace
    - `secrets`: Total number of secrets that can exist in the namespace
- For example, `pods` quota counts and enforces a maximum on the number of `pods` created in a single namespace that are not terminal. You might want to set a `pods` quota on a namespace to avoid the case where a user creates many small pods and exhausts the cluster's supply of Pod IP's.

### Viewing and Setting Quotas:
- kubectl supports creating, updating and viewing of quotas

- Create a namespace
  - `kubectl create namespace dev`
- Deploy the below ResourceQuota object for compute resources in the `dev` namespace

    ```yaml
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: compute-quota
    spec:
      hard:
        requests.cpu: "1"
        requests.memory: "1Gi"
        limits.cpu: "2"
        limits.memory: "2Gi"
        requests.nvidia.com/gpu: 4
    ```
    ```commandline
    $ kubectl apply -f compute-quota.yaml -n dev
    resourcequota/compute-quota created
    $ kubectl get resourcequotas -n dev
    NAME            AGE   REQUEST                                                                   LIMIT
    compute-quota   12s   requests.cpu: 0/1, requests.memory: 0/1Gi, requests.nvidia.com/gpu: 0/4   limits.cpu: 0/2, limits.memory: 0/2Gi
  
    $ kubectl describe quota compute-quota -n dev
    Name:                    compute-quota
    Namespace:               dev
    Resource                 Used  Hard
    --------                 ----  ----
    limits.cpu               0     2
    limits.memory            0     2Gi
    requests.cpu             0     1
    requests.memory          0     1Gi
    requests.nvidia.com/gpu  0     4
    ```
- Deploy the below ResourceQuota object for object counts in the `dev` namespace
    
    ```yaml
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: object-counts-quota
    spec:
      hard:
        configmaps: "10"
        pods: 4
        persistentvolumeclaims: "4"
        replicationcontrollers: "20"
        secrets: "10"
        services: "10"
        services.loadbalancers: "2"
    ```

    ```commandline
    kubectl apply -f object-counts-quota.yaml -n dev
    resourcequota/object-counts-quota created
    
    kubectl get resourcequota/object-counts-quota -n dev
    NAME                  AGE   REQUEST                                                                                                                                              LIMIT
    object-counts-quota   13s   configmaps: 1/10, persistentvolumeclaims: 0/4, pods: 0/4, replicationcontrollers: 0/20, secrets: 0/10, services: 0/10, services.loadbalancers: 0/2 
    
    kubectl describe quota object-counts-quota -n dev
    Name:                   object-counts-quota
    Namespace:              dev
    Resource                Used  Hard
    --------                ----  ----
    configmaps              1     10
    persistentvolumeclaims  0     4
    pods                    0     4
    replicationcontrollers  0     20
    secrets                 0     10
    services                0     10
    services.loadbalancers  0     2
    ```
- kubectl also supports object count quota for all standard namespaces resources using the syntax `count/<resource>.<group>`
    ```commandline
    $ kubectl create quota test --hard=count/deployment.apps=2,count/pods=3,count/statefulsets.apps=2,count/secrets=10,count/configmaps=10,count/persistentvolumeclaims=2 -n dev
    resourcequota/test created
    
    $ kubectl get quota/test -n dev
    NAME   AGE   REQUEST                                                                                                                                                     LIMIT
    test   14s   count/configmaps: 1/10, count/deployment.apps: 0/2, count/persistentvolumeclaims: 0/2, count/pods: 0/3, count/secrets: 0/10, count/statefulsets.apps: 0/2   
    
    $ kubectl describe quota/test -n dev
    Name:                         test
    Namespace:                    dev
    Resource                      Used  Hard
    --------                      ----  ----
    count/configmaps              1     10
    count/deployment.apps         0     2
    count/persistentvolumeclaims  0     2
    count/pods                    0     3
    count/secrets                 0     10
    count/statefulsets.apps       0     2
    ```

### Quota and Cluster Capacity
- ResourceQuotas are independent of the cluster capacity. They are expressed in absolute units. So, if you add nodes to your cluster, this deos not automatically give each namespace the ability to consume more resources.
- Sometimes more complex policies may be desired, such as:
  - Proportionally divide total cluster resources among several teams
  - Allow rach tenant to grow resources usage as needed, but have a generous limit to prevent accidental resource exhaustion
  - Detect demand from one namespace, add nodes, and increase quota.
- Such policies could be implemented using `ResourceQuotas` as building blocks, by writing a "controller" that watches the quota usage and adjusts the quota hard limits of each namespace accordingly to other signals.
- Note that the resource quota divides up aggregate cluster resources, but it creates no restrictions around nodes: pods from several namespaces may run onm the same node.

### Quota Scopes
- Each quota can have an associated set og `scopes`. A quota will only measure usage fot a resource if it matches the intersection of enumerated scopes.
- When a scope is added to the quota, it limits the number of resources it supports to those that pertain to the scope. Resources specified on the quota outside the allowed set results in a validation error.

- Kubernetes 1.34 supports the following scopes:
    - `BestEffort`: Match pods that have the best effort quality of service.
    - `CrossNamespacePodAffinity`: Match pods that have cross namespace pod (anti)affinity terms.
    - `NotBestEffort`: Match pods that do not have the best effort quality of service.
    - `NotTerminating`: Match pods where .spec.activeDeadlineSeconds is nil
    - `PriorityClass`: Match pods that references the specified priority class.
    - `Terminating`: Match pods where .spec.activeDeadlineSeconds >= 0
    - `VolumeAttributesClass`: Match PersistentVolumeClaims that references the specified volume attribute class.

- ResourceQuotas with a scope set can also have a optional `scopeSelector` filed. You can define one or more *match expressions* that specify an `operator` and, if relevant, a set of values to match.
    ```yaml
    scopeSelector:
      matchExpressions:
        - scopeName: BestEffort # match pods that have the best quality of service
          operator: Exists # optional; Exists if implied for BestEffort scope
    ```

- The `scopeSelector` supports the following values in the `operator` filed
  - `In`
  - `NotIn`
  - `Exists`
  - `DoesNotExist`
- If the operator is `In` or `NotIn`, the `values` filed must have at least one value. For example

    ```yaml
    scopeSelector:
      matchExpressions:
        - scopeName: PriorityClass
          operator: In
          values:
            - middle
    ```
- If the `operator` is `Exists` or `DoesNotExists`, the values field must Not be specified.

#### Best effort Pods scope
- This scope only tracks quota consumed by pods. It only matches pods that have the best effort Qos class.
- The `operator` for a `scopeSelector` must be `Exists`.

#### Not-best-effort Pods scope
- This scope only tracks quota consumed by Pods. It only matches pods that have Guaranteed or Burstable QoS class.
- The `operator` for a `scopeSelector` must be `Exists`

#### Non-terminating Pods scope
- This scope only tracks quota consumed by Pods that are not terminating. The `operator` for a `scopeSelector` must be `Exists`.
- A Pod is not terminating if the `.spec.activeDeadlineSeconds` filed is unset.
- You can use a ResourceQuota with this scope to manage the following resources:
  - `counts.pods`
  - `pods`
  - `cpu`
  - `memory`
  - `requests.cpu`
  - `requests.memory`
  - `limits.cpu`
  - `limits.memory`

#### Terminating Pods scope
- This scope only tracks quota consumed by Pods that are terminating. The `operator` for a `scopeSelector` must be `Exists`.
- A Pod is considered as *terminating* if the `.spec.activeDeadlineSeconds` filed is set to any number
- You can use a ResourceQuota with this scope to manage the following
    - `counts.pods`
    - `pods`
    - `cpu`
    - `memory`
    - `requests.cpu`
    - `requests.memory`
    - `limits.cpu`
    - `limits.memory`

#### Cross-namespace pod affinity scope
- You can use `CrossNamespacePodAffinity` quota scope to limit which namespaces are allowed to have pods with affinity terms that cross namespaces.
- Specially, it controls which pods are allowed to set `namespaces` or `namespaceSelector` fields in pod (anti)affinity terms.
- Preventing users from using cross-namespace affinity terms might be desired since a pid with anti-affinity constraints can block pods from all other namespaces from getting scheduled in a failure domain.
- Using this scope, you can prevent certain namespaces - such as `foo-ns` in the example below - from having pods that use cross-namesapce pod affinity.
- You configure this creating a ResourceQuota object in that namespace qith `CrossNamespacePodAffinity` scope and hard limit of 0.

    ```yaml
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: diable-cross-namespace-affinity
      namespace: foo-ns
    spec:
      hard:
        pods: "0"
      scopeSelector:
        matchExpressions:
          - operator: Exists
            scopeName: CrossNamespacePodAffinity
    ```

- If you want to disallow using `namespaces` and `namespaceSelector` by default, and only allow it for specific namespaces, you could configure `CrossNamespacePodAffinity` as a limited resource by setting the kube-apiserver fag `--admission-control-config-file` to the path of the following configration file:

    ```yaml
    apiVersion: apiserver.config.k8s.io/v1
    kind: AdmissionConfiguration
    plugins:
      - name: "ResourceQuota"
        configuration:
          apiVersion: apiserver.config.k8s.io/v1
          kind: ResourceQuotaConfiguration
          limitedResources:
            - resource: pods
              matchScopes:
                - scopeName: CrossNamespacePodAffinity
                  operator: Exists
    ```
- With the above configuration, pods can use `namespaces` and `namespaceSelector` in the pod affinity only if the namespace where they are created have a resource quota object with `CrossNamespacePodAffinity` scope and a hard limit grater than or equal to number of pods using those fields.

#### PriorityClass scope
- A ResourceQuota with a PriorityClass scope only matches Pods that have a particular priority class, and only ig any `scopeSelector` in the quota spec selects a particular Pod.
- Pods can be created at a specific priority. You can control a Pod's consumption of system resources based on pod's priority, by using the `scopeSelector` filed in the quota spec.
- When a quota is scoped for PriorityClass using the `scopeSelector` filed, the ResourceQuota can only track (and limit) the following resources:
  - `pods`
  - `cpu`
  - `memory`
  - `ephemeral-storage`
  - `limits.cpu`
  - `limits.memory`
  - `limits.ephemeral-storage`
  - `requests.cpu`
  - `requests.memory`
  - `requests.ephemeral-storage`
- Example:
  - This example creates a ResourceQuota matches it with pods at specific priorities. The example works as follows:
  - Pods in the cluster have one of the three PriorityClasses, "low", "medium" and "high"
    - If you want to try out, use a testing cluster and setup those three PriorityClasses before you continue.
  - One quota object is created for each priority class.

    ```yaml
    ---
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: pods-high
    spec:
      hard:
        cpu: "1000"
        memory: "200Gi"
        pods: "10"
      scopeSelector:
        matchExpressions:
          - operator: In
            scopeName: PriorityClass
            values:
              - "high"
    ---
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: pods-medium
    spec:
      hard:
        cpu: "10"
        memory: "20Gi"
        pods: "10"
      scopeSelector:
        matchExpressions:
          - operator: In
            scopeName: PriorityClass
            values:
              - "medium"
    ---
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: pods-low
    spec:
      hard:
        cpu: "5"
        memory: "10Gi"
        pods: "10"
      scopeSelector:
        matchExpressions:
          - operator: In
            scopeName: PriorityClass
            values:
              - "low"
    ```
- Apply the above manifest using `kubectl`

    ```commandline
    kubectl apply -f resource-quota.yaml -n test
    resourcequota/pods-high created
    resourcequota/pods-medium created
    resourcequota/pods-low created
    
    kubectl get quota -n test
    NAME          AGE   REQUEST                                  LIMIT
    pods-high     13s   cpu: 0/1k, memory: 0/200Gi, pods: 0/10   
    pods-low      13s   cpu: 0/5, memory: 0/10Gi, pods: 0/10     
    pods-medium   13s   cpu: 0/10, memory: 0/20Gi, pods: 0/10 
    ```

- Create a Pod with high priority class
    
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: high-pod-test
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "1"
              memory: "2Gi"
      priorityClassName: high
    ```
- Deploy the Pod and view the used stats for resource quota object

    ```commandline
    $ kubectl apply -f high-priority-pod.yaml -n test
    pod/high-priority-pod created
    
    kubectl describe quota -n test
    Name:       pods-high
    Namespace:  test
    Resource    Used  Hard
    --------    ----  ----
    cpu         500m  1k
    memory      1Gi   200Gi
    pods        1     10
    
    
    Name:       pods-low
    Namespace:  test
    Resource    Used  Hard
    --------    ----  ----
    cpu         0     5
    memory      0     10Gi
    pods        0     10
    
    
    Name:       pods-medium
    Namespace:  test
    Resource    Used  Hard
    --------    ----  ----
    cpu         0     10
    memory      0     20Gi
    pods        0     10
    ```
 
##### Limiting PriorityClass consumption by default
- It may be desired that pods at a particular priority, such as "cluster-services", should be allowed in a namespace, if and only if, a matching quota object exists.
- With this mechanism, operators are able to restrict usage of certain high priority classes to be limited number of namespaces and not every namespace will be able to consume these priority classes by default.
- To enforce this `kube-apiserver` flag `--admission-control-config-file` should be used to pass the path to the following configuration file:

    ```yaml
    apiVersion: apiserver.config.k8s.io/v1
    kind: AdmissionConfiguration
    plugins:
      - name: "ResourceQuota"
        configuration:
          apiVersion: apiserver/config.k8s.io/v1
          kind: ResoureQuotaConfiguration
          limitedResources:
            - resource: pods
              matchScopes:
                - scopeName: PriorityClass
                  operator: In
                  value: ["cluster-services"]
    ```
- Create a resource quota object in the `kube-system` namespace

    ```yaml
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: pods-cluster-services
    spec:
      scopeSelector:
        matchExpressions:
          - operator: In
            scopeName: PriorityClass
            values:
              - "cluster-services"
    ```

- In this case, a Pod creation will be allowed if:
  - The Pod's `priorityClassName` is not specified
  - The Pod's `priorityClassName` is specified to a value other than `cluster-services`
  - The Pod's `priorityClassName` is set to `cluster-services`, it is to be created in the `kube-system` namespace, and it has passes the resource quota check.
- A Pod creation request is rejected if its `priorityClassName` is set to `cluster-services` and it is to be created in the namespace other than `kube-system`.


#### VolumeAttributeClass scope
- This scope only tracks quota consumed by PersistentVolumeClaims.
- PersistentVolumeClaims can be created with a specific VolumeAttributeClass, and might be modified after creation. YOu can control a PVC's consumption of storage resources based on the associated VolumeAttributeClasses, by using the `scopeSelector` filed in the quota spec.
- The PVC references the associated `VolumeAttributeClass` by the following filed
  - `.spec.volumeAttributeClassName`
  - `.status.currentVolumeAttributeClassName`
  - `.status.modifyVolumeStatus.targetVolumeAttributeClassName`
- A relevant ResourceQuota is matched and consumed only if the ResourceQuota has a `scopeSelector` that selects a PVC.
- When the quota is scoped for the volume attributes class using the `scopeSelector` filed, the quota object is restricyed to track only the following resources:
  - `persistentvolumeclaims`
  - `request.storage`