# Deployments

- A deployment manages a set of pods to run an application workload, usually one that doesn't maintain state.
- A deployment provides declarative updates for Pods and ReplicaSets.
- You describe a *desired state* in a Deployment, and the Deployment Controller changes the actual state to the desired state at a controlled rate.
- You can define Deployments to create new ReplicaSets, or to remove existing Deployments and adopt all their resources with new Deployments.

## Use Cases
The following are typical use cases for Deployments
- `Create a Deployment to rollout a ReplicaSet`: The ReplicaSet creates Pods in the background. Check the status of the rollout to see if it succeeds or not.
- `Declare the new state of the Pods` by updating the *PodTemplateSpec* of the Deployment. A new ReplicaSet is created, and the Deployment gradually scales it up while scaling down the old ReplicaSet, ensuring Pods are replaced at a controlled rate. Each new ReplicaSet updates the revision of the Deployment.
- `Rollback to an earlier deployment revision` If the current state of the Deployment is not stable. Each rollback updates the revision of the Deployment.
- `Scale up the Deployment to facilitate more load`.
- `Pause the rollout of a Deployment` to apply multiple fixes to its PodTemplateSpec and then resume it to start a new rollout.
- `Use the status of the Deployment` as an indicator that a rollout has stuck
- `Clean up older ReplicaSets` that you don't need anymore.

## Creating a Deployment:
The following is an example of a Deployment. It creates a ReplicaSet to bring up three `nginx` pods:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80

```
In this above example:
- A Deployment named `nginx-deployment` is created, indicated by the `.metadata.name` field. This name will become the basis for the ReplicaSets and Pods which are created later.
- The Deployment creates a ReplicaSet that creates three replicated Pods, indicated by the `.spec.replicas` field.
- The `.spec.selector` field defines how the created ReplicaSet finds which Pods to manage. In this case, you select a label that is defined in PodTemplate (`app: nginx`).
- The `.spec.template` field contains the following subfields: 
  - The Pods are labeled `app: nginx` using `.metadata.labels` field
  - The Pod template's specification, or `.spec` field indicates that the pods run one container, `nginx`, which runs the `nginx` docker hub image.
  - Create one container and name it `nginx` using the `.spec.containers[0].name` field.

The following steps given below to create the above deployment.
1. Create the Deployment by running the following command
    ```bash
    $ kubectl apply -f deployment/manifests/nginx-deployment.yaml 
    deployment.apps/nginx-deployment created
    ```
2. Check the Deployment status using the below command
    ```bash
    $ kubectl get deployment/nginx-deployment
    ```
    If the deployment is still being created, the output is similar to the following
    ```bash
    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-deployment   0/3     0            0           1s 
    ```
   - `NAME`: lists the names of the Deployments in the namespace
   - `READY`: displays how many replicas of the application are available to your users. it follows the pattern ready/desired
   - `UP-TO-DATE`: displays the number of replicas that have been updated to achieve the desired state.
   - `AVAILABLE`: displays how many replicas of the application are available to your users.
   - `AGE`: displays the amount of time that the application has been running.
3. To see the Deployment rollout status, Run the below command
    ```bash
    kubectl rollout status deployment/nginx-deployment
    deployment "nginx-deployment" successfully rolled out
    ```
4. To see the ReplicaSet (rs) created by the deployment, Run the below command
    ```bash
    $ kubectl get rs
    NAME                         DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6   3         3         3       10m
    ```
   - Notice that the name of the ReplicaSet is always formatted as `[DEPLOYMENT-NAME]-[HASH]`. This name will become the basis for the ReplicaSet.
5. To see the labels automatically generated for each pod, Run the below command
    ```bash
    $ kubectl get pods --show-labels
    NAME                               READY   STATUS    RESTARTS        AGE   LABELS
    nginx-deployment-576c6b7b6-fh8mv   1/1     Running   0               14m   app=nginx,pod-template-hash=576c6b7b6
    nginx-deployment-576c6b7b6-lljml   1/1     Running   0               14m   app=nginx,pod-template-hash=576c6b7b6
    nginx-deployment-576c6b7b6-lnpjf   1/1     Running   0               14m   app=nginx,pod-template-hash=576c6b7b6
    ```
- `pod-template-hash` label is added by the deployment controller to every ReplicaSet that a Deployment creates or adopts.
- This label ensures that child ReplicaSets of a Deployment do not overlap. It is generated by hashing the `PodTemplate` of ReplicaSet and using the resulting hash as the label value is added to the ReplicaSet selector, Pod template labels.

## Updating a Deployment
A Deployment's rollout is triggered if and only if the Deployment's Pod template `spec.template` is changed, for example, if the labels or container images of the template are updated. Other updates such as scaling the Deployment do not trigger a rollout.

Steps to update a deployment:
- Let's update the nginx Pods to use the `nginx:1.16.1` image instead of the latest image.

```bash
$ kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
deployment.apps/nginx-deployment image updated
```
- Alternatively you can edit the Deployment and change the `.spec.template.spec.container[0].image` from `nginx:latest` to `nginx:1.16.1`

```bash

