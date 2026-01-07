# Assigning Pods to Nodes

- You can constrain a Pod so that it is *restricted* to run on particular node(s), or to prefer to run on particular node.
- There are several ways to do this and the recommended approaches all use label selector to facilitate the section. Often you don't need to set any such constraints; the schedular will automatically do a reasonable placement.
- However, there are some circumstances where you may want to control which node the Pod deploys to, for example, to ensure that a Pod ends up on a node with an SSD attached to it, or to co-locate Pods from two different services that communicate a lot into the same availability zone.
- You can use any of the following methods to choose where kubernetes schedules specific Pods:
  - nodeSelector filed matching against node labels
  - Affinity and anti-affinity
  - nodeName filed
  - Pod topology spread constraints

## Node labels
- Like many kubernetes objects, nodes have labels. You can attach labels manually. Kubernetes also populates a standard set of labels on all nodes in a cluster.

### Node isolation/restriction
- Adding labels to nodes allows you to target Pods for scheduling on specific nodes or groups of nodes. You can use this functionality to ensure the specific pods only run on nodes with certain isolation, security, or regulatory properties.
- If you use labels for node isolation, choose label keys that the kubelet cannot modify. This prevents a compromised node from setting those labels on itself so that the scheduler schedules workloads onto the compromised node.
- The `NodeRestriction` admission plugin prevents the kubelet from setting or modify labels with a `node-restriction.kubernetes.io/` prefix
- To make use of that label prefix for node isolation:
  - Ensure you are using the Node authorizer and have enabled the `NodeRestriction` admission plugin.
  - Add labels with the `node-restriction.kubernetes.io/` prefix to your nodes, and use those labels in your node selectors.
    - For example: `example.com.node-restriction.kubernetes.io/fips=true` or `example.com.node-restriction.kubernetes.io/pci-dss=true`

### nodeSelector
- `nodeSelector` is the simplest recommended form of node selection constraint.
- You can add the `nodeSelector` filed to your Pod specification and specify the node labels you want the target node to have. Kubernetes only schedules the Pod onto nodes that each of the labels you specify.

## Affinity and anti-affinity
- `nodeSelector` is the simplest way to constrain Pods to nodes with specific labels. Affinity and anti-affinity expand the types of constraints you can define. Some of the benefits of affinity and anti-affinity include:
  - The affinity/anti-affinity languages is more expressive. `nodeSelector` only selects nodes with all the specified labels. Affinity/anti-affinity gives you more control over the selection logic.
  - You can indicate that a rule is soft or preferred, so that the scheduler still schedules the Pod even if it can't find a matching node.
  - You can constrain a Pod using labels on other Pods running on the node (or other topological domain), instead of just node labels, which allows you to define rules for which Pods can be co-located on a node.
- The affinity feature consists of two types of affinity:
  - *Node Affinity* functions like the `nodeSelector` field but is more expressive and allows you to specify soft rules.
  - *Inter-pod affinity/anti-affinity* allows you to constrain Pods against labels on other Pods.

### Node affinity
- Node affinity is conceptually similar to `nodeSelector`, allowing you to constrain which nodes your Pod can be scheduled on based on node labels.
- There are two types of node affinity:
  - `requoredDuringSchedulingIgnoredDuringExecution`: The scheduler can't schedule the Pod unless the rule is met. This functions like `nodeSelector`m but with more expressive syntax.
  - `preferredDuringSchedulingIgnoredDuringExecution`: The scheduler tries to find a node that meets the rule. If a matching node is not available, the Scheduler still schedules the Pod. 
- NOTE: In the preceding types, `IgnoredDuringExecution` means that if the node labels change after kubernetes schedules the Pod, the Pod continuous to run.

