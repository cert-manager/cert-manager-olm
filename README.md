# cert-manager packages for OLM

Definitions for the cert-manager operator published via Red Hat's [Operator Lifecycle Manager (OLM)][]

[Operator Lifecycle Manager (OLM)]: https://olm.operatorframework.io/

This repository contains all files that are used to package cert-manger for deployment with OLM.
This allows users of OpenShift and OperatorHub to easily install cert-manager into their clusters.
It is currently an experimental deployment method.

[OpenShift]: https://www.okd.io/
[OperatorHub]: https://operatorhub.io/

## Installing

The simplest way to install an operator using OLM is to use the `kubectl operator` plugin, as follows:

```sh
kubectl krew install operator
kubectl operator list-available
kubectl operator install cert-manager -c stable -v 1.3.1 --create-operator-group
```

[kubectl operator plugin]: https://github.com/operator-framework/kubectl-operator

## Release Process

* Add the new version of cert-manager to the `CERT_MANAGER_VERSIONS` list at the top of the `Makefile`
* Run `make catalog-build` to generate / update all the bundle files in `./github.com/operator-framework/community-operators/`
* [Preview the generated clusterserviceversion file on OperatorHub ](https://operatorhub.io/preview)
* Test the generated bundle locally (See testing below)
* Create PRs on the [communit-operators repository][] adding the new or updated bundle files to both `community-operators` and `upstream-community-operators`, as described in the [Where to contribute][] documentation.

[communit-operators repository]: https://github.com/operator-framework/community-operators
[Where to contribute]: https://operator-framework.github.io/community-operators/contributing-where-to/

## Testing

The bundles Docker images and a temporary catalog Docker image can be built and pushed to a personal Docker registry.
These can then be used by OLM running on a Kubernetes cluster.
Run `make bundle-test` to create the bundle and catalog then deploy them with OLM, installed on a local Kind cluster, for testing.

```
make bundle-test
```

## Legacy bundles

This includes the operator itself, based on the Helm operator as well as Dockerfiles to build [UBI](https://connect.redhat.com/about/faq/what-red-hat-universal-base-image-ubi-0) based images.

This repository contains all files that are used by the RedHat image builder to release the operator.

For more info on cert-manager, please see [the cert-manager repository](https://github.com/jetstack/cert-manager) or [cert-manager.io](https://cert-manager.io)