$ kubectl edit deployment/nginx-deployment
deployment.apps/nginx-deployment edited

$ kubectl rollout status deployment/nginx-deployment
deployment "nginx-deployment" successfully rolled ou
```
- You can watch updates to the pods by using below command
```bash

$ kubectl get pods --watch
NAME                                READY   STATUS              RESTARTS     AGE
nginx-deployment-576c6b7b6-jrx6w    1/1     Running             0            76s
nginx-deployment-576c6b7b6-p6cgd    1/1     Running             0            72s
nginx-deployment-586855f7f6-4wf29   1/1     Running             0            7s
nginx-deployment-586855f7f6-gvsxf   0/1     ContainerCreating   0            3s
web-server-pod                      1/1     Running             1 (9d ago)   10d
nginx-deployment-586855f7f6-gvsxf   1/1     Running             0            4s
nginx-deployment-576c6b7b6-p6cgd    1/1     Terminating         0            73s
nginx-deployment-586855f7f6-4ghfr   0/1     Pending             0            0s
nginx-deployment-586855f7f6-4ghfr   0/1     Pending             0            0s
nginx-deployment-586855f7f6-4ghfr   0/1     ContainerCreating   0            0s
nginx-deployment-576c6b7b6-p6cgd    0/1     Terminating         0            73s
nginx-deployment-576c6b7b6-p6cgd    0/1     Terminating         0            74s
nginx-deployment-576c6b7b6-p6cgd    0/1     Terminating         0            74s
nginx-deployment-576c6b7b6-p6cgd    0/1     Terminating         0            74s
nginx-deployment-586855f7f6-4ghfr   1/1     Running             0            4s
nginx-deployment-576c6b7b6-jrx6w    1/1     Terminating         0            81s
nginx-deployment-576c6b7b6-jrx6w    0/1     Terminating         0            81s
nginx-deployment-576c6b7b6-jrx6w    0/1     Terminating         0            82s
nginx-deployment-576c6b7b6-jrx6w    0/1     Terminating         0            82s
nginx-deployment-576c6b7b6-jrx6w    0/1     Terminating         0            82s
```
### Rollover (multiple updates in-flight)
- Each time a new Deployment is observed by the Deployment controller, a ReplicaSet is created to bring up the desired pods.
- If the Deployment is updated, the existing replicaset that controls Pods whose labels match the `.spec.selector` but whose template does not match `.spec.template`  are scaled down.
- Eventually new ReplicaSet is scaled to `.spec.replicas` and all old ReplicaSets is scaled to 0.
- If you update a Deployment while an existing rollout is in progress, the Deployment creates a new ReplicaSet as per the update and starts scaling that up, and rolls over the ReplicaSet that it was scaling up previously — it will add it to its list of old ReplicaSets and start scaling it down. 

### Label selector updates
- It is generally discouraged to make label selector updates and it is suggested to plan your selectors up front. In any case, if you need to perform a label selector update, exercise great caution and make sure you have grasped all of your implications.
- In API version `apps/v1`, a Deployment's label selector is immutable after it gets created.

## Rollback a Deployment
Sometimes, you may want to rollback a Deployment; for example, when the Deployment is not stable, such as crash looping. By default, all the Deployment's rollout history is kept in the system so that you can rollback anytime you want
- A Deployment revision is created when a Deployment's rollout is triggered. This means that the new revision is created if and only if the Deployment's Pod template `.spec.template` is changed, for example, if you update the labels or container images of the template.
- Other updates such as scaling the Deployment do not create a Deployment revision, so that you can facilitate simultaneous manual- or auto-scaling. This means that when you roll back to an earlier revision, only the Deployment's pod template part os rolled back. 

`Scenario:`
- Suppose that you made a typo while updating thr Deployment, by putting the image name as `nginx:1.291` instead of `nginx:1.29.1`
```bash

$ kubectl set image deployment/nginx-deployment nginx=nginx:1.291
deployment.apps/nginx-deployment image updated
```
- The rollout gets stuck. You can verify it by checking the status
```bash

$ kubectl rollout status deployment/nginx-deployment
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated... 
```
- The ReplicaSet information by running the below command
  - Here the old replicas from ReplicaSet `nginx-deployment-586855f7f6` is 3 and from the new ReplicaSet `nginx-deployment-5cfb57d7d4 ` is 1
```bash
 
