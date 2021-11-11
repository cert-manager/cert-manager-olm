# cert-manager-olm

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


The repository contains two OLM packages in two subdirectories:

* `cert-manager` is the preferred package and is published in the `community-operators` catalogs.
* `cert-manager-oparator` is a legacy package which is published in the RedHat `certified-operators` and `redhat-marketplace` catalogs

## cert-manager (current)

See `cert-manager/README.md`

```sh
make -C cert-manager help
```

## cert-manager-operator (legacy)

See `cert-manager-operator/README.md`

```sh
make -C cert-manager-operator help
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
make crc-instance OPENSHIFT_VERSION=4.9 PULL_SECRET=${HOME}/Downloads/pull-secret
```

This will create a VM and automatically install the chosen version of OpenShift, using a suitable version of `crc`.
The `crc` installation, setup and start are performed by a `startup-script` which is run when the VM boots.
You can monitor the progress of the script as follows:

```sh
gcloud compute instances tail-serial-port-output crc-4-9
```

You can log in to the VM and interact with the cluster as follows:

```sh
gcloud compute ssh crc@crc-4-9 -- -D 8080
sudo journalctl -u google-startup-scripts.service  --output cat
eval $(bin/crc-1.34.0 oc-env)
oc get pods -A
```

### Install cert-manager

Log in to the VM using SSH and enable socks proxy forwarding so that you will be able to connect to the Web UI of `crc` when it starts.
```
gcloud compute ssh crc@crc-4-9 -- -D 8080
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

### Run E2E Tests on crc cluster

Once you have installed cert-manager on the `crc-instance` you can run the cert-manager E2E tests,
to verify that cert-manager has been installed properly and is reconciling Certificates.

First compile the cert-manager E2E test binary as follows:

```sh
cd projects/cert-manager/cert-manager
bazel build //test/e2e:e2e
```

And then upload the binary to the remote VM and run them against cert-manager installed in the crc OpenShift cluster:

```sh
cd projects/cert-manager/cert-manager-olm
make crc-e2e \
  OPENSHIFT_VERSION=4.8 \
  PULL_SECRET=~/Downloads/pull-secret \
  E2E_TEST=../cert-manager/bazel-bin/test/e2e/e2e.test
```

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
gcloud compute ssh crc@crc-4-9 -- -D 8080
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
