# cert-manager packages for OLM

This repository contains scripts and files that are used to package cert-manager for Red Hat's [Operator Lifecycle Manager (OLM)][].
This allows users of OpenShift and OperatorHub to easily install cert-manager into their clusters.
It is currently an experimental deployment method.

[Operator Lifecycle Manager (OLM)]: https://olm.operatorframework.io/
[OpenShift]: https://www.okd.io/
[OperatorHub]: https://operatorhub.io/

The package is called an [Operator Bundle][] and it is a container image that stores the Kubernetes manifests and metadata associated with an operator.
A bundle is meant to represent a specific version of an operator.

The bundles are indexed in a [Catalog Image][] which is pulled by OLM in the Kubernetes cluster.
Clients such as `kubectl operator` then interact with the [OLM CRDs][] to "subscribe" to a particular release channel.
OLM will then install the newest cert-manager bundle in that release channel and perform upgrades as newer versions are added to that release channel.

[Operator Bundle]: https://github.com/operator-framework/operator-registry/blob/master/docs/design/operator-bundle.md
[OLM CRDs]: https://olm.operatorframework.io/docs/concepts/crds/

## Installing

The simplest way to install cert-manager via OLM is to use the `kubectl operator` plugin, as follows:

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



Wait for the CSV to be created:

```
$ kubectl -n operators get clusterserviceversion -o wide
NAME                  DISPLAY        VERSION   REPLACES   PHASE
cert-manager.v1.3.1   cert-manager   1.3.1                Installing
```

Monitor events as OLM installs cert-manager 1.3.1

```
$ kubectl -n operators get events -w
LAST SEEN   TYPE     REASON                OBJECT                                      MESSAGE
0s          Normal   RequirementsUnknown   clusterserviceversion/cert-manager.v1.3.1   requirements not yet checked
0s          Normal   RequirementsNotMet    clusterserviceversion/cert-manager.v1.3.1   one or more requirements couldn't be found
0s          Normal   AllRequirementsMet    clusterserviceversion/cert-manager.v1.3.1   all requirements found, attempting install
0s          Normal   AllRequirementsMet    clusterserviceversion/cert-manager.v1.3.1   all requirements found, attempting install
0s          Normal   ScalingReplicaSet     deployment/cert-manager                     Scaled up replica set cert-manager-74d7f9dff to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-74d7f9dff           Created pod: cert-manager-74d7f9dff-72g4t
0s          Normal   Scheduled             pod/cert-manager-74d7f9dff-72g4t            Successfully assigned operators/cert-manager-74d7f9dff-72g4t to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-74d7f9dff-72g4t            Pulling image "quay.io/jetstack/cert-manager-controller:v1.3.1"
0s          Normal   ScalingReplicaSet     deployment/cert-manager-cainjector          Scaled up replica set cert-manager-cainjector-bffcd79d7 to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-cainjector-bffcd79d7   Created pod: cert-manager-cainjector-bffcd79d7-h29qc
0s          Normal   Scheduled             pod/cert-manager-cainjector-bffcd79d7-h29qc    Successfully assigned operators/cert-manager-cainjector-bffcd79d7-h29qc to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-cainjector-bffcd79d7-h29qc    Pulling image "quay.io/jetstack/cert-manager-cainjector:v1.3.1"
0s          Normal   ScalingReplicaSet     deployment/cert-manager-webhook                Scaled up replica set cert-manager-webhook-649f87bd5b to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-webhook-649f87bd5b     Created pod: cert-manager-webhook-649f87bd5b-7swpk
0s          Normal   Scheduled             pod/cert-manager-webhook-649f87bd5b-7swpk      Successfully assigned operators/cert-manager-webhook-649f87bd5b-7swpk to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-webhook-649f87bd5b-7swpk      Pulling image "quay.io/jetstack/cert-manager-webhook:v1.3.1"
0s          Normal   InstallSucceeded      clusterserviceversion/cert-manager.v1.3.1      waiting for install components to report healthy
0s          Normal   InstallWaiting        clusterserviceversion/cert-manager.v1.3.1      installing: waiting for deployment cert-manager to become ready: deployment "cert-manager" not available: Deployment does not have minimum availability.

```


