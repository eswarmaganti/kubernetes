# Kubernetes Operator Overview
> A Kubernetes Operator is a method of packaging, deploying, and managing a Kubernetes application. A Kubernetes application is both deployed on Kubernetes and managed using the Kubernetes API and kubectl tooling.
> An operator is a custom Kubernetes controller that uses custom resources (CR) to manage applications and their components. High-level configuration and settings are provided by the user within a CR. The kubernetes operator translates the high-level directives into low leval actions, based on best practices embedded within the operator's logic.

> A custom resource is the API extension mechanism in Kubernetes. A custom resource definition (CRD) defines a CR and lists out all the configuration available to users of the operator.

- A Kubernetes operator is an application-specific controller that extends the functionality of the Kubernetes API to create, configure, and manage instances of complex applications on behalf of a Kubernetes user.
- It builds upon the basic kubernetes resources and controller concepts, but includes domain or application-specific knowledge to automate the entire life cycle of the software it manages.
- In Kubernetes, controllers of the control plane implement control loops that repeatedly compare the desired state of the cluster to its actual state. If the cluster's actual state does not match the desired state, then the controller takes action to fix the problem.
- Kubernetes Operator introduce new object types through custom resources definitions. Custom resource definitions can be handled by the Kubernetes API just like built-in objects, including interaction via kubectl and inclusion in RBAC policies.
- Kubernetes operator continues to monitor its application as it runs, and can back up data, recover from failures, and upgrade the application over time, automatically.

## How operators manage Kubernetes applications
- Kubernetes can manage and scale stateless applications, such as web apps, mobile backends, and API services, without requiring any additional knowledge about how these applications operate. The built-in features of Kubernetes are designed to easily handle these tasks.
- However, stateful applications, like databases and monitoring systems, require additional domain-specific knowledge that kubernetes doesn't have. It needs this knowledge in order to scale, upgrade, and reconfigure these applications.
- Kubernetes operator encode this specific domain knowledge into Kubernetes extensions so that it can manage and automate an application's life cycle.
- By removing difficult manual application management tasks, Kubernetes operator make these processes scalable, repeatable, and standardized.

## Operator Framework
- The Operator Framework is an open source project that provides developer and runtime kubernetes tools, enabling you to accelerate the development of an operator.
- The Operator Framework includes:
  - **Operator SDK**: Enables developers to build operators based on their expertise without requiring knowledge of kubernetes API complexities
  - **Operator Lifecycle Management**: Oversees installation, updates and management of the lifecycle of all the operates running across Kubernetes cluster.
  - **Operator Metering**: Enables usage reporting for operators that provide specialized services.