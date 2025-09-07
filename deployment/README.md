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
1. Now you've decided to undo the current rollout and rollback to the previous version, we can use any of the below commands
    - `kubectl rollout undo deployment/<deployment-name>`
    - `kubectl rollout undo deployment/<deployment-name> --to-rivision=<revision_number>`

    ```bash
    $ kubectl rollout undo deployment/nginx-deployment 
    deployment.apps/nginx-deployment rolled back
    $ kubectl rollout status deployment/nginx-deployment 
    deployment "nginx-deployment" successfully rolled out 
    
    $ kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause='Rolled back to working version'
    deployment.apps/nginx-deployment annotated
    $ kubectl rollout history deployment/nginx-deployment
    deployment.apps/nginx-deployment 
    REVISION  CHANGE-CAUSE
    3         <none>
    5         updated the image to nginx:1.291
    6         Rolled back to working version
    
    ```
2. Check if the rollback was successful and the Deployment is running as expected
    ```bash
     
    $ kubectl get deployment/nginx-deployment
    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-deployment   3/3     3            3           2d23h
    ```

## Scaling a Deployment
- You can scale a Deployment by using the following command
    
    ```bash 
    $ kubectl scale deployment/nginx-deployment --replicas=10
    deployment.apps/nginx-deployment scaled
    
    $ kubectl get pods
    NAME                                READY   STATUS    RESTARTS      AGE
    nginx-deployment-586855f7f6-4ghfr   1/1     Running   0             24h
    nginx-deployment-586855f7f6-4wf29   1/1     Running   0             24h
    nginx-deployment-586855f7f6-9gqvw   1/1     Running   0             55s
    nginx-deployment-586855f7f6-c4nb7   1/1     Running   0             55s
    nginx-deployment-586855f7f6-fqxz7   1/1     Running   0             55s
    nginx-deployment-586855f7f6-gvsxf   1/1     Running   0             24h
    nginx-deployment-586855f7f6-h5d29   1/1     Running   0             55s
    nginx-deployment-586855f7f6-kk8pw   1/1     Running   0             55s
    nginx-deployment-586855f7f6-mn6pt   1/1     Running   0             55s
    nginx-deployment-586855f7f6-ql2n6   1/1     Running   0             55s
    ```
- Assume that HPA is enabled in your cluster, you can set up an autoscaler for your Deployment and choose the minimum and maximum number of pods you want to run based on the CPU utilization of your existing Pods.

    ```bash
    $ kubectl autoscale deployment/nginx-deployment --min=10 --max=15 --cpu-percent=80
    
    deployment.apps/nginx-deployment scaled
    ```

### Proportional Scaling
- When a *Rolling Update* Deployment is mid-rollout (or even paused) you can end up with multiple active ReplicaSets (old + new).
- If you or an HPA scales the Deployment at that moment, Kubernetes **spreads the extra (or fewer) replicas across all the active ReplicaSets in proportion to their current sizes**, instead of putting them all in one just the newest one. This reduces risk and keeps capacity balanced while rollout settles.

- It only applies to *RollingUpdate* (the default) because that's when multiple RS can be active.
- The controller *allocates more replicas to the ReplicaSet that already has more*, fewer to the smaller one(s).
- Leftover replicas from rounding go to the ReplicaSet with the most replicas; RS with zero replicas aren't scaled up.
- 
#### A Quick numerical Example:
- You have a deployment with 10 replicas, `maxSurge=3` and `maxUnavailable=2`
- You start a rollout (new image). Now you have two RS; say old=8, new=5 (blocked by availability)
- You (or HPA) scale the deployment to 15 (add 5)
- With proportional scaling, kubernetes adds ~3 to the larger RS and ~2 to the smaller RS. Any rounding leftovers are given to the largest RS. Over time, the rollout still migrates replicas to the new RS. Over time, the rollout still migrates replicas to the new RS as its Pods become healthy.

#### Why it exists:
- Without proportional scaling, a mid-rollout scale-up would push all the new replicas into the new RS—which can amplify a bad release or exceed surge limits. Proportional scaling hedges by keeping capacity spread while the rollout proves itself.

