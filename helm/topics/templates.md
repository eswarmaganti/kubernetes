# Helm Template Guide

## Built-in Objects
Objects are passed into template from the template engine. And your code can pass objects around. There are even ways to create new objects within your template.

Objects can be simple, and have just one value. Or they can contain other objects or functions. FOr example, the `Release` object contains several objects and the `Files` object has a few functions.

- `Release`: This object describe the release itself. It has several objects inside of it:
  - `Release.Name`: The release name
  - `Release.Namespace`: The namespace to be released into.
  - `Release.IsUpgrade`: This is set to `true` if the current operation is an upgrade or rollback
  - `Release.IsInstall`: This is set to `true` if the current operation is installed.
  - `Release.Revision`: The revision number for this release. On install, this is 1, and it is incremented with each upgrade and rollback.
  - `Release.Service`: The service that is rendering the present template. On Helm, this is always `Helm`.
- `Values`: Values passed into the template from the `values.yaml` file and from user-supplied files. By default, `Values` is empty.
- `Chart`: The contents of the `Chart.yaml` file. Any data in `Chart.yaml` will be accessible here. For example `{{ Chart.Name }}-{{ Chart.Version }}` will print out the `mychart-0.1.0`.
- `Subcharts`: This provides access to the scope of subcharts to the parent. Ex: `.Subcharts.mysubchart.myValue` to access the `myValue` from `mysubchart` chart
- `Files`: This provides access to all non-special files in a chart. While you cannot user it to access templates, you can use it to access other files in the chart.
  - `Files.Get` is a function for getting a file by name
  - `Files.GetBytes` is a function for getting the contents of a file as an array of bytes instead of a string. This is useful for images.
  - `Files.Glob` is a function that returns a list of files whose names match the given shell glob pattern.
  - `Files.Lines` is a function that reads a file line-by-line. This is useful for iterating over each line in a file.
  - `Files.AsSecret` is a function that returns the file bodies as Base64 encoded strings.
  - `Files.AsConfig` is a function that returns the file bodies as YAML map.
- `Capabilities`: This provides information about what capabilities the Kubernetes cluster supports
  - `Capabilities.APIVersions` is a set of versions.
  - `Capabilities.APIVersions.HAS $version` indicates whether a version is available in cluster.
  - `Capabilities.KubeVersion` and `Capabilities.KubeVersion.Version` is the Kubernetes version
  - `Capabilities.KubeVersion.Major` is the Kubernetes major version.
  - `Capabilities.KubeVersion.Minor` is the Kubernetes minir version.
  - `Capabilities.HelmVersion` is the object containing helm version details
  - `Capabilities.HelmVersion.Version` is the current Helm version in semver format
  - `Capabilities.HelmVersion.GitCommit` is the Helm git sha1
  - `Capabilities.HelmVersion.GitTreeState` is the state of the Helm git tree
  - `Capabilities.HelmVersion.GoVersion` is the version of Go compiler used.
- `Template`: Contains information about the current template that is being executed
  - `Template.Name`: A namespaced file path to the current template
  - `Template.BasePath`: THe namespaced path to the templates directory of the current chart


---

## Values Files
One of the built-in objects is `Values`. This object provides access to values passed into the chart. Its contents come from multiple sources:
- The `values.yaml` file in the chart
- If it is a subchart, the `values.yaml` file of a parent chart
- A values file passed into `helm install/upgrade` with `-f` flag.
- Individual parameters are passed with `--set`

The above list is in order of specificity: `values.yaml` is the default, which can be overridden by a parent chart's `values.yaml`, which can be overridden by a user-supplied values file, which can in turn be overridden by `--set` parameters.

**Example**
```yaml
# values.yaml

favorite:
  drink: coffee
  food: burger
```

```yaml
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
data:
  myvalue: "Hello World"
  drink: {{ .Values.favorite.drink }}
  food: {{ .Values.favorite.food }}
```

### Deleting a default key
If you need to delete a key from default values, you may override the values of the key to be `null`, which case Helm will remove tje key from the overridden values merge.

