# Taints and Tolerations
- *Node affinity* is a property of Pods that *attracts* them to a set of nodes. *Taints* are opposite -- they allow a node to repel a set of pods.
- *Tolerations* are applied to pods. Tolerations allow the scheduler to schedule pods with matching taints.
- Tolerations allow scheduling but don't guarantee scheduling: the scheduler also evaluates other parameters as part of its function.
- Taints and tolerations work together to ensure that pods are not scheduled onto inappropriate nodes. One or more taints are applied to a node; this marks that the node should not accept any pods that do not tolerate the taints.

## Concepts
- You can add a taint to a node using `kubectl taint`. For example:
  - `kubectl taint nodes node1 key1=value1:NoSchedule`
  - This places a taint on node `node1`. The taint has key `key1`, value `value1`, and taint effect `NoSchedule`. This means that no pod will be able to schedule onto `node1` unless it has a matching toleration.
- To remove the taint added by the command above, you can run:
  - `kubectl taint nodes node1 key1=value1:NoSchedule-`
- You specify a toleration for a pod in the PodSpec. Both of the following tolerations "match" the taint created by the `kubectl taint` line above, and thus pod with either toleration would be able to schedule onto `node1`
    
    ```yaml
    tolerations:
      - key: "key1"
        operator: "Equal"
        value: "value1"
        effect: "NoSchedule"
    ```
    
    ```yaml
    tolerations:
      - key: "key1"
        operator: "Exists"
        effect: "NoSchedule"
    ```
- The default kubernetes scheduler takes taints and tolerations into account when selecting a node to run a particular Pod.
- However, if you manually specify the `.spec.nodeName` for a Pod, that action bypasses the scheduler; the Pod is then bound onto the node where you assigned it, even if there are `NoSchedule` taints on that node that you selected.
- If this happens and the node also has a `NoExecute` taint set, the kubelet will eject the Pod unless there is an appropriate tolerance set.

