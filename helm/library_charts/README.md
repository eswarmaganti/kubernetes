# Helm Library Charts

## Chart
Helm uses a packaging format called *charts*. A chart is a collection of files tht describe a related set of Kubernetes resources. A single chart might be used to deploy something simple, like a memcached pod, or something complex, like a full web app stack with HTTP servers, databases, caches and so on.

Charts are created as files laid out in a particular directory tree. They can be packages into versioned archives to be deployed.

If you want to download and look at the files for a published chart, without installing it, you can do so with `helm pull chartrepo/chartname`. 

### Chart Types
The `type` filed defines the type of chart. There aare two types: `application` and `library`. 
- Application is the default type and is the standard chart with can be operated on fully.
- The library chart provides utilities or functions for the chart builder. A library chart differs from an application chart because it is not installable and usually doesn't contain any resource objects.

> NOTE: An application chart can be ised as aa library chart. This is enabled by setting the type to `library`.  
> The chart will then be rendered as a library chart where all utilities and functions can be leveraged.  
> All resource objects of the chart will not be rendered

## Library Charts
A library chart is a type of helm chart that defines chart primitives or definitions which can be shared by Helm templates in other charts. This allows users to share snippets of code that can be re-used across charts, avoiding repetition and keeping charts DRY.

The library chart was introduced in helm 3 to formally recognize common ot helper charts that have been used by chart maintainers since helm 2. By including it as a chart type, it provides:
- A means to explicitly distinguish between common and application charts
- Logic to prevent installation of common chart
- No rendering of templates in a common chart which may contain release artifacts
- Allow of dependent chart to use the importer's context

A chart maintainer can define a common chart as a library chart and now be confident that Helm will handle the chart in a standard consistent fashion. It also means that definitions in an application chart can be shared by changing the chart type.

## Library chart benefits
Because of the inability to act as standalone charts, library charts can leverage the following functionality:
- The `.Files` object references the file paths on the parent chart, rather than the path local to the library chart.
- The `.Values` object is the same as the parent chart, in contrast to application subcharts which receive the section of values configured under their header in the parent.