For example, a chart allows configuring the liveness probe as below
```yaml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  initialDelaySeconds: 120
```

If you try to override the linevessProbe handler to `exec` instead of `httpGet` using the `--set livenessProbe.eec.command=[cat, mychart/CHANGELOG.txt]`, Helm will coalesce the default and overridden keys together, resulting in the following YAML.

```yaml
livenessProbe:
  httpGet:
    path: /user/login
    port: http
  exec:
    command:
      - cat
      - mychart/CHANGELOG.txt
  initialDelaySeconds: 120
```

However, Kubernetes would then fail because you can not declare more than one livenessProbe handler. To overcome this, we can do as below

`helm install mychart --set livenessProbe.exec.command=[cat,mychart/CHANGELOG.txt] --set livenessProbe.httpGet=null`

---

## Template Functions and Pipelines

Sometimes we want to transform the supplied data in a way that makes it more usable to us.

For example:
Let's start with a best practice: When injecting strings from the `.Values` object into the template, we ought to quote these strings. We can do that by calling the `quote` function in the template directive:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ quote .Values.favorite.drink }}
  food: {{ quote .Values.favorite.food }}
```
Template functions follow the syntax `functionName arg1 arg2 ...` In the above snippet, `quote .Values.favorite.drink` calls the `quote` function and passes it a single argument

> Helm has over 60 available functions. Some of them are defined by the Go Template language itself. Most of the others are part of Sprig template library.


### Pipelines
One of the powerful features of the template language is its concept of *pipelines*. Drawing on a concept from UNIX, pipelienes are a tool for chaining toigether a series of template commands to compactly express a series of transformations. In other words, pipelines are an efficient way of getting several things fone in sequence.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ .Values.favorite.drink | quote}}
  food: {{ .Values.favorite.food | quote}}
```
In this example, instead of calling `quote ARGUMENT`, we inverted the order. We "sent" the argument to the function using a pipeline `|`. Using pipelines we can chain several functions together.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ quote .Values.favorite.drink }}
  food: {{ quote .Values.favorite.food | upper | quote }}
```

When pipelining arguments like this, the result of the first evaluation is sent as the *last* argument to the function.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ quote .Values.favorite.drink | repeat 5 | quote }} # => "coffeecoffeecoffeecoffeecoffee"
  food: {{ quote .Values.favorite.food }}
```

### Using the `default` function

One function frequently used in templates is the `default` function: `default DEFAULT_VALUE GIVEN_VALUE`. This function allows you to specify a default value insiode of the template, in case the value is omitted.

```yaml
drink: {{ .Values.favorite.drink | default "tea" | quote }}
```

In an actual chart, all static default values should live in the `values.yaml`, and should not be repeated using the `default` command. However, the `default` command is perfect for computed values, which cannot be declared inside the `values.yaml` file.

```yaml
drink: {{ .Values.favorite.drink | default (printf "%s-tea" (include "fullname" .)) }}
```

Template functions and pipelines are a powerful way to transform information and then insert it into your YAML> But sometimes it's necessary to add some template logic that is little more sophisticated than just inserting a string.

### Using the `lookup` function
The `lookup` function can be used to *look up* resources in a running cluster. THe synopsis of the lookup function is `lookup apiVersion, kind, namespace, name`

Both `name` and `namespace` are optional and can be passed as an empty string. However, if you're working with a namespace-scoped resource, both `name` and `namespace` must be specified

- `kubectl get pods mypod -n myns` => `lookup "v1" "Pod" "myns" "mypod"`
- `kubectl get pods -n myns` => `lookup "v1" "Pod" "myns" ""`
- `kubectl get pods --all-namespaces` => `lookup "v1" "Pod" "" ""`
- `kubectl get namespace myns` => `lookup "v1" "Namespace" "" "myns"`
- `kubectl get namespaces` => `lookup "v1" "Namespace" "" ""`