- You can specify the node affinities using the `.spec.affinity.nodeAffinity` filed in your Pod spec.
- For example:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: pod-with-affinity
    spec:
      containers:
        - name: nginx
          image: nginx
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                      - antarctica-east1
                      - antarctica-west1
          preferredDuringSchedulingIgnoredDuringExecution:
            - preference:
                matchExpressions:
                  - key: another-node-label-key
                    operator: In
                    values:
                      - another-node-label-value
              weight: 1   
    ```
- In the above example, the following rules apply
  - The node must have a label with key `topology.kubernetes.io/zone` and the value of the label must be either `antarctica-east1` or `antarctica-west1`
  - The node preferably has a label with the key `another-node-label-key` and the value `another-node-label-value`
- You can use the `operator` filed to specify a logical operator for Kubernetes to use when interpreting the rules. You can use `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt` and `Lt`.
- `NotIn` and `DoesNotExist` allow you to define node anti-affinity behaviour. Alternatively, you can use node taints to repl Pods from specific nodes.

Note:
- If you specify both `nodeSelector` and `nodeAffinity`, both must be satisfied for the Pod to be scheduled on a node.
- If you specify multiple terms in `nodeSelectorTerms` associated with `nodeAffinity` types, then the Pod can be scheduled onto a node ig one of the specified terms can be satisfied (terms are ORed).
- If you specify multiple expressions in a single `matchExpressions` filed associated with a term in `nodeSelectorTerms`, then the Pod can be scheduled onto a node only if all the expressions are satisfied. (expressions are ANDed)

### Node Affinity Weight
- You can specify a `weight` between 1 and 100 for each instance of the `preferredDuringSchedulingIgnoredDuringExecution` affinity type.
- When the schedular finds nodes that meet all the other scheduling requirements of the Pod, the scheduler iterates through every preferred rule that the node satisfies and adds the value of the `weight` for that expression to a sum.
- The final sum is added to the score of other priority functions for the node. Nodes with the highest total score are prioritized when the scheduler makes a scheduling decision for the Pod.
- For example:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: pod-with-affinity-weight
    spec:
      containers:
        - name: nginx
          image: nginx
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - preference:
                matchExpressions:
                  - key: label1
                    operator: In
                    values:
                      - key1
              weight: 1
            - preference:
                matchExpressions:
                  - key: label2
                    operator: In
                    values:
                      - key2
              weight: 50  
    ```
- If there are two possible nodes that match the `ppreferredDuringSchedulingIgnoredDuringExecution` rule, one with the `label1:key1` label and another with `label2:key2` label, the schedular considers the `weight` of each node and adds the weight to the other scores for that node, and schedules the Pod on the node with the highest final score.

### Inter-Pod affinity and anti-affinity
- Inter-pod affinity and anti-affinity allow you to constrain which nodes your Pods can be scheduled on based on the labels of Pods already running on that node, instead of the node labels.

#### Types of Inter-Pod Affinity and Anti-affinity
- Inter-pod affinity and anti-affinity take the form "this Pod should (or in the case of anti-affinity, should not) run in a X if that X is already running one or more Pods that meet rule Y"
- Where X is a topology domain like node, rack, cloud provider zone or region, or similar and Y is the rule Kubernetes tried to satisfy.
- You express these rules (Y) as label selectors with an optional associated list of namespaces.
- Pods are namespaced objects in Kubernetes, so Pod labels also implicitly have namespaces.
- Any label selector for Pod labels should specify the namespaces in which kubernetes should look for those labels.
- You can express the topology domain (X) using a `topologyKey` which is the key for the node label that the system uses to denote the domain.
- Note:
  - Inter-pod affinity and anti-affinity requires substantial amounts of processing which can slow down scheduling in large clusters significantly. We do not recommend using them in clusters larger than several hundred nodes.
  - Pod anti-affinity requires nodes to be consistently labelled, in other words, every node in the cluster must have an appropriate label matching `topologyKey`. If some or all nodes are missing the specified `topologyKey` label, it can lead to unintended behaviour.
- Similar ro node affinity are two types of Pod affinity and anti-affinity as follows:
  - `requiredDuringSchedulingIgnoredDuringExecution`
  - `preferredDuringSchedulingIgnoredDuringExecution`
- For Example, you could use
  - `requiredDuringSchedulingIgnoredDuringExecution` affinity to tell the scheduler to co-locate Pods of two services in the same cloud provider zone because they communicate with each other a lot.
  - Similarly, you could use `preferredDuringSchedulingIgnoredDuringExecution` anti-affinity to spread Pods from a service across multiple cloud provider zones.
- To use inter-pod affinity, use the `affinity.podAffinity` filed in the Pod spec. For inter-pod anti-affinity, use the `affinity.podAntiAffinity` field in the Pod spec

#### Scheduling Behavior
- When scheduling a new Pod, the kubernetes scheduler evaluates the Pod's affinity/anti-affinity in the context og the current cluster state:
  - Hard constraints (Node Filtering):
    - `podAffinity.requiredDuringSchedulingIgnoredDuringExecution` and `podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution`:
      - The scheduler ensured the new Pod is assigned to nodes that satisfy these required affinity and anti-affinity rules based on existing Pods.
  - Soft Constraints (Scoring):
    - `podAffinity.preferredDuringSchedulingIgnoredDuringExecution` and `podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution`:
      - The scheduler scores nodes based on how well they meet these preferred affinity and anti-affinity rules to optimize Pod placement
  - Ignored Fields:
    - Existing Pods `podAffinity.preferredDuringSchedulingIgnoredDuringExecution`:
      - These preferred affinity rules are not considered during the scheduling decision for new Pods.
    - Existing Pods `podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution`:
      - Similarly, preferred anti-affinity rules of existing pods are ignored during scheduling

