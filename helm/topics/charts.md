# Charts
Helm uses a packaging format called *charts*. A chart is a collection of files that describe a related set of Kubernetes resources. A single chart might be used to deploy something simple, like  memcached pod, or something complex, like a full web aapp with HTTP servers, databases, caches and so on.

Charts are created as files laid out in a particular directory tree. They can be packaged into versioned archives to be deployed.

If you want to download and look at the files for a published chart, without installing it, you can do so with `helm pull chartrepo/chartname`.


## The chart file structure
A chart is organized as a collection of files inside of a directory. The directory name is the name of the chart (without versioning information). Thus, a chart describing WordPress would be stored in a `wordpress/` directory.

Inside of this directory, helm will except a structure that matches this:

```
wordpress/
    Chart.yaml          # A YAML file containing information about the chart
    LICENSE             # Optional: A plain text file containing the license for the chart
    README.md           # Optional: A human-readable README file
    values.yaml         # The default configuration values for this chart
    values.schema.json  # Optional: A JSON schema for imposing a structure on the values.yaml 
    charts/             # A directory containing any charts uponm which this chart depends.
    crds/               # Custom Resource Definitions
    templates/          # A directory of templates that, when combined with values,
                        # will generate valid Kubernetes manifest files.
    templates/NOTES.txt # Optional: A plain text file containing short usage notes 
```

## The `Chart.yaml` file
The `Chart.yaml` file is required for a chart. It contains the following fields:

```yaml
apiVersion: The chart API version (required)
name: The name of the chart (required)
version: The version of the chart (required)
kubeVersion: A SemVer range of compatible Kubernetes versions (optional)
description: A single-sentence description of this project (optional)
type: The type of the chart (optional)
keywords:
  - A list of keywords about this project (optional)
home: The URL of this project home page (optional)
sources: 
  - A list of URLs to source code of this project (optional)
dependencies: # A listy of the chart requirements (optional)
  - name: THe name of the chart (nginx)
    version: The version of the chart ("1.2.3")
    repository: The repository URL (optional)
    condition: A yaml path that resolves to a boolean, used for enabling/disabling charts (optional)
    tags: # (optional)
      - Tags can be used to group charts for enabling/disabling together
    import-values: # (optional)
      - ImportValues hold the mapping og source values to parent key to be imported. Each item can ve a string or child/parent sublist items.
    alias: (optional) Alias to be used for the chart. Useful when you want to add the same chart multiple times.
maintainers: # (optional)
  - name: The maintainers name (required for each maintainer)
    email: THe maintainers email (optional for each maintainer)
    url: A URL for the maintainer (optional for each maintainer)
icon: A URL to an SVG or PNG image to be used as an icon (optional)
appVersion: The version of the app that this contains (optional). Needn't be SemVer. Quotes recommended.
deprecated: Whether this chart is deprecated (optional, boolean)
annotations:
  example: A list of annotations keyed by name (optional)
```

### Charts and Versioning
Every chart must have a version number. A version should follow the SemVer2 standard but it is not strictly enforced. Unlike Helm Classic, Helm v2 and later uses version number as release markers. Packages in repositories are identified by name plus version.

For example, an `nginx` chart whose version filed is set to `version: 1.2.3` will be named:
`nginx-1.2.3.tgz`

The `version` filed inside the `Chart.yaml` is used by many of the Helm tools. including the CLI. When generating a package, the `helm package` command will use the version that it finds in the `Chart.yaml` as a token in the package name. The system assumes that the version number in the chart package name matches the version number in the `Chart.yaml`. Failure to meet this assumption will cause an error. 

### The `apiVersion` Field
The `apiVersion` filed should be `v2` for Helm charts that require at least Helm 3. Charts supporting previous Helm versions have an `apiVersion` set to `v1` and are still installable by Helm 3.

Changes from `v1` to `v2`
- A `dependencies` filed defining chart dependencies, which were located in a separate `requirements.txt` file for `v1` charts
- The `type` filed, discriminating application and library charts.

### The `appVersion` Field
Note that the `appVersion` filed is not related to the `version` field. It is a way of specifying the version of the application.

For example, the `drupal` chart may have an `appVersion: "8.2.1"`, including that the version of Drupal included in the chart (by default) is `8.2.1`. This field is informational, and has no impact on chart version calculations.

### The `kubeVersion` Filed
The optional `kubeVersion` filed can define semver constraints on supported Kubernetes versions. Helm will validate the version constraints when installing the chart and fail if the cluster runs an unsupported Kubernetes version.

Version constraints may comprise space separated AND comparisons such as `>= 1.13.0 < 1.15.0`

Which themselves can be combined with the OR `||` operator `>= 1.13.0 < 1.14.0 || >= 1.14.1 < 1.15.0`