Watch OLM then upgrade to cert-manager 1.4.0
```
0s          Normal   InstallSucceeded      clusterserviceversion/cert-manager.v1.3.1      install strategy completed with no errors
0s          Normal   RequirementsUnknown   clusterserviceversion/cert-manager.v1.4.0      requirements not yet checked
0s          Normal   RequirementsNotMet    clusterserviceversion/cert-manager.v1.4.0      one or more requirements couldn't be found
0s          Normal   BeingReplaced         clusterserviceversion/cert-manager.v1.3.1      being replaced by csv: cert-manager.v1.4.0
0s          Normal   AllRequirementsMet    clusterserviceversion/cert-manager.v1.4.0      all requirements found, attempting install
0s          Normal   ScalingReplicaSet     deployment/cert-manager                        Scaled up replica set cert-manager-69f886dcd to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-69f886dcd              Created pod: cert-manager-69f886dcd-glqrw
0s          Normal   Scheduled             pod/cert-manager-69f886dcd-glqrw               Successfully assigned operators/cert-manager-69f886dcd-glqrw to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-69f886dcd-glqrw               Pulling image "quay.io/jetstack/cert-manager-controller:v1.4.0"
0s          Normal   ScalingReplicaSet     deployment/cert-manager-cainjector             Scaled up replica set cert-manager-cainjector-54669f6494 to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-cainjector-54669f6494   Created pod: cert-manager-cainjector-54669f6494-4qjjn
0s          Normal   Scheduled             pod/cert-manager-cainjector-54669f6494-4qjjn    Successfully assigned operators/cert-manager-cainjector-54669f6494-4qjjn to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-cainjector-54669f6494-4qjjn    Pulling image "quay.io/jetstack/cert-manager-cainjector:v1.4.0"
0s          Normal   ScalingReplicaSet     deployment/cert-manager-webhook                 Scaled up replica set cert-manager-webhook-7bb69c56f7 to 1
0s          Normal   SuccessfulCreate      replicaset/cert-manager-webhook-7bb69c56f7      Created pod: cert-manager-webhook-7bb69c56f7-9vbr8
0s          Normal   Scheduled             pod/cert-manager-webhook-7bb69c56f7-9vbr8       Successfully assigned operators/cert-manager-webhook-7bb69c56f7-9vbr8 to cert-manager-olm-control-plane
0s          Normal   Pulling               pod/cert-manager-webhook-7bb69c56f7-9vbr8       Pulling image "quay.io/jetstack/cert-manager-webhook:v1.4.0"
0s          Normal   InstallSucceeded      clusterserviceversion/cert-manager.v1.4.0       waiting for install components to report healthy
1s          Normal   InstallWaiting        clusterserviceversion/cert-manager.v1.4.0       installing: waiting for deployment cert-manager to become ready: deployment "cert-manager" waiting for 1 outdated replica(s) to be terminated
0s          Normal   Pulled                pod/cert-manager-69f886dcd-glqrw                Successfully pulled image "quay.io/jetstack/cert-manager-controller:v1.4.0" in 29.231317695s
0s          Normal   Created               pod/cert-manager-69f886dcd-glqrw                Created container cert-manager
0s          Normal   Started               pod/cert-manager-69f886dcd-glqrw                Started container cert-manager
0s          Normal   ScalingReplicaSet     deployment/cert-manager                         Scaled down replica set cert-manager-74d7f9dff to 0
0s          Normal   SuccessfulDelete      replicaset/cert-manager-74d7f9dff               Deleted pod: cert-manager-74d7f9dff-72g4t
0s          Normal   Killing               pod/cert-manager-74d7f9dff-72g4t                Stopping container cert-manager
0s          Normal   InstallWaiting        clusterserviceversion/cert-manager.v1.4.0       installing: waiting for deployment cert-manager-cainjector to become ready: deployment "cert-manager-cainjector" waiting for 1 outdated replica(s) to be terminated

```

Run some of the cert-manager E2E conformance tests:

```
$ ./devel/run-e2e.sh --ginkgo.focus '[Conformance].*SelfSigned Issuer'
...
```

## Legacy bundles

This includes the operator itself, based on the Helm operator as well as Dockerfiles to build [UBI](https://connect.redhat.com/about/faq/what-red-hat-universal-base-image-ubi-0) based images.

This repository contains all files that are used by the RedHat image builder to release the operator.

For more info on cert-manager, please see [the cert-manager repository](https://github.com/jetstack/cert-manager) or [cert-manager.io](https://cert-manager.io)
