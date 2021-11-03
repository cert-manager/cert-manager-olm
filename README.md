# cert-manager packages for OLM

This repository contains scripts and files that are used to package cert-manager for Red Hat's [Operator Lifecycle Manager (OLM)][].
This allows users of [OpenShift][] and [OperatorHub][] to easily install cert-manager into their clusters.
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
[Catalog Image]: https://olm.operatorframework.io/docs/glossary/#index

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
* Create a PR on the [Kubernetes Community Operators Repository][], adding the new or updated bundle files to the `operators/cert-manager` directory.
* Create a PR on the [OpenShift Community Operators Repository][], adding the new or updated bundle files to the `operators/cert-manager` directory.

[Kubernetes Community Operators Repository]: https://github.com/k8s-operatorhub/community-operators
[OpenShift Community Operators Repository]: https://github.com/redhat-openshift-ecosystem/community-operators-prod
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

## Testing on OpenShift

There are a few ways to create an OpenShift cluster for testing.
Here we will describe using `crc` ([code-ready-containers][crc]) to install a single node local OpenShift cluster.
Alternatives are:

* [Initializing Red Hat OpenShift Service on AWS using `rosa`][rosa]: known to work but takes ~45min to create a multi-node OpenShift cluster.
* [Install OpenShift on any cloud using OpenShift Installer][openshift-installer]: did not work on GCP at time of writing due to
  [Installer can't get managedZones while service account and gcloud cli can on GCP #5300][openshift-installer-issue-5300].

[`crc` requires: 4 virtual CPUs (vCPUs), 9 GiB of free memory, 35 GiB of storage space][crc-minimum-system-requirements]
but for [crc-v1.34.0][], this is insufficient and you will need 8 CPUs and 32GiB,
which is more than is available on most laptops.

### Automatically create a VM with crc installed

Download your pull secret from the [crc-download] page and supply the path in the command line below:

```sh
make -f hack/crc.mk crc-instance OPENSHIFT_VERSION=4.9 PULL_SECRET=~/Downloads/pull-secret
```

This will create a VM and automatically install the chosen version of OpenShift, using a suitable version of `crc`.
The `crc` installation, setup and start are performed by a `startup-script` which is run when the VM boots.
You can monitor the progress of the script as follows:

```sh
gcloud compute instances tail-serial-port-output crc-4-9
```

You can log in to the VM and interact with the cluster as follows:

```sh
gcloud compute ssh crc-4-9 -- -D 8080
sudo journalctl -u google-startup-scripts.service  --output cat
sudo -u crc -i
eval $(bin/crc-1.34.0 oc-env)
oc get pods -A
```

### Install cert-manager

Log in to the VM using SSH and enable socks proxy forwarding so that you will be able to connect to the Web UI of `crc` when it starts.
```
gcloud compute ssh crc-4-9 -- -D 8080
```

Now configure your web browser to use the socks5 proxy at `localhost:8080`.
Also configure it to use the socks proxy for DNS requests.

With this configuration you should now be able to visit the OpenShift web console page:

https://console-openshift-console.apps-crc.testing

You will be presented with a couple of "bad SSL certificate" error pages,
because the web console is using self-signed TLS certificiates.
Click "Acccept and proceed anyway".

Now click the "Operators > OperatorHub" link on the left hand menu.

Search for "cert-manager" and click the "community" entry and then click "install".

### Manual Creation of a `crc` VM

If you can't use the automated script to create the `crc` VM
you can create one manually, as follows.

#### Create a host machine

Create a powerful cloud VM on which to run `crc`, as follows:

```sh
GOOGLE_CLOUD_PROJECT_ID=$(gcloud config get-value project)
gcloud compute instances create crc-4-9 \
    --enable-nested-virtualization \
    --min-cpu-platform="Intel Haswell" \
    --custom-memory 32GiB \
    --custom-cpu 8 \
    --image-family=rhel-8 \
    --image-project=rhel-cloud \
    --boot-disk-size=200GiB \
    --boot-disk-type=pd-ssd
```

NOTE: The VM must support nested-virtualization because `crc` creates another VM using `libvirt`.

#### Create a `crc` cluster

Now log in to the VM using SSH and enable socks proxy forwarding so that you will be able to connect to the Web UI of `crc` when it starts.
```
gcloud compute ssh crc-4-9 -- -D 8080
```

[Download `crc` and get a pull secret][crc-download] from the RedHat Console.
The latest version of `crc` will install the latest version of OpenShift (4.9 at time of writing).
If you want to test on an older version of OpenShift you will need to download an older version of `crc` which corresponds to the target OpenShift version.

Download the archive, extract it and move the `crc` binary to your system path:

```
curl -SLO https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/1.34.0/crc-linux-amd64.tar.xz
tar xf crc-linux-amd64.tar.xz
sudo mv crc-linux-1.34.0-amd64/crc /usr/local/bin/
```

Run `crc setup` to prepare the system for running the `crc` VM:

```
crc setup

...
INFO Uncompressing crc_libvirt_4.9.0.crcbundle
crc.qcow2: 11.50 GiB / 11.50 GiB [---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------] 100.00%
oc: 117.16 MiB / 117.16 MiB [--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------] 100.00%
Your system is correctly setup for using CodeReady Containers, you can now run 'crc start' to start the OpenShift cluster
```

Run `crc start` to create the VM and start OpenShift

(Paste in the pull secret which you can copy from the [crc-download] page when prompted)

```
crc start

...
CodeReady Containers requires a pull secret to download content from Red Hat.
You can copy it from the Pull Secret section of https://cloud.redhat.com/openshift/create/local.
? Please enter the pull secret

...

Started the OpenShift cluster.

The server is accessible via web console at:
  https://console-openshift-console.apps-crc.testing

Log in as administrator:
  Username: kubeadmin
  Password: ******

Log in as user:
  Username: developer
  Password: *******

Use the 'oc' command line interface:
  $ eval $(crc oc-env)
  $ oc login -u developer https://api.crc.testing:6443
```

[crc]: https://developers.redhat.com/products/codeready-containers/overview
[rosa]: https://docs.openshift.com/rosa/rosa_cli/rosa-get-started-cli.html
[openshift-installer]: https://github.com/openshift/installer/
[openshift-installer-issue-5300]: https://github.com/openshift/installer/issues/5300#issuecomment-953937892
[crc-download]: https://console.redhat.com/openshift/create/local
[crc-minimum-system-requirements]: https://access.redhat.com/documentation/en-us/red_hat_codeready_containers/1.24/html/release_notes_and_known_issues/minimum-system-requirements_rn-ki
[crc-v1.34.0]: https://github.com/code-ready/crc/releases/tag/v1.34.0