### Deprecating Charts
When managing charts in a Chart Repository, it is sometimes necessary to deprecate a chart. The optional `deprecated` filed in `Chart.yaml` can be used to mark a chart as deprecated.

If the *latest* version of a chart in the repository is marked as deprecated, then the chart as a whole is considered to be deprecated. The chart name can be later reused by publishing a newer version that is not marked as deprecated. The workflow for deprecating charts is:

1. Update chart's `Chart.yaml` to mark the chart as deprecated, bumping the version
2. Release the new chart version in the Chart Repository
3. Remove the chart from the source repository

---

## Chart LICENSE, README and NOTES
Charts can also contain files that describe the installation, configuration, usage and license of a chart.

A LICENSE is a plain text file containing the license for the chart. The chart can contain a license as it may have programming logic in the templates and would therefore not be configuration only. There can also be separate license(s) for the application installed by the chart, if required.

A README for a chart should be formatted in Markdown, and should generally contain:
- A description of the application or service the chart provides
- Any prerequisites or requirements to run the chart
- Descriptions of options in `values.yaml` and default values
- Any other information that may be relevant to the installation or configuration of the chart.

The chart also contain a short plain text `templates/NOTES.txt` file that will be printed out after installation, and when viewing the status of a release. This file is evaluated as a template, and can be used to display usage notes, next steps, or any other information relevant to a release of the chart.

---

## Chart Dependencies
In Helm, one chart may depend on any number of other charts. The dependencies can be dynamically linked using the `dependencies` filed in `Chart.yaml` or brought in to the `charts/` directory and managed manually.

### Managing dependencies with the `dependencies` filed
The charts required by the current chart are defined as a list in the `dependencies` filed.

```yaml
dependencies:
  - name: apache
    version: 1.2.3
    repository: https://example.com/charts
  - name: mysql
    version: 3.2.1
    repository: https://another-example.com/charts
```
- The `name` field is the name of the chart you want
- The `version` field is the version of the chart you want
- The `repository` field is the fully URL to the chart repository. Note that you must also use `helm repo add` to add the that repo locally.
- You might use the name of the repo instead of URL

`$ helm repo add fantastic-charts https://charts.helm.sh/incubator`

```yaml
dependencies:
  - name: awesomeness
    version: 1.0.0
    repository: "@fantastic-charts"
```

Once you have defined dependencies, you can run `helm dependency update` and it will use your dependency file to download all the specified charts into your `charts/` directory.

#### Tags and Condition fields in dependencies
All charts are loaded by default. If `tags` or `condition` fields are present, they will be evaluated and used to control loading for the chart(s) they are applied to.

**condition** - it folds one or more YAML paths (delimited by commas). If this path exists in the top parent's values and resolves to a boolean value, the chart will be enabled or disabled based on that boolean value. Only the first valid path in the list is evaluated and if no paths exist then the condition has no effect.

**tags** - it is a YAML list of labels to associate with this chart. In the top parent's values, all charts with tags can be enabled or disabled by specifying the tag and a boolean value.

```yaml
# parentchart/Chart.yaml

dependencies:
  - name: subchart1
    repository: https://eample.com/charts
    version: 0.1.0
    condition: subchart1.enabled,global.subchart1.enabled
    tags:
      - front-end
      - subchart1
  - name: subchart2
    repository: https://eample.com/charts
    version: 0.1.0
    condition: subchart2.enabled,global.subchart2.enabled
    tags:
      - back-end
      - subchart2
```

##### Using the CLI with Tags and Conditions
The `--set` parameter can be used as usual to alter tags and condition values

`helm install --set tags.front-end=true --set subchart2.enabled=false`

##### Tags and Condition Resolution
- **Conditions (when set in values) always override tags. The first condition path that exists wins and subsequent ones for that chart are ignored.
- Tags are evaluated as 'if any of the chart's tags are true then enable the chart'.
- Tags and conditions values must be set in th top parent's values.
- The `tags:` key in values must be a top level key. Global and nested `tags:` tables are not currently supported

#### Importing child values via dependencies
In some cases it is desirable to allow a child chart's values to propagate to the parent chart and be shared as common defaults. An additional benefit of using the `exports` format is that it will enable future tooling to introspect user-settable values.

The keys containing the values to be imported  can be specified in the parent chart's `dependencies` in the filed `import-values` using a YAML list. Each item in the list is a key which is imported from the child chart's `exports` field.

To import values not contained in the `exports` key, use the child-parent format.

##### Using the exports format
If a child chart's `values.yaml` file contains an `exports` filed at the root, its content may be imported directly into the parent's values by specifying the keys to import as in the example below:

