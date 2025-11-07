# Volumes

Kubernetes *volumes* provide a way for containers in a pod to access and share data via *filesystem*. There are different kinds of volume that you can use for different purposes such as:
- populating a configuration file based on a ConfigMap or a Secret.
- providing some temporary scratch space for a pod.
- sharing a filesystem between two different containers in the same pod.
- sharing a filesystem between two different pods (even if those Pods run on different nodes)
- durably storing data so that it stays even if the Pod restarts or is replaced.
- passing configuration information to an app running in a container, based on details of the Pod the container is in (for ex: telling a sidecar container what namespace the Pod is running in).
- providing read-only access to data in a different container image.

Data sharing can be between different local processes within a container, or between different containers, or between Pods.

## Why volumes are important:
- Kubernetes volume abstraction can help to solve the below problems

1. Data persistence:
   - On-disk files in a container are ephemeral, which presents some problems for non-trivial applications when running in containers.
   - One such problem occurs when a container crashes or is stopped, the container state is not saved so all the files that were created or modified during the lifetime of the container are lost. After a crash, kubelet restarts the container with a clean state.

2. Shared Storage:
    - Another problem occurs when multiple containers are running in a `Pod` and need to share files. It can be challenging to set up and access a shared filesystem across all the containers.


## How Volumes work
- At its core, a volume is a directory, possibly with some data in it, which is accessible to the containers in a Pod.
- How that directory comes to be, the medium that backs it, and the contents of it are determined by the particular volume type used.
- To use a volume, specify the volumes to provide for the Pod in `.spec.volumes` and declare where to mount those volumes into containers in `.spec.containers[*].volumeMounts`
- When a pod is launched, a process in the container sees a filesystem view composed of the initial contents of the container image, plus volumes (if defined) mounted inside the container.
- The process sees a root filesystem that initially matches the contents of the container image. Any writes to within that filesystem hierarchy, if allowed, affect what that process views when it performs a subsequent filesystem access.
- Volumes are mounted at specified paths within the container filesystem. For each container defines within a pod, you must independently specify where to mount each volume that the container uses.

## Types of Volumes
kubernetes supports several types of volumes

### configMap
- A ConfigMap provides a way to inject configuration data into pods. The data stored in a ConfigMap can be referenced in a volume of type `configMap` and then consumed by containerized applications running in a pod.
- When referencing a ConfigMap, you provide the name of the ConfigMap in the volume. You can customize the path to use for a specific entry in the ConfigMap.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: configmap-pod
    spec:
      containers:
        - name: busybox
          image: busybox:latest
          command:
            - "/bin/sh"
            - "-e"
            - "echo 'Application is running' && tail -f /dev/null"
          volumeMounts:
            - mountPath: /etc/config
              name: config-vol
      volumes:
        - name: config-vol
          configMap:
            name: log-config
            items:
              - key: log_level
                path: log_level.conf
    ```
- The `log-config` ConfigMap is mounted as a volume, and all contents stored in its `log_level` entry are mounted into the Pod at path `/etc/config/log_level.conf`.

### emptyDir
- For a Pod that defines an `emptyDir` volume, the volume is created when the Pod is assigned to a node. As the name says, the `emptyDir` volume is initially empty.
- All the containers in the Pod can read and write the same files in the `emptyDir` volume, though that volume can be mounted at the same ir different paths in each container.
- When a Pod is removed from a node for any reason, the data in the `emptyDir` is deleted permanently.
- Some uses for an emptyDir are:
  - scratch space, such as for a disk-based merge sort.
  - checkpointing a long computation for recovery from crashes.
  - holding files that a content-manager container fetches while a webserver container serves the data.
- The `emptyDir.medium` filed controls where `emptyDir` volumes are stored. By default `emptyDir` volumes are stores on whatever medium that backs the node such as a disk, SSD, or a network storage, depending on your environment.
- If you set the `emptyDir.medium` field to `"Memory"`, kubernetes mounts a tmpfs (RAM-backed filesystem) for you instead. While tmpfs is very fast, be aware that, unlike disks, files you write count against the memory limit of the container that wrote them.
- A size limit can be specified for a default medium, which limits the capacity of the `emptyDir` volume.
- The storage is allocated from node ephemeral storage. If that is filled up from another source, the emptyDir may run out of capacity before this limit. If no size is specified, memory-backed volumes are sized to node allocatable memory.
- Example

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-pod
    spec:
      containers:
        - name: test-container
          image: nginx
          volumeMounts:
            - mountPath: /cache
              name: cache-volume
      volumes:
        - name: cache-volume
          emptyDir:
            sizeLimit: 500Mi
    ```
