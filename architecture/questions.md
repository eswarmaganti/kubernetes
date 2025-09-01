# Kubernetes Architecture Questions

## ✅ Beginner Level (Core Concepts)

### What are the main components of the Kubernetes architecture?
- Kubernetes is a distributed system. We can classify the components into two parts, Control Plane and Data Plane.
- In Control Place we have `kube-api-server`, `etcd`, `kube-schedular`, `kube-controller-manager`, `cloud-controller-manager`
- The Data Place / Worker Plane consists all the worker nodes which are responsible for running the kubernetes objects. In Data Place we have `kubelet`, `kube-proxy` and `Container Runtime`.

<hr>

### What is the role of the Control Plane in Kubernetes?
- **Cluster State Management**: 
  - Maintains the desired state of kubernetes objects (Pods, Deployment, Services e.t.c)
  - Continuously compares the desired state (user/automation) with the actual state (from cluster) and reconciles differences.
- **Scheduling Workloads**:
  - The control plane includes a scheduler called `kube-schedular` which is responsible for scheduling the pods to appropriate worker nodes based on resource availability.
- **Orchestration & Lifecycle Management**:
  - Ensures that containers are running, restarted on failure, scale up/down, replaced when needed - via various controllers.
- **API Access & Cluster Entry Point**:
  - `kube-apiserver` serves as the central point for all the API interactions using kubectl, CICD and monitoring systems etc.
- **Persistent State System**:
  - The `etcd` is a distributed key-value store, to persist all cluster configuration and metadata.
- **Monitoring & Node Management**:
  - Detect Node failures, monitors cluster health, removes or replaces unhealthy nodes.
- **Cloud Integration**
  - If using a cloud-provider, the `cloud-control-manager` handles cloud specific tasks like managing the load balancers, routes and persistent volumes.

<hr>

### What are the components of the Control Plane?
- `kube-api-server`: The frontend of the kubernetes control plane, It exposes the Kubernetes API and is the only component that interacts directly with the etcd and other control plane components.
- `kube-scheduler`: Watches the unscheduled pods and assigns them to suitable worker nodes based on resource availability, node affinity taints/tolerations etc.
- `etcd`: A distributed key-value store used as a backing store for all the cluster data.
- `kube-controller-manager`: Runs various in-built controllers (NodeController, ReplicationController, JobController) to ensure desired state of cluster objects.
- `cloud-controller-manager`: Its responsible for managing the cloud specific resources like load balancers, volumes and networking.
<hr>

### What is the role of the Kubelet in the Kubernetes architecture?
- Kubelet is a node level agent that runs on every worker node, It's deployed a DaemonSet. It is responsible for managing the life cycle of containers on that node as instructed by the control plane.
- Roles:
  - **Pod Lifecycle Management**: Ensures the containers defines in podSpec are running and healthy, If a container crashes, kubelet restart it based on the restart policy
  - **Node Registration**: Registers a node with API Server when it boots up. Periodically send heartbeat status to control plane to indicate the node is healthy and ready.
  - **Container Runtime Communication**: Talks to container runtimes `containerd, CRI-O` using Container Runtime Interface to manage the containers.
  - **PodSpecification Retrieval**: Watches the api-server for new pods assigned to the node. Pulls the podSpec and execute the instructions
  - **Health Monitoring & Probes**: Executes readiness and liveness probes for each container, helping kubernetes to know if containers are healthy and ready to receive traffic.
  - **Volume Management**: mounts and managed the persistent volumes defines in the podSpec.

<hr>

### What is the difference between a Master Node and a Worker Node?
- Master Node also known as Control Plane is responsible for managing the kubernetes cluster, maintaining the desired state and exposing the kubernetes API.
- Worker Node is responsible for running the pods and container, reports back the state to control plane. 
<hr>

### What is the function of etcd in Kubernetes architecture?
- `etcd` is a distributed key-value store which stores all the information about the kubernetes cluster state, the objects running inside the cluster and the metadata about the cluster.
- It ensures data persistent and serves the single source of truth for the control plane.
<hr>


### How does the kube-scheduler decide where to place a pod?
- The kube-schedular follows an two step approach called filter and scoring. 
- It will filter out all the worker nodes which are having available resources and is most suitable to run the pod and then it will rank them by assigning a score to each node based on available plugins. 
- The pod will be assigned high-scoring node or randomly among equals if there is a tie.
<hr>

### What is kube-apiserver and why is it considered the front end of the Kubernetes control plane?
- The kube-apiserver is a component of kubernetes control plane. 
- It is the entrypoint to the kubernetes control plane and exposes the Kubernetes API to the end users and other components.
- It is the only component which directly communicated with `etcd` and coordinates with other control plane components like `kube-scheduler` and controllers.
<hr> 

### What does the kube-controller-manager do?
- kube-control-manager runs various built-in controllers that continuously monitor the cluster's state and work to main the desired state.
- Examples include NodeController, JobController, ReplicaSet Controller etc. It watches the kube-apiserver and makes changes by creating and updating the kubernetes objects as needed.
<hr>