When lookup returns an object, it will return a dictionary. This dictionary can be further navigated to extract specific values.

The following example will return the annotations present for the `myns` object
`(lookup "v1" "Namespace" "" "myns").metadata.annotations`

When lookup returns a list of objects, it is possible to access the object list via the `items` field:

```yaml
{{ range $index, $service := (lookup "v1" "Services" "myns" "").items }}
        {{ /* do something with each element */ }}
{{ end }}
```

The `lookup` function uses Helm's existing Kubernetes connection configuration to query Kubernetes. If any error is returned when interacting with calling the API server, Helm's template processing will fail.

> To test `lookup` against a running cluster `helm template|install|upgrade|delete|rollback --dry-run=server` should be used to allow cluster connection.

---

## Flow Control

Control structures provide you, the template author, with the ability to control the flow of a template's generation. Helm's template language provides the following control structures:

- `if/else` for creating conditional blocks
- `with` to specify scope
- `range` which provides a "for-each" style loop

In addition to these, it provides a few actions for declaring and using named template segments:
- `define` declares a new named template inside of your template
- `template` imports named template
- `block` declares a special kind of fillable template area

### if/else 

The basic structure of a conditional looks like this
```yaml
{{ if PIPELINE }}
  # Do something
{{ else if OTHER PIPELINE }}
  # Do something else
{{ else }}
  # default
{{ end }}
```

> Note: Control Structures can execute an entire pipeline, not just evaluating a value.

Let's add a simple condition to our ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{ if eq .Values.favorite.drink "coffee" }}
  mug: "true"
  {{ end }}

```

When we run the above template through the Helm template engine, we will get something like below

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: "coffee"
  food: "burger"

  mug: "true"

```

Notice that we received a few empty lines in our YAML, Why?
- When the template engine runs, it removed the contents inside of `{{` and `}}`, but leaves the remaining whitespace exactly as is.

YAML ascribes meaning to whitespace, so managing the whitespace becomes pretty important. Fortunately, Helm templates have a few tools to help.

First, the curly brace syntax of template declarations can be modified with special characters to tell the template engine to chomp whitespace. 
- `{{-` indicates that whitespace should be chomped left.
- `-}}` indicates that whitespace to the right should be consumed

Using this syntax, we can modify our template and get rid of those new lines:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  drink: {{ .Values.favorite.drink | default "tea" | quote }}
  food: {{ .Values.favorite.food | upper | quote }}
  {{- if eq .Values.favorite.drink "coffee" }}
  mug: "true"
  {{- end }}
```

### Modifying scope using `with`

The `with` control structure controls variable scoping. The `.` is a reference to the *current scope*. So `.Values` tells the template to find the `Values` object in the current scope.

The syntax for `with` is
```yaml
{{ with PIPELINE }}
  # restricted scope
{{ end }}
```
Scopes can be changed. `with` can allow you to set the current scope `.` to a particular object. For example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
```

The `with` block only executes if `.Values.favorite` is not empty, so a separate outer `if` guard is not needed.

Notice that now we can reference `.drink` and `.food` without qualifying them. That is because the `with` statement sets `.` to point to `.Values.favorite`. The `.` is reset to its previous scope after `{{- end }}`

> Note: Inside the restricted scope, you will not be able to access the outer objects from the parent scope using `.`, The below example will fail

```
{{- with .Values.favorite }}
drink: {{ .drink | default "tea" | quote }}
food: {{ .food | upper | quote }}
release: {{ .Release.Name }}
{{- end }}
```

It will produce an error because `Release.Name` is not inside the restricted scope for `.`. We can use `$` for accessing the object `Release.Name` from parent scope. `$` is mapped to the roor scope when template execution begins and it doesnot chnage during template execution.

```
{{- with .Values.favorite }}
drink: {{ .drink | default "tea" | quote }}
food: {{ .food | upper | quote }}
release: {{ $.Release.Name }}
{{- end }}
```

### Looping with the `range` action

In Helm's template language, the way to iterate through a collection is to use the `range` operator.