- Example:

    ```bash
    $ kubectl apply -f manifests/nginx-deployment.yaml
    deployment.apps/nginx-deployment created
    
    $ kubectl get deployment/nginx-deployment
    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-deployment   10/10   10           10          49s
    
    
    $ kubectl set image deployment/nginx-deployment nginx=nginx:1.28.0
    deployment.apps/nginx-deployment image updated
    
    $ kubectl get rs
    NAME                          DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6    8         8         8       65s
    nginx-deployment-5b8c8cd5cd   5         5         0       3s
    
    $ kubectl scale deployment/nginx-deployment --replicas=15
    deployment.apps/nginx-deployment scaled
    
    $ kubectl get rs 
    NAME                          DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6    10        10        7       74s
    nginx-deployment-5b8c8cd5cd   8         8         2       12s
    
    ```
- You can see the extra replicas split between the old and new RS, roughly in proportion to their sizes.

## Pausing and Resuming a rollout of a Deployment

- When you update a Deployment, or plan to, you can pause rollouts for the Deployment before yu trigger one or multiple updates.
- When you're ready to apply those changes, you can resume rollouts for the Deployment. This approach allows you to apply multiple fixes in between pausing and resuming without triggering unnecessary rollouts.

Example:
- With a Deployment that was created
    ```bash
  
    $ kubectl get deployment/nginx-deployment
    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-deployment   5/5     5            5           52s
    ```

Get the ReplicaSet details
    ```bash
    
    $ kubectl get rs
    NAME                         DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6   5         5         5       108s
    ```

- Pause the rollout by running the below command
    ```bash
     
    $ kubectl rollout pause deployment/nginx-deployment
    deployment.apps/nginx-deployment paused
    ```

- Update the image of the Deployment
    ```bash 
    $ kubectl set image deployment/nginx-deployment nginx=nginx:1.28.0
    deployment.apps/nginx-deployment image updated
    ```

- Notice no new rollout started

    ```bash 

    $ kubectl rollout history deployment/nginx-deployment
    deployment.apps/nginx-deployment 
    REVISION  CHANGE-CAUSE
    1         <none>
    ```

- Get the ReplicaSet details to verify the rollout 
    ```bash
    
    $ kubectl get rs                                                  
    NAME                         DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6   5         5         5       6m15s
    ```

- You can make as many updates as you wish, for example, update the resources that will be used

    ```bash
    
    $ kubectl set resources deployment/nginx-deployment -c=nginx --limits=cpu=100m,memory=128Mi
    deployment.apps/nginx-deployment resource requirements updated
    ```
- The initial state of the Deployment prior to pausing its rollout will continue its function, but new updates to the Deployment will not have any effect as long as the Deployment rollout is paused.
- Eventually, resume the Deployment rollout and observe a new ReplicaSet coming up with all the new updates:

    ```bash
    $ kubectl rollout resume deployment/nginx-deployment
    deployment.apps/nginx-deployment resumed
    
    ~$kubectl get rs --watch
    NAME                          DESIRED   CURRENT   READY   AGE
    nginx-deployment-576c6b7b6    3         3         3       14m
    nginx-deployment-68dfb9965d   5         5         0       4s
    nginx-deployment-68dfb9965d   5         5         1       8s
    nginx-deployment-576c6b7b6    2         3         3       14m
    nginx-deployment-576c6b7b6    2         3         3       14m
    nginx-deployment-576c6b7b6    2         2         2       14m
    nginx-deployment-68dfb9965d   5         5         2       12s
    nginx-deployment-576c6b7b6    1         2         2       14m
    nginx-deployment-576c6b7b6    1         2         2       14m
    nginx-deployment-576c6b7b6    1         1         1       14m
    nginx-deployment-68dfb9965d   5         5         3       15s
    nginx-deployment-576c6b7b6    0         1         1       14m
    nginx-deployment-576c6b7b6    0         1         1       14m
    nginx-deployment-576c6b7b6    0         0         0       14m
    nginx-deployment-68dfb9965d   5         5         4       19s
    nginx-deployment-68dfb9965d   5         5         5       23s
    ```