$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-586855f7f6   3         3         3       35m
nginx-deployment-5cfb57d7d4   1         1         0       2m44s
```
- Looking at the Pods, created, you will see that 1 Pod created by new ReplicaSet is stuck in an image pull loop
```bash 

$ kubectl get pods
NAME                                READY   STATUS             RESTARTS      AGE
nginx-deployment-586855f7f6-4ghfr   1/1     Running            0             34m
nginx-deployment-586855f7f6-4wf29   1/1     Running            0             34m
nginx-deployment-586855f7f6-gvsxf   1/1     Running            0             34m
nginx-deployment-5cfb57d7d4-bdfkj   0/1     ImagePullBackOff   0             5m
```
- Get the description of the Deployment to observe the events
```bash 

$kubectl describe deployment/nginx-deployment
Name:                   nginx-deployment
Namespace:              default
CreationTimestamp:      Tue, 02 Sep 2025 05:43:35 +0530
Labels:                 app=nginx
Annotations:            deployment.kubernetes.io/revision: 5
Selector:               app=nginx
Replicas:               3 desired | 1 updated | 4 total | 3 available | 1 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=nginx
  Containers:
   nginx:
    Image:         nginx:1.291
    Port:          80/TCP
    Host Port:     0/TCP
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    ReplicaSetUpdated
OldReplicaSets:  nginx-deployment-576c6b7b6 (0/0 replicas created), nginx-deployment-586855f7f6 (3/3 replicas created)
NewReplicaSet:   nginx-deployment-5cfb57d7d4 (1/1 replicas created)
Events:
  Type    Reason             Age                From                   Message
  ----    ------             ----               ----                   -------
  Normal  ScalingReplicaSet  40m                deployment-controller  Scaled up replica set nginx-deployment-586855f7f6 to 1
  Normal  ScalingReplicaSet  40m                deployment-controller  Scaled down replica set nginx-deployment-576c6b7b6 to 2 from 3
  Normal  ScalingReplicaSet  40m                deployment-controller  Scaled up replica set nginx-deployment-586855f7f6 to 2 from 1
  Normal  ScalingReplicaSet  40m                deployment-controller  Scaled down replica set nginx-deployment-576c6b7b6 to 1 from 2
  Normal  ScalingReplicaSet  40m                deployment-controller  Scaled up replica set nginx-deployment-586855f7f6 to 3 from 2
  Normal  ScalingReplicaSet  38m                deployment-controller  Scaled up replica set nginx-deployment-576c6b7b6 to 1 from 0
  Normal  ScalingReplicaSet  38m                deployment-controller  Scaled down replica set nginx-deployment-586855f7f6 to 2 from 3
  Normal  ScalingReplicaSet  38m                deployment-controller  Scaled up replica set nginx-deployment-576c6b7b6 to 2 from 1
  Normal  ScalingReplicaSet  37m (x8 over 38m)  deployment-controller  (combined from similar events): Scaled up replica set nginx-deployment-586855f7f6 to 3 from 2
  Normal  ScalingReplicaSet  36m (x2 over 40m)  deployment-controller  Scaled down replica set nginx-deployment-576c6b7b6 to 0 from 1
  Normal  ScalingReplicaSet  7m48s              deployment-controller  Scaled up replica set nginx-deployment-5cfb57d7d4 to 1
```

### Checking the Rollout history of a Deployment
1. First, check the revisions of this Deployment
```bash 

$kubectl rollout history deployment/nginx-deployment
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
3         <none>
4         <none>
5         updated the image to nginx:1.291
```
   - The CHANGE-CAUSE is copied from the Deployment annotation `kubernetes,io/change-cause` to its revisions upon creation. We can also specify the `CHANGE-CAUSE` message by
   ```bash 
   $ kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause='updated the image to nginx:1.291'
   deployment.apps/nginx-deployment annotated
   ```
2. To see the details of each revision, run
```bash

$ kubectl rollout history deployment/nginx-deployment --revision=5
deployment.apps/nginx-deployment with revision #5
Pod Template:
  Labels:       app=nginx
        pod-template-hash=5cfb57d7d4
  Annotations:  kubernetes.io/change-cause: updated the image to nginx:1.291
  Containers:
   nginx:
    Image:      nginx:1.291
    Port:       80/TCP
    Host Port:  0/TCP
    Environment:        <none>
    Mounts:     <none>
  Volumes:      <none>
  Node-Selectors:       <none>
  Tolerations:  <none>
 
```
### Rolling Back to a previous revision
Follow the steps given below to roll back the deployment from the current version to the previous version, which is version 2.
1. Now you've decided to undo the current rollout and rollback to the previosu version:
## Scaling a Deployment

## Pausing and Resuming a rollout of a Deployment


## Deployment Status

## Writing a Deployment Spec