### fc (fibre channel)
- An `fc` volume type allows an existing fibre channel block storage volume to be mounted in a Pod.
- You can specify single or multiple target world wide names (WWNs) using the parameter `targetWWNs` in your Volume configuration.
- If multiple WWNs are specified, targetWWNs expect that those WWNs are from multi-path connections.

### hostPath
- A `hostPath` volume mounts a file or directory from the host node's filesystem into your Pod. This is not something most Pods will need, but it offers powerful escape hatch to some applications.
- Some uses for `hostPath` are:
  - running a container that needs access to node-level system components (such as a container that transfers system logs to a central location, accessing those logs using a read-only mount of `/var/log`).
  - Making a configuration file stored on the host system available read-only to a static pod; unlike normal pods, static pods cannot access ConfigMaps.
- Warning:
  - Using the `hostPath` volume type presents many security risks. If you can avoid using a `hostPath` volume, you should. For example, define a `local` PersistentVolume and use that instead.
  - Take care when using `hostPath` volumes, whether these are mounted as read-only or as read-write, because:
    - Access to the host filesystem can expose privileged system credentials (such as for the kubelet) or privileged APIs (such as the container runtime socket) that can be used for container escape or to attack other parts of the cluster.
    - Pods with identical configuration (such as created form PodTemplate) may behave differently on different nodes due to different files on the nodes.
    - `hostPath` volume usage is not treated as ephemeral storage usage. You need to monitor the disk usage by yourself because excessive `hostPath` disk usage will lead to disk pressure on thr node.
#### hostPath volume types
- In addition to the required `path` property, you can optionally specify a `type` for a `hostPath` volume.
- The Available types are
  - `""`: EmptyString (default) is for backward compatibility, which means that no checks will be performed before mounting the `hostPath` volume.
  - `DirectoryOrCreate`: If nothing exists at the given path, an empty directory will be created there as needed with permission set to 0755, having the same group and ownership with kubelet.
  - `Directory`: A directory must exist at the given path
  - `FileOrCreate`: If nothing exists at the given path, an empty file will create there as needed with permission set to 0644, having the same group and ownership with kubelet.
  - `File`: A file must exist at  the given path
  - `Socket`: A UNIX socket must exist at the given path
  - `CharDevice`: (Linux nodes only) A character device must exist at the given path
  - `BlockDevice`: (Linux nodes only) A block device must exist at the given path

Note: The `FileOrCreate` mode does not create the parent directory of the file. If the parent directory of the mounted file doesn't exist, the pod fails to stats.

Sometimes file ir directories created on the underlying hosts might only be accessible by root. You then either need to run your processes as root in a privileged container or modify the file permissions on the host to read from or write to `hostPath` volume,

#### hostPath configuration example

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: hostpath-pod
    spec:
      os: { name: linux }
      nodeSelector:
        kubernetes.io/os: linux
      containers:
        - name: nginx-container
          image: nginx:latest
          volumeMounts:
            - mountPath: /foo
              name: example-volume
              readOnly: true
      volumes:
        - name: example-volume
          hostPath:
            path: /data/foo
            type: Directory
    ```

#### hostPath FileOrCreate example
- The following manifest defines a Pod that mounts `/var/local/aaa` inside the single container in the Pod. If the node doesn't already have a path `/var/local/aaa`, the kubelet creates it as a directory and then mounts it into the Pod.
- If `/var/local/aaa` already exists but is not directory, the Pod fails. Additionally, the kubelet attempts to make a file named `/var/local/aaa/1.txt` inside that directory. If something already exists at that path and isn't a regular file, the Pod fails.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: hostpath-test-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          volumeMounts:
            - mountPath: /var/local/aaa
              name: mydir
            - mountPath: /var/local/aaa/1.txt
              name: myfile
      volumes:
        - name: mydir
          hostPath:
            path: /var/local/aaa
            type: DirectoryOrCreate
        - name: myfile
          hostPath:
            path: /var/local/aaa/1.txt
            type: FileOrCreate
    ```