### What is the purpose of the kube-proxy on worker nodes?
- `kube-proxy` is a component of kubernetes worker plane and it runs on each node.
- It is responsible for managing the network rules that allow pod-to-pod and pod-to-service communication.
- It sets up IP routing and load balancing using iptables, ipvs or eBPF to forward traffic to the correct pod backing as a service.

<hr/>

## 🧪 Intermediate Level (Component Interactions & Internals)
### How do Kubernetes nodes communicate with the control plane?
- In kubernetes, the control plane manages the worker nodes. Communication flows in both directions:
- `Nodes -> Control Plane`
  - **Kubelet to kube-apiserver**
    - Each node runs a kubelet, which continuously talks to the kube-apiserver over HTTPS.
    - It registers the node, reports status (CPU, memory, pod health), and watches for new Pod Specs.
    - This is a pull-based model - kubelet pulls Pod definitions from the API Server.
  - **Authentication & Authorization**
    - Communication is TLS-secured using client certificates or tokens.
    - kube-apiserver authenticates kubelet requests via x.509 certificates or service accounts.
- `Control Plane to Nodes`
  - **kube-apiserver -> kubelet**
    - The API server doesn't directly push workloads to kubelet. Instead, kubelet polls the API server for desired PodSpecs.
    - For Logs, exec, or port-forwarding commands, the apiserver proxies the connections to the kubelet.
  - **kube-control-manager -> Node**
    - Indirectly updates Node status via API server objects, not direct connections.
- `Networking between Nodes and Control Plane`
  - All traffic goes through the `kube-apiserver`, which acts as the single communication hub.
  - Typical ports:
    - `6443` : kube-apiserver (main entry point)
    - `10250` : kubelet API (for exec/logs)

<hr/>

### What is the typical flow of a pod creation request in Kubernetes?

- **kubectl sends request to kube-apiserver**
   - when a user runs kubectl commands
      ```bash
      kubectl run nginx --image=nginx
      ```
   - kubectl communicates with kube-apiserver (REST over HTTPS)
   - Authentication + RBAC authorization happens.
- **API server validates and stores the object**
  - kube-apiserver
    - validates the PodSpec (YAML/JSON)
    - stores it in **etcd**
  - At this point, the Pod object exists in `Pending` state (no node assigned to it).
- **Scheduler assigns a Node**
  - The kube-scheduler continuously watches API server for unscheduled pods (.spec.nodeName not set).
  - Scheduler evaluates the cluster resources (CPU, memory, taints/toleration, affinity etc.) and picks the best Node.
  - Scheduler updates the Pod object in etcd with `.spec.nodeName`
- **Kubelet on Node picks up the Pod**
  - Each node's kubelet watches the apiserver for pods assigned to it.
  - When kubelet identifies a new Pod scheduled to it.
    - It talks to the container runtime
    - pulls the. required container image
    - creates the container inside a Pod sandbox.
- **Pod Networking**
  - The CNI plugin assigns an IP to the Pod.
  - kube-proxy updates service routing rules (iptables/IPVS) for traffic to the Pod.
- **Pod status updated**
  - kubelet continuously reports Pod status to the apiserver.
  - API server updates etcd, finally users can view the status using kubectl.

<hr/>

### How does etcd ensure consistency of the cluster state?
- The etcd ensures consistency using the **Raft consensus algorithm**, which elects a leader to handle writes and replicate them to followers.
- A write is communicated only after a majority quorum acknowledges it, preventing split-brain. (The change is only considered committed when more than half of the nodes `majority quorum` confirm that have written it to their logs. This prevents split-brain, where different nodes might think they have different truths, because no decision is finalized unless the majority agrees. If quorum is not reached, etcd rejects writes to protects consistency)
- Reads and writes are linearizable, ensuring clients always see the latest committed state.
- Data is persisted through WAL (Write-Ahead Log) and snapshots for durability. This guarantees strong consistency even during node failures.

`Example:`
- Imagine we have a three node etcd cluster running your kubernetes control plane. A developer deploys a new application (PodSpec) through kubectl. The apiserver writes this change to etcd.
  - The Leader etcd node receives the write and sends it to the remaining two followers.
  - If at least 2 out of 3 nodes acknowledge the write, etcd commits it and the new Pod definition becomes the cluster truth.
  - If one node is down, the majority (2/3) an still commit safely.
  - If the cluster splits (1 node isolates, 2 together) only th e side with quorum (2 nodes) continues to accept writes, while the isolated one rejects them.
<hr/>

### How does the control plane enforce the desired state of the cluster?

- The control plane enforces the desired state using a declerative model.
- The kube-apiserver stores the desired state in etcd. Controllers (via kube-controller-manager) continuously compare the desired state (in etcd) with the actual cluster state. 
- If there is a mismatch, controllers take corrective actions (creating, rescheduling, or deleting pods). This reconciliation loop ensures the cluster always converges to desired state.