- Get the status of the rollout
    ```bash 
    
    $ kubectl rollout status deployment/nginx-deployment
    deployment "nginx-deployment" successfully rolled out
    
    $ kubectl rollout history deployment/nginx-deployment
    deployment.apps/nginx-deployment 
    REVISION  CHANGE-CAUSE
    1         <none>
    2         <none>
    ```
## Deployment Status

A Deployment enters various states during its lifecycle. It can be `progressing` while roll out a new ReplicaSet, it can be `complete` or it can `fail to progress`.

### Progressing Deployment
Kubernetes marks a Deployment *progressing* when one of the following talks is performed:
- The Deployment creates a new ReplicaSet.
- The Deployment is scaling up its newest ReplicaSet.
- The Deployment is scaling down its older ReplicaSet(s).
- New Pods become ready or available.

When a rollout becomes "progressing," the Deployment controller adds a condition with the following attributes to the Deployment's `.status.conditions`
- `type: Progressing`
- `status: "True"`
- `reason: NewReplicaSetCreated` | `reason: FoundNewReplicaSet` | `reason: ReplicaSetUpdated`

### Complete Deployment
- Kubernetes marks a Deployment as `complete` when it has the following characteristics:
  - All the new replicas associated with the Deployment have been updated to the latest version you've specified, meaning any updates you've requested have been completed.
  - All the replicas associated with the Deployment are available.
  - No old replicas for the Deployment are running.
- When the rollout becomes "complete", the Deployment controller sets a condition with the following attributes to the Deployment's `.status.conditions`
  - `type: Progressing`
  - `status: "True"`
  - `reason: NewReplicaSetAvailable`
- This `Processing` condition will retain a status value of `"True"` until a new rollout is initiated. The condition holds even when availability of replicas changes
- When you check if a Deployment has completed by using `kubectl rollout status`. If the rollout completed successfully, `kubectl rollout status` returns a zero exit code
    ```bash
    
    $ kubectl rollout status deployment/nginx-deployment
    deployment "nginx-deployment" successfully rolled out
    $ echo $?
    0
    ```

### Failed Deployment
- Your Deployment may get stuck trying to deploy its newest ReplicaSet without ever completing. This can occur due to some of the following factors:
  - Insufficient Quota
  - Readiness Probe Failures
  - Image Pull Errors
  - Insufficient Permissions
  - Limit Ranges
  - Application runtime misconfiguration
- One way you can detect this condition is to specify a deadline parameter in your Deployment spec: `.spec.progressDeadlineSeconds`. This denotes the number of seconds the Deployment controller waits before indicating that the Deployment progress has stalled.
- Once the deadline has been exceeded, the Deployment controller adds a DeploymentCondition with the following attributes to the Deployment's `.status.conditions` 
  - `type: Progressing`
  - `status: "False"`
  - `reason: progressDeadlineExceeded`
- This condition can also fail early and is then set to status value of `"False"` due to reasons as `ReplicaSetCreateError`. Also, the deadline is not taken into account anymore once the Deployment rollout is completed.

Note:
- kubernetes takes no action on a stalled Deployment other than to report a status condition with `reason: ProgressDeadlineExceeded`. Higher level orchestrators can take advantage of it and act accordingly, for example, roll back the Deployment to its previous version.
- If you pause a Deployment rollout, Kubernetes does not check progress against your specified deadline. You can safely pause a Deployment rollout in the middle of a rollout and resume without triggering the condition for exceeding deadline.


## Clean up Policy
- You can set `.spec.revisionHistoryLimit` field in a Deployment to specify how many old ReplicaSets for this Deployment you want to retain. The rest will be garbage-collected in the background. By default, it is 10.
- **Explicitly setting this field to 0, will result in cleaning up all the history of your Deployment, thus the Deployment will not be able to roll back**
- The cleanup only starts after a Deployment reached a complete state. If you set `.spec.revisionHistoryLimit` to 0, any rollout nonetheless triggers creation of a new ReplicaSet before kubernetes removes the old one.
- Even with a non-zero revision history limit, you can have more ReplicaSets than the limit you configure.
  - If pods are crash looping, and there are multiple rolling updates events triggered over time, you might end up with more ReplicaSets than the `.spec.revisionHistoryLimit` because the Deployment never reaches a complete state.