Example

```yaml
favorite:
  food: pizza
  drink: coffee
pizzaToppings:
  - mushrooms
  - cheese
  - onions
  - pineapple
  - chicken
```

Now we have a list of `pizzaToppings`, we can modify our template to print this list in our configMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
  toppings: |-
  {{- range .Values.pizzaToppings}}
  - {{ . | title | quote }}
  {{- end }}
```

The `range` function will iterate through the `pizzaToppings` list. But now something interesting happens. Just like `with` sets the scope of `.`, so does `range` operator. Each time through the loop `.` sets to the current pizza topping.

The `toppings: |-` line is declaring a multi-line string. So our list of toppings is actually not a YAML list, it's a big string.

---

## Variables
In templates, variables are less frequently used. But we will see how to use them to simplify code, and make better use of `with` and `range`.

In Helm templates, a variable is a named reference to another object. It follows the form `$name`. Variables are assigned with a special assignment operator `:=`.

```yaml
apiVersion: v1
kind: ConfigMap
metadata: 
  name: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  {{- $release := .Release.Name }}
  {{- with .Values.favorite  }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  release: {{ $release }}
  {{- end }}

```

Notice that before we start the `with` block, we assign the value of `$release`. Now inside of the `with` block, the release variable still points to the value of `.Release.Name`

Variables are potentially used in `range` loops. They can be used on list-like objects to capture both the index and the value.

```yaml
toppings: |-
  {{- range $index, $topping := .Values.pizzaToppings }}
  {{ $index }}: {{ $topping }}
  {{- end }}
```

For data structures that have both a key and a value, we can use `range` to get both. For example, we can loop through `.Values.favorite` like this:

```yaml
apiVersion: v1
kind: ConfigMap
metadata: 
  name: {{ .Release.Name }}
data:
  myvalue: "Hello World!"
  {{- range $key, $value := .Values.favorite }}
  {{ $key }}: {{ $value }}
  {{- end }}
```

Variables are normally not "global". They are scoped to the block in which they are declared. Earlier, we assigned `$release` in the top level of the template. That variable will be in scope for the entire template. But in our last example, `$key` and `$value` will only be in scope inside of the `range` block.


However, there is one variable that will always point to the root context: `$`. This can be very useful when you are looping in a range and you need to know the chart's release name.

```yaml
{{- range .Values.tlsSecret }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  labels:
    app.kubernetes.io/name: {{ template "fullname" }}
    helm.sh/chart: "{{ $.Chart.Name }}-{{ .Chart.Version }}"
    app.kubernetes.io/instance: "{{ $.Release.Name }}"
    app.kubernetes.io/version: "{{ $.Chart.AppVersion }}"
    app.kubernetes.io/managed-by: "{{ $.Release.Service }}"
type: kubernetes.io/tls
data:
  tls.crt: {{ .certificate }}
  tls.key {{ .key }}
{{- end }}
```

---

## Named Templates

**Template names are global**. If you declare two templates with the same name, whichever one is loaded last will be the one used. Because templates in subcharts are compiled together with top-level templates, you should be careful to name your templates with *chart-specific* names.

### Partials and `_` files
Helm's template language allows you to create named embedded templates, that can be accessed by name else where.

There is a file naming convention for templates,
- Most files in `templates/` are treated as if they contain Kubernetes manifests
- The `NOTES.txt` is in exception
- But files whose name begins with an underscore `_` are assumed to not have a manifest inside. These files are not rendered to Kubernetes object definitions, but are available everywhere within other chart templates for use.

These files are used to store partials and helpers. The `_helpers.tpl` file is the default location for template partials.

### Declaring and using templates with `define` and `template`

The `define` action allows us to create a named template inside of a template file. Its syntax goes like this:

```yaml
{{- define "My.Name" }}
  # body of the template
{{- end }}
```

For example, we can define a template to encapsulate a Kubernetes block of labels

```yaml
{{- define "mychart.labels" }}
labels:
  helm.sh/chart: {{ .Release.Name }}
  app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Now we can embed this template inside of our existing ConfigMap, and then include that with the `template` action:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
  {{- template "mychart.labels" . }}
data:
  myvalue: "Hello World!"
  {{- range $key, $val := .Values.favorite }}
  {{ .key }}: {{ .val }}
  {{- end }}
```

> NOTE: a `define` does not produce output unless it is called with a template, as in this example. 
> Conventionally, Helm charts put these templates inside of a partial file, usually `_helpers.tpl`. 
> By convention, `define` block should have a documentation block `{{ /* ... */ }}` describing what they do. 


### Setting the scope of a template
When we are using any objects in our named template we need to define the scope. When a named template (created with `define`) is rendered. It will receive the scope passed in by the `template` call. In the above example

```
{{- template "mychart.labels" . }}
```

If we missed to pass the scope `.` which is global, the named templates fail to render. We can also pass `.Values` or `.Values.favorite` or whatever scope we want.


---

## The `include` function

Say we've defined a simple template that looks like this:

```yaml
{{- define "mychart.app" }}
app_name: {{ .Chart.Name }}
app_version: {{ .Chart.Version }}
{{- end }}
```

Now, if we want to insert this both in the `labels:` section of the template, and also the `data:` section

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
  labels:
    {{template "mychart.app" . }}
data:
  myvalue: "Hello World!"
{{ template "mychart.app" . }} 
```

If we render the chart, it will fail with some validation errors, If we force the chart to render by disabling the validation 

`helm install --dry-run --disable-openapi-validation myrelease ./mychart`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myrelease
  labels:
    app_name: mychart
  app_version: "0.1.0"
data:
  myvalue: "Hello World!"
app_name: mychart
app_version: "0.1.0"
```

Note that the indentation on `app_version` is wrong in both places. `template` is an action, and not a function, there is no way to pass the output of a `template` call to other functions; the data is simply inserted inline.

To work around ths case, Helm provides an alternative to `template` that will import the contents of a template into the present pipeline where it can be passed along to other functions in the pipeline.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "mychart.app" . | nindent 4 }}
data:
  myvalue: "Hello World!"
  {{- include "mychart.app" . | nindent 2 }}
```


---

## Accessing Files inside Templates

Helm provides access to files through the `.Files` object.
- Some files cannot be accessed through the `.Files` object, usually for security reasons.
  - Files in `/templates` cannot be accessed
  - Files excluded using `.helmignore` cannot be accessed.
  - Files outside of a Helm application subchart, including those of the parent, cannot be accessed.
- Charts do not preserve UNIX mode information, so file-level permissions will have no impact on the availability of a file when it comes to the `.Files` object.

### Basic Example
Let's write a template that reads three files into our ConfigMap. To get started, we will add three files to the chart, putting all three directly inside of the `mychart/` directory.


```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
data:
  {{- $files := .Files }}
  {{- range tuple "config1.toml" "config2.toml" "config3.toml" }}
  {{ . }}: |-
    {{ $file.Get . }}
  {{- end }}
```

Running this template will produce a single ConfigMap with the contents of all three files:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}
data:
  config1.toml: |-
    message = "Hello from config1"
  
  config2.toml: |-
    message = "Hello from config2"
  
  config3.toml: |-
    message = "Hello from config3"
```

### Glob patterns
As your chart grows, you may find you have a greater need to organize your files more, and so we provide a `Files.Glob(pattern string)` method to assist in extracting certain files with all the flexibility of glob patterns.

`.Glob` returns a `Files` type, so you may call any of the `Files` method on the returned object.

For example:
```
foo/:
  foo.txt foo.yaml

bar/:
  bar.go bar.conf baz.yaml
```

You have multiple options with Globs:

```yaml
{{ $currentScope := . }}
{{ range $path, $_ := .Files.Glob "**.yaml" }}
  {{- with $currentScope }}
    {{ .Files.Get $path }}
  {{- end }}
{{ end }}
```