### iscsi
- An `iscsi` volume allows an existing iSCSI (SCSI over IP) volume to be mounted into your Pod. Unlike `emptyDir`, whhich is erased when a Pod is removed, the contents of an `issci` volume are preserved and the volume is merely unmounted.
- This means that an iscsi volume can be pre-populated with data, and that data can be shared between pods.
- A feature of iSCSI is that it can be mounted as read-only by multiple consumers simultaneously. This means that you can pre-populated a volume with your dataset and then serve it in parallel from as many Pods as you need.
- Unfortunately, iSCSI volumes can only be mounted by a single consumer in read-write mode. Simultaneous write are not allowd.

### local

- A `local` volume represents a mounted local storage device as a disk partition or directory.
- Local volumes can only be used as statically created PersistentVolume. Dynamic provisioning is not supported.
- Compared to `hostPath` volumes, `local` volumes are used in a durable and portable manner without manually scheduling pods to nodes.
- The system is aware of the volume's node constraints by looking at the node affinity on the PersistentVolume.
- However, `local` volumes are subject to the availability of the underlying node and are not suitable for all applications.
- If the node becomes unhealthy, then the local volume becomes inaccessible to the pod. The Pod using the volume is unable to run.
- Applications using `local` volumes must be able to tolerate this reduced availability, as well as potential data loss, depending on the durability characteristics of the underlying disk.
    
    ```yaml
    
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: example-pv
    spec:
      capacity:
        storage: 100Gi
      volumeMode: Filesystem
      accessModes:
        - ReadWriteOnce
      persistentVolumeReclaimPolicy: Delete
      storageClassName: local-storage
      local:
        path: /mnt/disks/ssd1
      nodeAffinity:
        required:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/hostname
                  operator: In
                  values:
                    - example-node
    ```
- You must set a PersistentVolume `nodeAffinity` when using `local` volumes. The kubernetes scheduler uses the PersistentVolume `nodeAffinity` to schedule these Pods to the correct node.
- PersistentVolume `volumeMode` can be set to "Block" (instead of default value "FileSystem") to expose the local volume as a raw block device.

### nfs
- An `nfs` volume allows an existing NFS share to tbe mounted into a Pod. Unlike `emptyDir`, which is erased when a Pod is removed, the contents of an `nfs` volume are preserved and the volume is merely unmounted.
- This means that an NFS volume can be pre-populated with data, and that data can be shared between the pods. NFS can be mounted by multiple writers simultaneously.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          volumeMounts:
            - mountPath: /my-nfs-data
              name: test-volume
      volumes:
        - name: test-volume
          nfs:
            path: /my-nfs-data
            server: my-nfs-server.example.com
            readOnly: true
    ```

### persistentVolumeClaim
- A `PersistentVolumeClaim` volume is used to mount a PersistentVolume into a Pod. PersistentVolumeClaims are a way for users to "claim" durable storage (such as an iSCSI volume) without knowing the details of the particular cloud environment.

### secret
- A Secret volume is used to pass sensitive information, such as passwords to Pods.
- You can store secrets in the Kubernetes API and mount them as files for use by pods without coupling to kubernetes directly.
- Secret volumes are backed by tmpfs (a RAM-backed filesystem) so they are never written to non-volatile storage.

## using subPath
- Sometimes, it is useful to share one volume for multiple users in a single pod. The `volumeMounts[*].subPath` property specifies a sub-path inside the referenced volume instead of its root.
- The following example shows how to configure a Pod with LAMP stack using a single, shared volume. This sample `subPath` configuration is not recommended for production use.
- The PHP application's code and assets map to the volume's `html` directory and the MySQL database is stored in the volume's `mysql` folder. For example:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: my-lamp-site
    spec:
      containers:
        - name: mysql
          image: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: "MYSQL_ROOT_PASSWORD"
                  name: mysql-secret
          volumeMounts:
            - mountPath: /var/lib/mysql
              name: site-data
              subPath: mysql
        - name: php
          image: php:7.0-apache
          volumeMounts:
            - mountPath: /var/www/html
              name: site-data
              subPath: html
      volumes:
        - name: site-data
          persistentVolumeClaim:
            claimName: my-lamp-site-data
    ```