- Here is an example of a pod that has some tolerations defined:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
      tolerations:
        - key: "example-key"
          operator: "Exists"
          effect: "NoSchedule"
    ```
  - The default value for `operator` is `Equal`. A toleration "matches" a taint if the keys are same and the effects are the same, and:
    - the `operator` is `Exists` (in this case, no `value` should be specified) or,
    - the `operator` is `Equal` and the values should be equal.
    - There are two special cases: 
      - If the `key` is empty, then the `operator` must be `Exists`, which matches all the keys and values. The `effect` needs to be matched at the same time
      - An empty `effect` matches all effects with key `key1`
      
  - The allowed values for the effect filed are:
  - **No Execute**
    - This affects pods that are already running on the node as follows:
      - Pods that do not tolerate the taint are evicted immediately
      - Pods that tolerate the taint without specifying `tolerationSeconds` in their toleration specification remain bound forever
      - Pods that tolerate the taint with a specified `tolerationSeconds` remain bound for the specified amount of time. After the time elapses, the node lifecycle controller evicts the Pods from the node.
  - **NoSchedule**
    - No new Pods will be scheduled on the tainted node unless they have a matching toleration. Pods currently running on the node are not evicted.
  - **PreferNoSchedule**
    - It is a soft version of `NoSchedule`. The control plane will try to avoid placing a Pod that does not tolerate the taint on the node, but it is not guaranteed
- You can put multiple taints on the same node and multiple tolerations on the same pod.
- The way kubernetes processes multiple taints and tolerations is like a filter: start with all of a node's taints, then ignore the ones for which the pod has a matching toleration; the remaining un-ignored taints have the indicated effects on the pod. In particular
  - If there is at least one un-ignored taint with effect `NoSchedule` then Kubernetes will not schedule the pod onto that node
  - If there is no un-ignored taint with effect `NoSchedule` but there is at least one un-ignored taint with effect `PreferNoSchedule` then kubernetes will try to not schedule the pod onto the node
  - If there is at least one un-ignored taint with effect `NoExecute` then the pod will be evicted from the node (if it's already running on the node), and will not be scheduled onto the node (if it's not running on the node).

## Example Use cases:
- Taints and tolerations are a flexible way to steer pods away from nodes or evict pods that shouldn't be running. A few of the use cases are

### Dedicated Nodes:
- If you want to dedicate a set of nodes for exclusive use by a particular set of users, you can add a taint to those nodes and then add a corresponding toleration to their pods
- The pods with the tolerations will then be allowed to use the tainted (dedicated) nodes as well as any other nodes in the cluster.
- If you want to dedicate the node to them and ensure they only use the dedicated nodes, they should additionally add a label similar to taint to the same set of nodes (e.g. `dedicated=groupName`), and the admission controller should additionally add a node affinity to require that the pods can only schedule onto nodes labelled with `dedicated=groupName`.

### Nodes with special hardware:
- In a cluster where a small subset of nodes have specialized hardware (for example GPU's), it is desirable to keep pods that don't need the specialized hardware off of those nodes, thus leaving room for later-arriving pods that do need the specialized hardware.
- This can be done by tainting the node have the specialized hardware and adding a corresponding toleration to pods that use the special hardware.
- As in the dedicated nodes use case, it is probably easiest to apply the tolerations using a custom admission controller. For example, it is recommended to use Extended Resources to represent the special hardware, taint your special hardware nodes with extended resource name and run the ExtendedResourceToleration admission controller.
- Now because the nodes are tainted, no pods without the toleration will schedule on them. But when you submit a pod that requests the extended resource, the `ExtendedResourceToleration` admission controller will automatically add the correct toleration to the pod and that pod will schedule on the special hardware nodes.
- This will make sure that the special hardware nodes are dedicated for pods requesting such hardware, and you don't have to manually add tolerations to your pods.

---

## Taint based Evictions
- the node controller automatically taint a Node when certain conditions are true. The following taints are built in:
  - `node.kubernetes.io/not-ready`: Node is not ready. This corresponds to the NodeCondition `Ready` being `False`.
  - `node.kubernetes.io/unreachable`: Node is unreachable from the node controller. This corresponds to the NodeCondition `Ready` being `UnKnown`.
  - `node.kubernetes.io/memory-pressure`: Node has a memory pressure.
  - `node.kubernetes.io/disk-pressure`: Node has disk pressure
  - `node.kubernetes.io/pid-pressure`: Node has PID pressure
  - `node.kubernetes.io/unschedulable`: Node is unschedulable
  - `node.cloudprovider.kubernetes.io/uninitialized`: When the kubelet is started with an "external" cloud provider, the taint is set on a node to mark it as unusable. After a controller from the cloud-controller-manager initializes this node, the kubelet removes this taint.

- In case a node is to be drained, the node controller or the kubelet adds relevant taints with `NoExecute` effect. This effect is added by default for the `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreacheble` taints. If the fault condition returns to normal, the kubelet or node controller can remove the relevant taint(s).
- In some cases when the node is unreachable, the API server is unable to communicate with the kubelet on the node. The decision to delete the pods cannot be communicated to the kubelet until communication with the api server is re-established. In the meantime, the pods that are scheduled for deletion may continue to run on the partitioned node.

- you can specify `tolerationSeconds` for a Pod to define how long that Pod stays bound to a failing or unresponsive node.
- For example, you might want to keep an application with a lot of local state bound to node for a long time in the event of network partition, hoping that the partition will recover and thus the pod eviction can be avoided. The toleration you set for that pod might look like

    ```yaml
    tolerations:
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 6000
    ```
- **Note:** Kubernetes automatically adds a toleration for `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable` with `tolerationSeconds=300`, unless you, or a controller, set those tolerations explicitly. This automatically added tolerations means that pods remain bound to nodes for 5 minutes after one of these problems is detected 
- DaemonSet Pods are created with `NoExecute` tolerations for the following taints with no `tolerationSeconds`
  - `node.kubernetes.io/not-ready`
  - `node.kubernetes.io/unreachable`
- This ensures that DaemonSet pods are never evicted due to these problems.

---

## Taint nodes by condition
- The control plane, using the node controller, automatically creates taints with a `NoSchedule` effect for node conditions.
- The scheduler checks taints, not node conditions, when it makes scheduling decisions. This ensures that node conditions don't directly affect scheduling.
  - For example, if the `DiskPressure` node condition is active, the control plane adds the `node.kubernetes.io/disk-pressure` taint and does not schedule new pods onto the affected node.
  - If the `MemoryPressure` node condition is active, the control plane adds the `node.kubernetes.io/memory-pressure` taint.
- The DaemonSet controller automatically adds the following `NoSchedule` tolerations to all daemons, to prevent DaemonSets form breaking.
  - `node.kubernetes.io/memory-pressure`
  - `node.kubernetes.io/disk-pressure`
  - `node.kubernetes.io/pid-pressure`
  - `node.kubernetes.io/unschedulable`
  - `node.kubernetes.io/network-unavailable`