```yaml
# parent's Chart.yaml

dependencies:
  - name: subchart
    repository: http://localhost:10191
    version: 0.1.0
    import-values:
      - data
```

```yaml
# child's values.yaml file
exports:
  data:
    myint: 99
```

Since we are specifying the key `data` in our import list, Helm looks in the `exports` filed of the child chart for `data` key and imports its contents.

The final parent values would contain our exported filed:
```yaml
# parent's values
myint: 99
```
> Please note th parent key `data` is not contained in the parent's final values. If you need to specify the parent key, use the 'child-parent' format


##### Using the child-parent format
To access values that are not contained in the `exports` key of the child's values, you will need to specify the source key of the values to be imported and the destination path in the parent chart's values

```yaml
# Parent's Chart.yaml

dependencies:
  - name: subchart`
    repository: http://localhost:10191
    version: 0.1.0
    import-values:
      - child: default.data
        parent: myimports
```

In the above example, values found at `default.data` in the *subchart1* values will be imported to the `myimports` key in the parent chart's values as detailed below:

```yaml
# parent's values.yaml file

myimports:
  myint: 0
  mybool: false
  mystring: "helm rocks!"
```

```yaml
# subchart1's values.yaml file
default:
  data:
    myint: 999
    mybool: true
```

The parent chart's resulting values would be:
```yaml
myimports:
  myint: 999
  mybool: true
  mystring: "helm rocks!"
```

### Managing dependencies manually via the `charts/` directory

If more control over dependencies is desired, these dependencies can be expressed explicitly by copying the dependency charts into the `charts/` directory.

A dependency should be an unpacked chart directory but its name cannot start with `_` or `.`. Such files are ignored by the chart loader.

For example, if the WordPress chart depends on the Apache chart, the Apache chart is supplied in the WordPress chart's `charts/` directory.

```yaml
wordpress:
  Chart.yaml
  # ....
  charts/
    apache/
      Chart.yaml
      # ...
    mysql/
      Chart.yaml
      # ...
```

> To drop the dependencies into your `charts/` directory, use the `helm pull` command.


### Operational aspects of using dependencies
The above sections explain how to specify chart dependencies, but how does this affect chart installation using `helm install` and `helm upgrade`?

Suppose that a chart named "A" creates the following Kubernetes objects
- namespace "A-Namespace"
- statefulset "A-StatefulSet"
- service "A-Service"

Furthermore, A is depend on chart B that creates objects
- namespace "B-namespace"
- replicaset "B-ReplicaSet"
- service "B-Service"


After installation/upgrade of chart-A a single helm release is created/mofified. The release will create/update all of the above Kubernetes objects on the following order:
- A-Namespace
- B-Namespace
- A-Service
- B-Service
- B-ReplicaSet
- A-StatefulSet

This is because when Helm installs/upgrades charts, the Kubernetes objects from the charts and all its dependencies are
- aggregated into a single set; then
- sorted by type followed by name; and then
- created/updated in that order.

Hence, single release is created with all the objects for the chart and its dependencies

---

## Templates and Values
Helm Chart templates are written in the Go template language, with the addition of 50 or so add-on template functions from Sprig library and a few other specialized functions.

All template files are stored in a chart's `templates/` folder. When Helm renders the charts, it will pass every file in that directory through the template engine.

Values for the templates are supplied two ways:
- Chart developers may supply a file called `values.yaml` inside of a chart. This file can contain default values.
- Chart users may supply a YAML file that contains values. This can be provided on the command line with `helm install`

When a user supplies custom values, these values will override the values in the chart's `values.yaml` file


### Template Files
Template files follow the standard conventions for writing Go templates. An example template file might look something like this

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "nginx.fullname" . }}
  namespace: development
  labels:
    {{- include "nginx.labels" . | nindent 4}}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ include "nginx.servicePortName" }}
      protocol: TCP
      name: {{ include "nginx.servicePortName" . }}
  selector:
    {{- include "nginx.selectorLabels" . | nindent 4 }}
```

### Predefined Values
Values are supplied via a `values.yaml` file (or via the `--set` flag) are accessible from the `.Values` object in a template. But there are other pre-defined pieces of data you can access in your templates.

The following values are pre-defined, are available to every template, and cannot be overridden . As with all values, the names are case-sensitive.

- `Release.Name`: The name of the release
- `Release.Namespace`: The namespace the chart was released to
- `Release.Service`: The service that conducted the release
- `Release.IsUpgrade`: This is set to true if the current operation is an upgrade or rollback
- `Release.IsInstall`: This is set to true if the current operation is an install.
- `Chart`: The contents of the `Chart.yaml`. Thus, the chart version is obtainable as `Chart.Version`.
- `Files`: A map-like object containing all non-special files in the chart. This will not give you access to templates, but will give you access to additional files that are present.
- `Capabilities`: A map like object that contains information about the versions of Kubernetes ( `{{ .Capabilities.KubeVersion }}`) and the supported Kubernetes API versions (`{{ .Capabilities.APIVersions.Has "batch/v1"}}`)