<hr/>

### What happens when a node fails? How does the Kubernetes architecture respond?

- When a node fails, the **kubelet stops sending heartbeats to the apiserver**.
- The node controller marks it as `NotReady` after a timeout (default ~40s). Pods running on the node will go into `Unknown` state.
- If the pods are managed by Deployment/ReplicaSet, the scheduler creates replacement pods on healthy nodes.
- For StatefulSets, Pods are recreated with same identity. If using DaemonSets, their pods are only recreated when the node recovers. This self-healing mechanism ensures high availability of workloads.
- **StaticPods**: These are created directly by the kubelet from manifest files on the node. If node fails, they are not recreated elsewhere because the API server doesn't manage them. They come back only when the failed node recovers.
- **Pods without controllers**: If the node fails, these pods lost permanently since there's no ReplicaSet/Deployment to reschedule them. Admins must recreate them manually.

<hr/>

### Can you explain how the controller pattern works in Kubernetes architecture?
- The controller pattern in kubernetes follows a control loop that continuously drives the cluster toward its desired state.
- A user defines the desired state in etcd via API server (e.g., 3 replicas of a pod). Controllers (like ReplicaSet, Deployment, Job) consistently watch the cluster state through the API server. If the actual state drifts (e.g., only 2 pods running instead of 3), the controller takes corrective action (creates another pod) until the actual state matches the desired one.
- This loop ensures self-healing and automation in the cluster.

<hr/>

### How do the Scheduler and Controller Manager interact with the API Server?

Both the Scheduler and Controller Manager interact with the cluster only through the kube-apiserver.
- The scheduler watches the API server for unscheduled pods, decides the best Node, and updated the pods `.spec.nodeName` back vua the API server
- The Controller Manager (ReplicaSet, Deployment, Node Controllers, etc) watches objects through the API server and make changes (like creating/deleting pods) by writing back updates.
- They never talk directly to etcd, The API Server is the single communication hub.

<hr/>

### How are changes in the cluster state propagated across components?
- Changes in cluster state are always propagated through the kube-apiserver. Components like kubelet, scheduler, and controllers use the watch mechanism to subscribe to resource changes.
- When a user or controller updates an object, the API server stores it in etcd and notifies watchers.
- Each component then reacts - for example, kubelet sees a new Pod assigned to its node and creates it. This event-driven watch system ensures all components stay in sync without polling constantly.
- 


### What is the role of Informers and Watchers in Kubernetes architecture?
- Watchers in kubernetes maintain an open connection to the API server and get notified whenever a resource changes (e.g., pod created, deleted, updated).
- Informers build on top of watchers, they not only watch resources but also cache the objects locally and deliver event notifications (Add, Update, Delete) to controllers. This reduces the API server load, avoids constant polling, and ensures controllers react quickly to cluster state changes.
- The kubelet runs a watcher on the API server for pod objects assigned to its node. When a new pod is scheduled, the watcher notifies kubelet immediately so it can start the container.
- The ReplicaSet controller uses an informer to watch pods. If a pod is deleted, the informer's cache updates and triggers the controller logic to create a replacement pod, instead of hitting the API server again.

<hr/>

### Why is the API Server a single point of interaction in the Kubernetes architecture?
- The API Server is the central hub of kubernetes, acting as the single point of truth for all cluster interactions. All components - kubelet, scheduler, controllers, kubectl - communicate only with the API server, never directly with etcd or each other.
- This ensures security (authn/authz), consistency (validated state stored in etcd), and extensibility (custom resources via same API). By being the single entry point, it standardizes communication and prevents split or conflicting cluster states.

<hr/>

## 🔬 Advanced Level (High Availability, Performance, Scalability)

### How does Kubernetes achieve high availability in the control plane?
- Kubernetes achieves the HA in the control plane by running multiple replicas of critical components like API server, controller manager, and scheduler across different nodes.
- The API Server runs behind a load balancer, ensuring requests are distributed and failover is seamless.
- The etcd is deployed as a multi-node cluster (3,5,or 7) nodes using Raft consensus to keep data consistent. Leader election among controllers and schedulers ensures only one active leader operates at a time. This redundancy eliminates single point of failure and keeps the control plane resilient.

<hr/>

How can you horizontally scale the Kubernetes control plane components?

What are the architectural limitations of a monolithic control plane?

How does Kubernetes achieve eventual consistency in a distributed architecture?

What are the considerations for securing communication between Kubernetes components (TLS, authentication, etc.)?

How is leader election handled among controller managers?

What are the differences between CRI, CNI, and CSI and how do they fit into Kubernetes architecture?

How does the architecture support extensions via custom controllers or CRDs?

What happens in the control plane when a Deployment is updated?

How does Kubernetes architecture differ in managed services like EKS, AKS, or GKE compared to self-managed clusters?