#### Scheduling a Group of Pods with Inter-pod Affinity to themselves
- If the current Pod being scheduled is the first in a series that have affinity to themselves, it is allowed to be scheduled ig it passes all other affinity checks.
- This is determined by verifying that no other Pod in the cluster matches the namespace and selector of this Pod, that the Pod matches its own terms, and the chosen node matches all required topologies.
- This ensures that there will not be a deadlock even if all the Pods have inter-pod affinity specified.

#### Pod affinity example
    
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: with-pod-affinity
    spec:
      containers:
        - name: nginx
          image: nginx
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - topologyKey: topology.kubernetes.io/zone
              labelSelector:
                matchExpressions:
                  - key: security
                    operator: In
                    values:
                      - S1
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                topologyKey: topology.kubernetes.io/zone
                labelSelector:
                  matchExpressions:
                    - key: security
                      operator: In
                      values:
                        - S2
              weight: 100
    ```

- This example defines one Pod affinity rule and one Pod anti-affinity rule. The Pod affinity rule used the "hard" `requiredDuringSchedulingIgnoredDuringExecution`, while the anti-affinity rule uses the "soft" `preferredDuringSchedulingIgnoredDuringExecution`
- The affinity rule specifies that the scheduler is allowed to place the example Pod on a node only if that node belongs to a specific zone where other Pods have been labeled with `security=S1`
- For instance, if we have a cluster with a designated zone, let's call it `Zone V`, consisting of nodes labeled with `topology.kubernetes.io/zone=V`, the scheduler can assign the Pod to any node within Zone V, as long as there is at least one Pod within Zone V already labelled with `security=S1`.
- Conversely, if there are no Pods with `security=S1` labels in Zone V, the scheduler will not assign the example Pod to any node in that zone.
- The anti-affinity rule specifies that the scheduler should try to avoid scheduling the Pod on a node if that node belongs to a specific zone where other Pods have been labeled with `security=S2`.
  - For instance, If we have a cluster with a designated zone, let's call it "Zone R", consisting of nodes labelled with `topology.kubernetes.io/zone=R`, the schedular should avoid assigning the Pod to any node within Zone R, as long as there is at least one Pod within Zone R already labelled with `security=S2`.
  - Conversely, the anti-affinity rule does not impact scheduling into Zone R if there are no Pods with `security=S2` labels 
- You can use the `In`, `NotIn`, `Exists`, and `DoesNotExist` values in the `operator` filed for Pod affinity and anti-affinity.
- In principle, the `topologyKey` can be any allowed label key with the following exceptions for performance and security reasons:
  - For Pod affinity and anti-affinity, an empty `topologyKey` filed is not allowed in both `requiredDuringSchedulingIgnoredDuringExecution` and `preferredDuringSchedulingIgnoredDuringExecution`.
  - For `requiredDuringSchedulingIgnoredDuringExecution` Pod anti-affinity rules, the admission controller `LimitPodHardAntiAffinityTopology` limits `topologyKey` to `kubernetes.io/hostname`. You can modify or disable the admission controller if you want to allow custom topologies.
- In addition to `labelSelector` and `topologyKey`, you can optionally specify a list of namespaces which the `labelSelector` should match aganist using the `namespaces` filed at the same level as `labelSelector` and `topologyKey`. If omitted or empty `namespaces` default to the namespace of the Pod where the affinity/anti-affinity definition appears.

#### Namespace Selector
- You can also select matching namespaces using `namespaceSelector`, which is a label query over the set of namespaces. The affinity term is applied to namespaces selected by both `namespaceSelector` and `namespaces` filed.
- Note that an empty `namespaceSelector` ({}) matches all namespaces, while a null or empty `namespaces` list and null `namespaceSelector` matches the namespace of the Pod where the rule is defined.

#### matchLabelKeys
- Kubernetes includes an optional `matchLabelKeys` field for Pod affinity or anti-affinity. The field specifies keys for the labels that should match with the incoming Pod's labels, when satisfying the Pod (anti)affinity.
- The keys are used to look up values from the Pod labels; those key-value labels are combines (using AND) with the match restrictions defines using the `labelSelector` filed.
- The combined filter selects the set of existing Pods that will be taken into Pod (anti)affinity calculation.

- A common use case is to use `matchLabelKeys` with `pod-template-hash` (set on Pods managed as part of a Deployment, where tha value is unique for each revision).
- Using `pod-template-hash` in `matchLabelKeys` allows you to target the Pods that belong to the same revision as the incoming Pod, so that a rolling upgrade won't break affinity.

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: app-server
    spec:
      template:
        spec:
          affinity:
            podAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - labelSelector:
                    matchExpressions:
                      - key: app
                        operator: In
                        values:
                          - database
                  topologyKey: topology.kubernetes.io/zone
                  # Only Pods from a given rollout are taken into consideration when calculating pod affinity.labelSelector:
                  # If you update the Deployment, the replacement Pods follow their own affinity rules
                  matchLabelKeys:
                    - pod-template-hash
        
    ```

