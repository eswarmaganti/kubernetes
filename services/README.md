# Services
- Kubernetes Services are resources that map network traffic to the Pods in your cluster, you need to create a Service each time you expose a set of Pods over the network, whether within your cluster or externally.
- Kubernetes Services are API objects that enable network exposure for one or more cluster Pods. Services are integral to the Kubernetes networking model and provide important abstractions of lower-level components, which could behave differently between different clouds.

## Why are services needed in Kubernetes?
- Services are necessary because of the distributed architecture of Kubernetes Cluster. Apps are routinely deployed as Pods that could have thousands of replicas, spanning hundreds of physical compute nodes.
- When a user interacts with the app, their request needs to be routed to any one of the available replicas, regardless of where it's placed.
- Services sit in front of Pods to achieve this behavior. All networks flow into the service before being redirected to one of the available Pods. Your other apps can then communicate with the service's IP address or DNS name to reliably access the Pods you've exposed.
- DNS for Services is enabled automatically through the Kubernetes service discovery system. Each service is assigned a DNS A or AAAA record in the format `<service-name>.<namespace-name>.svc.cluster-domain` 
  - Ex: a service called `demo` in the default namespace will be accessible within a `cluster.local` cluster at `demo.default.svc.cluster.local`
- This enables reliable in-cluster networking without having to look up service IP address.

## Kubernetes Service Types
- All kubernetes Services ultimately forward network traffic to the Pods they represent. Kubernetes provides five main types of services, each one controls how traffic is routed to pods, and the choice depends on visibility and routing requirements:
  - `ClsuterIP`: Default, internal-only access within the cluster.
  - `NodePort`: Exposes service on each node's IP at a static port.
  - `LoadBalancer`: Creates external load balancer for public access (cloud only) 
  - `ExternalName`: Maps service to the external DNS names, no proxying.
  - `Headless`: No cluster IP, exposes individual Pod IP's.

## `type: ClusterIP`
- This default service type assigns an IP address from a pool of IP addresses that your cluster has reserved for that purpose.
- Several of the other types of Service build omn the `ClusterIP` type as a same foundation
- If you define a service that has the `.spec.ClusterIP` set to `None` then kubernetes does not assign IP address.
### Choosing your own IP address
- You can specify your own cluster IP address as part of a `Service` creation request. To do this, set the `.spec.clusterIP` field. If you already have a existing DNS entry that you wish to reuse, or legacy systems that are configured for specific IP address and difficult to re-configure.
- The IP address that you choose must be a valida IPv4 or IPv6 address from within the `service-cluster-ip-range` CIDR range that is configured for the API server.
- If you try to create a Service with an invalid `clusterIP` address value the API server will return a 422 HTTP status code to indicate that there's a problem.


## `type: NodePort`

- If you set the `type` field to `NodePort`, the kubernetes control plane allocates a port from a range specified by `--service-node-port-range` flag (default: 30000 - 32767).
- Each node proxies that port (the same port number on every node) into your service. Your service reports the allocated port in its `.spec.ports[*].nodePort` field.

- Using NodePort gives you freedom to set up your own load balancing solution, to configure environments that are not fully supported by Kubernetes, or even to expose one or more nodes IP addresses directly.
- For a NodePort service, Kubernetes additionally allocates a port (TCP, UDP or SCTP to match the protocol of the service). Every node in the cluster configures itself to listen on that assigned port and to forward to one of the ready endpoints associated with that Service.
- You will be able to contact the `type: NodePort` service, from outside the cluster, by connecting to any node using the appropriate protocol and appropriate port (as assigned to that service).

### Choosing your own port
- If you want a specific port number, you can specify a value in the `nodePort` field. The control plane will either allocate you that port or report that the API transaction failed.
- This means that you need to take care of possible port collisions yourself. You also have to use a valid port number, one that's inside the range configured for NodePort use.
- Here is an example manifest for service of `type: NodePort` that specified a NodePort value (3007, in this example)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nodeport-service
spec:
  type: NodePort
  selector:
    name: my-app
  ports:
    - port: 80  # service port inside cluster
      targetPort: 8080 # Pod's application port (container Port)
      nodePort: 3007 # node's external port
```

### Reserve Nodeport ranges to avoid collisions 
- The policy for assigning ports to NodePort service applies to both auto-assignment and the manual assignment scenarios. When a user wants to create a NodePort service that uses a specific port, that target port may conflict with another port that has already been assigned.
- To avoid this problem, **the port range for NodePort services is divided into two bands. Dynamic port assignment uses the upper band by default, and it may use the lower band once the upper band has been exhausted. Users can then allocate from the lower band with a lower risk of port collisions**.

### Custom IP Address configuration for type: NodePort Services
- You can set up nodes in your cluster to use a particular IP address for service node port services. You might want to do this if each node is connected to multiple networks (for example, one network for application traffic, and another network for traffic between nodes and the control plane). 
- If you want to specify a particular IP address to proxy the port, you can set the `--nodeport-addreess` flag for kube-proxy or the equivalent `nodePortAddress` field of the kube-proxy configuration file to particular IP blocks.
- This flag takes the comma-delimited list of IP blocks to specify IP address ranges that kube-proxy should consider as local to this node.
- For example, If you start kube-proxy with the `--nodeport-addresses=127.0.0.0/8` flag, kube-proxy only selects the loopback interface for Nodeport Services.
- The default for `--nodeport-addresses` is an empty list. This means that kube-proxy should consider all available network interfaces for NodePort. 

## `type: LoadBalancer`
- On cloud providers which support external load balancers, setting the `type` field to `LoadBalancer` provisions a load balancer for your service.
- The actual creation of the load balancer happens asynchronously, and information about the provisioned balancer is published in the Service's `.status.loadBalancer` field.
  
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: my-lb-service
  spec:
    type: LoadBalancer
    selector:
      name: my-app
    ports:
      - port: 80
        protocol: TCP
        targetPort: 8080
        
    clusterIP: 10.0.171.239
  status:
      loadBalancer:
        ingress:
          - ip: 192.0.2.127
  ```
