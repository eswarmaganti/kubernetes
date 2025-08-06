✅ Beginner Level (Core Concepts)
What are the main components of the Kubernetes architecture?

What is the role of the Control Plane in Kubernetes?

What are the components of the Control Plane?

What is the role of the Kubelet in the Kubernetes architecture?

What is the difference between a Master Node and a Worker Node?

What is the function of etcd in Kubernetes architecture?

How does the kube-scheduler decide where to place a pod?

What is kube-apiserver and why is it considered the front end of the Kubernetes control plane?

What does the kube-controller-manager do?

What is the purpose of the kube-proxy on worker nodes?




🧪 Intermediate Level (Component Interactions & Internals)
How do Kubernetes nodes communicate with the control plane?

What is the typical flow of a pod creation request in Kubernetes?

How does etcd ensure consistency of the cluster state?

How does the control plane enforce the desired state of the cluster?

What happens when a node fails? How does the Kubernetes architecture respond?

Can you explain how the controller pattern works in Kubernetes architecture?

How do the Scheduler and Controller Manager interact with the API Server?

How are changes in the cluster state propagated across components?

What is the role of Informers and Watchers in Kubernetes architecture?

Why is the API Server a single point of interaction in the Kubernetes architecture?


🔬 Advanced Level (High Availability, Performance, Scalability)
How does Kubernetes achieve high availability in the control plane?

How can you horizontally scale the Kubernetes control plane components?

What are the architectural limitations of a monolithic control plane?

How does Kubernetes achieve eventual consistency in a distributed architecture?

What are the considerations for securing communication between Kubernetes components (TLS, authentication, etc.)?

How is leader election handled among controller managers?

What are the differences between CRI, CNI, and CSI and how do they fit into Kubernetes architecture?

How does the architecture support extensions via custom controllers or CRDs?

What happens in the control plane when a Deployment is updated?

How does Kubernetes architecture differ in managed services like EKS, AKS, or GKE compared to self-managed clusters?