### Values Files
Considering the template in the previous section, a `values.yaml` file that supplies the necessary values would look like this:
```yaml
imageRegistry: "docker.io"
dockerTag: "latest"
pullPolicy: "Always"
```

A values file is formatted in YAML. A chart may include a default `values.yaml` file. The helm install command allows a user to override values by supplying additional YAML files.
`$ helm install --generate-name --values=values.yaml wordpress`

When values are passed this way, they will be merged into the default values file. For example, consider a `myvalues.yaml` file that looks like
```yaml
imageRegistry: ghcr.io
```

When this is merged with the `values.yaml` in the chart, the resulting generated content will be
```yaml
imageRegistry: "ghcr.io"
dockerTag: "latest"
pullPolicy: "Always"
```

> NOTE: If the `--set` flag us used on `helm install/upgrade`, those values are simply converted to YAML on the client side.

### Scope, Dependencies, and Values
Values file can declare values for the top-level chart, as well as for any of the charts that are included in that chart's `charts/` directory (charts defined under dependencies).

For example, the demonstration WordPress chart above have both `mysql` and `apache` as dependencies. The values file could supply values to all of these components:

```yaml
title: "My Wordpress Site" # Sent to the wordpress template

mysql: # sent to MySQL
  max_connections: 100

apache: # sent to Apache
  port: 8080
```

Charts at a higher level have access to all the variables defines beneath. So the WordPress chart can access the MySQL password as `.Values.mysql.password`. But lower level charts cannot access things in parent charts, so MySQL will not be able to access the `title` property.

Values are namespaced, but namespaces are pruned. So for the WordPress chart, it can access the MySQL password field as `.Values.mysql.password`. But for the MySQL chart, the scope of the values has been reduced and the namespace prefix removed, so it will see the password filed simply as `.Values.password`.

#### Global Values
As of 2.0.0-Alpha.2, Helm supports special "global" value. Consider this modified version of the previous example:

```yaml
title: "My WordPress site" # Sent to the wordpress template

global:
  app: "MyWordPress"

mysql:
  max_connections: 100
  password: "secret"

apache:
  port: 8080
```

The above adds a `global` section with the value `app: MyWordPress`. This value is available to *all* charts as `.Values.global.app`

For example, the `mysql` templates may access `app` as `{{ .Values.global.app }}` and so can the apache chart. Effectively the values file above is generated like this:

```yaml
title: "My WordPress site" # Sent to the wordpress template

global:
  app: "MyWordPress"

mysql:
  global:
    app: "MyWordPress"
  max_connections: 100
  password: "secret"

apache:
  global:
    app: "MyWordPress"
  port: 8080
```

This provides a way of sharing one top-level variable with all subcharts, which is useful for things like setting `metadata` properties like labels

If a subchart declares a global variable, the global will be passed *downward*, but not *upward* to the parent chart. There is no way for a subchart to influence the values of the parent chart.

Also, global variables of parent charts take precedence over the global variables from subcharts.

---
## Custom Resource Definitions (CRDs)
Kubernetes provides a mechanism for declaring new type of Kubernetes objects. Using CustomResourceDefinitions (CRDs), Kubernetes developers can declare custom resource types.

In Helm 3, CRDs are treated as a special kind of objects. They are installed before the rest of the chart, and are subject to some limitations.

CRD YAML files should be placed in the `crds/` directory inside a chart. Multiple CRDs may be placed in the same file. Helm will attempt to load *all* the files in the CRD directory into Kubernetes.

> NOTE: CRDs can not be templated. They must be plain YAML documents

When Helm installs a new chart, it will upload the CRDs, pause until the CRDs are made available by the API server, and then start the template engine, render the rest of the chart, and upload it to Kubernetes.

Because of this ordering, CRD information is available in the `.Capabilities` object in Helm templates, and Helm templates may create new instances of objects that were declared in CRDs.

### Limitations on CRDs
Unlike most objects in Kubernetes, CRDs are installed globally. For that reason, Helm takes a very cautious approach in managing CRDs. CRDs are subject to the following limitations:
- CRDs are never reinstalled. If Helm determines that the CRDs in the `crds/` directory are already present (regardless of version), Helm will not attempt to install or upgrade.
- CRDs are never installed on upgrade or rollback. Helm will only create CRDs on installation operations.
- CRDs are never deleted. Deleting a CRD automatically deletes all the CRD's contents across all namespaces in the cluster.