- Traffic from the external load balancer is directed at the backend pods. The cloud provider decides how it is load balanced.
- To implement a Service of `type: LoadBalancer`, kubernetes typically starts off by making the changes that are equivalent to you requesting a service of `type: NodePort`. The cloud-control-manager component then configures the external load balancer to forward traffic to that assigned node port.


## `type: ExternalName`

- Services of type ExternalName map a Service to DNS name, not to a typical selector such as `my-service` or `cassandra`. You specify these Services with the `spec.externalName` parameter.
- This service definition, for example, maps the `my-service` Service in the `prod` namespace to `my.database.example.com`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ExternalName
  externalName: my.database.example.com
```
- Note: A service of `type: ExternalName` accepts an IPv4 address string, but treats that string as a DNS name comprising digits, not as an IP address (the internet does not however allow such names in DNS). Services with external names that resemble IPv4 addresses are not resolved by DNS servers.
- When looking up the host `my-service.prod.svc.cluster.local`, the cluster DNS Service returns a CNAME record with the value `my.database.example.com`.
- Accessing `my-service` works in the same way as other Services but with the crucial difference that redirection happens at the DNS level rather than via proxying or forwarding.
- You should later decide to move your database into your cluster, you can start its Pods, add appropriate selectors or endpoints, and change the Service's `type`.

## Headless Services

- Sometimes you don't need load-balancing and a single service IP. In this case, you can create what are termed *headless Services*, by explicitly specifying `"None"` for the cluster IP address `.spec.clusterIP`.
- You can use a headless service to interface with other service discovery mechanisms, without being tied to Kubernetes implementation.
- For headless services, a ClusterIP is not allocated, kube-proxy does not handle these services, and there is no load balancing or proxying done by the platform for them.
- *A headless Service allows a client to connect to whichever Pod it prefers, directly*. **Services that are headless don't configure routes and packet forwarding using virtual IP addresses and proxies; instead, headless Services report the endpoint IP address of the individual pods via internal DNS records, served through the cluster's DNS Service.**
- To define a headless service, you make a Service with `.spec.type` set to ClusterIP and you additionally set `.spec.clusterIP` to None.
- The string value None is a special case and is different from leaving the `.spec.clusterIP` field unset.
- How DNS is automatically configured depends on whether the Service has selectors defined:
### With selectors
- For headless services that define selectors, the endpoint controller creates EndpointSlices in the Kubernetes API, and modifies the DNS configuration to return A or AAAA records that point directly to the Pods backing the service.
### Without selectors
- For headless services that do not define selectors, the control plane does not create EndpointSlice objects.
  - Normally, If you define a `selector`, kubernetes watches the matching Pods and cretes **EndpointSlice** objects automatically (so Service DNS points to Pod IPs).
  - But if you don't define a `selector`. Kubernetes has no idea which Pods belong. Instead, you must **manually define Endpoint or rely on ExternalName**

- However, systems look for and configures either:
  - DNS CNAME records for `type: ExternalName` Services
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: external-service
    spec:
      type: ExternalName
      clusterIP: None
      externalName: api.example.com
      ports:
        - port: 443
          targetPort: 443
    ```
    - `external-service.default.svc.cluster.local` is a CNAME to `api.example.com`
    - Your pods can just use the Service DNS name, but it resolves outside the cluster
      
  - DNS A / AAAA records for all IP addresses for the Service's ready endpoints, for all Service types other than `ExternalName`.
    - for IPv4 endpoints, the DNS system creates A records.
    - for IPv6 endpoints, the DNS system creates AAAA records.

    ```yaml
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: external-db
    spec:
      type: ClusterIP
      clusterIP: None
      ports:
        - port: 5432
          targetPort: 5432
  
    ---
    apiVersion: v1
    kind: Endpoints
    metadata:
      name: external-db
    subsets:
      - addresses:
          - ip: 192.168.100.10 # IPv4
          - ip: fd00::1234 # IPv6
        ports:
          - port: 5432
    ```
    - DNS query for `external-db.default.svc.cluster.local` returns, `192.168.100.10` as an A record and `fd00::1234` as an AAAA record.
- When you define headless service without a selector, the `port` must match the `targetPort`