#### mismatchLabelKeys
- kubernetes includes an optional `mismatchLabelKeys` filed for Pod affinity or anti-affinity. The filed specifies keys for the labels that should not match with the incoming Pod's labels, when satisfying the Pod (anti)affinity.

- One example use case is to ensure Pods go to the topology domain (node, zone, etc) where only Pods from the same tenant or team are scheduled in. In other words to avoid running Pods from two different tenants on the same topology domain at the same time.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        tenant: tenant-a # assume that all relevant Pods have a "tenant" label set
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            # Ensure that the pods associated with this tenant land on the correct node pool
            - topologyKey: node-pool
              matchLabelKeys:
                - tenant
              labelSelector: {}
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            # ensure that Pods associated with this tenant can't schedule to nodes used for different tenant
            - topologyKey: node-pool
              mismatchLabelKeys:
                - tenant
              labelSelector:
                matchExpressions:
                  - key: tenant
                    operator: Exists
    ```
  
#### More practical use-cases
- Inter-pod affinity and anti-affinity can be even more useful when they are used with higher level collection such as ReplicaSets, StatefulSets and Deployments, etc.
- These rules allow you to configure that a set of workloads should be co-located in the same defined topology; for example, preferring to place two related Pods onto the same node.
- For example: imagine a three-node cluster. You use the cluster to run a web-application and also an in-memory cache (such as Redis). For this example, also assume that latency between the web application and the memory cache should be as low as is practical. You can use inter-pod affinity and anti-affinity to co-locate the web servers with the cache as much as possible
- In the following example Deployment for redis cache, the replicas get the label `app=store`. The `podAntiAffinity` rule tells the scheduler to avoid placing multiple replicas with the `app=store` on a single node. This creates each cache in a separate node

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: redis-cache
    spec:
      selector:
        matchLabels:
          app: store
      replicas: 3
      template:
        metadata:
          labels:
            app: store
        spec:
          containers:
            - name: redis
              image: redis:latest
          affinity:
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - topologyKey: "kubernetes.io/hostname"
                  labelSelector:
                    matchExpressions:
                      - key: app
                        operator: In
                        values:
                          - store
    ```
- The following example Deployment for web servers creates replicas with the label `app=web-store`. 
- The Pod affinity rule tells the scheduler to place each replica on a node that has a Pod with label `app=store`.
- The Pod anti-affinity rule tells the scheduler never to place multiple `app=web-store` servers on a single node.

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      labels:
        name: web-server
    spec:
      selector:
        matchLabels:
          app: web-store
      replicas: 3
      template:
        metadata:
          labels:
            app: web-store
        spec:
          containers:
            - name: nginx
              image: nginx:latest
          affinity:
            podAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - topologyKey: "kubernetes.io/hostname"
                  labelSelector:
                    matchExpressions:
                      - key: app
                        operator: In
                        values:
                          - store
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - topologyKey: "kubernetes.io/hostname"
                  labelSelector:
                    matchExpressions:
                      - key: app
                        operator: In
                        values:
                          - web-store
        
    ```
  
---

### nodeName
- `nodeName` is more direct form of node selection than affinity or `nodeSelector`. `nodeName` is a field in Pod Spec.
- If the `nodeName` filed is not empty, the scheduler ignores the Pod and the kubelet on the named node tries to place the Pod on that node.
- Using `nodeName` overrules using `nodeSelector` or affinity and anti-affinity rules
- Some limitations of using nodeName to select nodes are:
  - If the named node does not exist, the Pod will not run, and in some cases may be automatically deleted.
  - If the named node does not have the resources to accommodate the Pod, the Pod will fail and its reason will indicate why, for example OutOfMemory or OutOfCPU.
  - Node Names in cloud environments are not always predictable or stable.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
      nodeName: kube-01
    ```
    
### nominatedNodeName
- `nominatedNodeName` can be used for external components to nominate node for a pending pod.
- This nomination is the best effort: it might be ignored if the scheduler determines the pod cannot go to nominated node.
- Also, this field can be (over)written by the schedular:
  - If schedular finds a node to nominate via the preemption
  - If schedular decides where the pod is going, and move it to the binding cycle.
    - Note that, In this case, `nominatedNodeName` is put only when the pod has go through `WaitOnPermit` or `PreBind` extension points

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
    ...
    status:
      nominatedNodeName: kube-01
    ```