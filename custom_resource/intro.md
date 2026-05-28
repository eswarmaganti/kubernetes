# Custom Resources
> *Custom Resources* are the extension of the Kubernetes API that is not necessarily available in a default kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core kubernetes functions are now built using custom resources, making Kubernetes more modular.
- A *resource* is an endpoint in Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in *pods* resources contains a collection of Pod objects.
- Custom resources can appear and disappear in a running cluster through dynamic registration, and cluster admins can update custom resources independently of the cluster itself. Once a custom resource is installed, users can create and access its objects using kubectl, just as they do for built-in resources like *Pods*.

## Custom Controllers
- On their own, custom resources let you store and retrieve structured data. When you combine a custom resource with a custom controller, custom resources provide a true *declarative API*
- The Kubernetes declarative API enforces a separation of responsibilities. You declare the desired state of your resource. The Kubernetes controller keeps the current state of Kubernetes objects in sync with your declared desired state. This is in contrast to an imperative API, where you *instruct* a server what to do.
- You can deploy and update a custom controller on a running cluster, independently of the cluster's lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combines with custom resources. The Operator pattern combines custom resources and custom controllers. You can use custom controllers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

## Adding custom resources
- Kubernetes provides two ways tp add custom resources to your cluster:
  - CRDs are simple and can be created without any programming
  - API Aggregation require programming, but allows more control over API behaviours like how data is stored and conversion between API versions.
- Kubernetes provides these two options to meet the needs of different users, so that neither ease of use nor flexibility is compromised.
- Aggregated APIs are subordinate API servers that sit behind the primary API server, which acts as a proxy. This arrangement is called API aggregation (AA). To users, the Kubernetes API appears extended.
- CRDs allow users to create new type of resources without adding another API server. You do not need to understand API Aggregation to use CRDs.

### Custom Resource Definitions (CRDs)
- The  CustomResourceDefinition API resource allows you to define custom resources. Defining a CRD object creates a new custom resource with a name and schema that you specify.
- The Kubernetes API serves and handles the storage of your custom resource. The name of the CRD object itself must be a valid DNS subdomain name derived from the defined resource name and its API group, the name of an object whose kind/resource is defined by a CRD must also be a valid DNS subdomain name. 

### API Server aggregation
- Usually, each resource in the Kubernetes API requires code that handles REST request and manages persistent storage of objects. The main Kubernetes API server handles built-in resources like *pods* and *services*, ad also generically handle custom resources through CRDs.
- The aggregation layer allows you to provide specialized implementations for your custom resources by writing and deploying your own API Server. The main API server delegates requests to your API server for custom resources that you handle, making them available to all of its clients.

## Choosing a method for adding custom resources
- CRDs are easier to use. Aggregated APIs are more flexible. Choose the method that best meets your needs
- Typically, CRDs are a good fit if:
  - You have a handful of fields
  - You are using the resource within your company, or as part of a small open-source project

| CRDs | Aggregated API |
| -----| ---------------| 
| Do not require programming. Users can choose any language for a CRD controller| Requires programming and building binary and image |  
| No additional service to run; CRDs are handled by API server| An additional service to create and that could fail |
| No ongoing support once the CRD is created. Any bug fixes are picked up as part of normal Kubernetes Master upgrades | May need to periodically pickup bug fixes from upstream and rebuild and update the Aggregated API Server |
| No need to handle multiple versions of your API; for example, when you control the client for this resource, you can upgrade it in sync with the API | You need to handle multiple versions of your API; for example, when developing an extension to share with the world |