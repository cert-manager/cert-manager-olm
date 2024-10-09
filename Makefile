MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL: help
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:

# Change these values for each cert-manager release
#
# CERT_MANAGER_VERSION is the version of cert-manager for which Kubernetes
# manifests will be downloaded and bundled.
#
# BUNDLE_VERSION is the version assigned to the OLM bundle.
# * Add a pre-release suffix such as `-rc1` and publish the bundle on
#   community-operators and community-operators-prod, if you want to publish the
#   package only to the candidate release channel,
#   for pre-release testing on OpenShift OperatorHub or using operatorhub.io
# * Remove the pre-release suffix and republish when the testing is complete and
#   successful.
#
# See README.md#Release Process for more details.
CERT_MANAGER_VERSION ?= 1.16.1
export BUNDLE_VERSION ?= $(CERT_MANAGER_VERSION)


# BUNDLE_CHANNELS determines which of the OLM release channels this bundle will be assigned to.
# * if the BUNDLE_VERSION has a pre-release suffix such as `-rc1` this should be `candidate`.
# * else this should be `stable candidate`.
BUNDLE_CHANNELS := stable candidate
# STABLE_CHANNEL is the default channel for the bundle. It should be the first of the BUNDLE_CHANNELS,
STABLE_CHANNEL := stable

# These variables are used for local testing only and it should not be necessary
# to override them.
CATALOG_VERSION_DEFAULT := $(shell git describe --tags --always --dirty)
CATALOG_VERSION ?= $(CATALOG_VERSION_DEFAULT)
OPERATORHUB_CATALOG_IMAGE ?= quay.io/operatorhubio/catalog:latest

# from https://suva.sh/posts/well-documented-makefiles/
.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

OLM_PACKAGE_NAME ?= cert-manager
IMG_BASE_DEFAULT := ttl.sh/$(shell uuidgen | tr A-Z a-z)/cert-manager
IMG_BASE ?= $(IMG_BASE_DEFAULT)
BUNDLE_IMG_BASE ?= ${IMG_BASE}-olm-bundle
BUNDLE_IMG ?= ${BUNDLE_IMG_BASE}:${BUNDLE_VERSION}
CATALOG_IMG ?= ${IMG_BASE}-olm-catalogue:${CATALOG_VERSION}
E2E_CLUSTER_NAME ?= cert-manager-olm
CERT_MANAGER_LOGO_URL ?= https://github.com/cert-manager/website/raw/3998bef91af7266c69f051a2f879be45eb0b3bbb/static/favicons/favicon-256.png

KUSTOMIZE_VERSION ?= 5.3.0
KIND_VERSION ?= 0.21.0
OPERATOR_SDK_VERSION ?= 1.33.0
OPM_VERSION ?= 1.36.0
CMCTL_VERSION ?= 2.0.0

comma := ,
empty :=
space := $(empty) $(empty)

bin := bin
os := $(shell go env GOOS)
arch := $(shell go env GOARCH)

kustomize = ${bin}/kustomize-${KUSTOMIZE_VERSION}
kind = ${bin}/kind-${KIND_VERSION}
operator_sdk = ${bin}/operator-sdk-${OPERATOR_SDK_VERSION}
opm = ${bin}/opm-${OPM_VERSION}
cmctl = ${bin}/cmctl-${CMCTL_VERSION}

${kustomize}: url := https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${os}_${arch}.tar.gz
${kustomize}:
	mkdir -p $(dir $@)
	curl -sSL ${url} | tar --directory $(dir $@) -xzf - kustomize
	mv $(dir $@)/kustomize $@

${cmctl}: url := https://github.com/cert-manager/cmctl/releases/download/v$(CMCTL_VERSION)/cmctl_$(os)_$(arch)
${cmctl}:
	mkdir -p $(dir $@)
	curl -fsSL ${url} > $@
	chmod +x $@

${kind}: url := https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-${os}-${arch}
${operator_sdk}: url := https://github.com/operator-framework/operator-sdk/releases/download/v${OPERATOR_SDK_VERSION}/operator-sdk_${os}_${arch}
${opm}: url := https://github.com/operator-framework/operator-registry/releases/download/v${OPM_VERSION}/${os}-${arch}-opm

# Generic download rule for downloadable static binaries
# Adapted from https://stackoverflow.com/a/47521912
downloadable_executables = ${kind} ${operator_sdk} ${opm}
${downloadable_executables}:
	mkdir -p $(dir $@)
	curl --remote-time -sSL -o $@ ${url}
	chmod +x $@


build := build
$(build):
		mkdir -p $@

build_v := $(build)/${BUNDLE_VERSION}

cert_manager_manifest_upstream = build/cert-manager.${CERT_MANAGER_VERSION}.upstream.yaml
${cert_manager_manifest_upstream}: url := https://github.com/cert-manager/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml

cert_manager_logo = build/cert-manager-logo.png
${cert_manager_logo}: url := ${CERT_MANAGER_LOGO_URL}

downloadable_files = ${cert_manager_manifest_upstream} ${cert_manager_logo}
${downloadable_files}:
	mkdir -p $(dir $@)
	curl --remote-time -sSL -o $@ ${url}

cert_manager_manifest_olm = ${build_v}/cert-manager.${CERT_MANAGER_VERSION}.olm.yaml
fixup_cert_manager_manifests = hack/fixup-cert-manager-manifests
${cert_manager_manifest_olm}: ${cert_manager_manifest_upstream} ${fixup_cert_manager_manifests}
	mkdir -p $(dir $@)
	${fixup_cert_manager_manifests} < ${cert_manager_manifest_upstream} > $@

kustomize_config_dir = ${build_v}/config
kustomize_csv = ${kustomize_config_dir}/csv.yaml
${kustomize_csv}: ${cert_manager_manifest_olm}
	mkdir -p $(dir $@)
	ln -f $(abspath ${cert_manager_manifest_olm}) $@

scorecard_dir = config/scorecard
scorecard_files := $(shell find ${scorecard_dir} -type f)
kustomize_config = ${kustomize_config_dir}/kustomization.yaml
${kustomize_config}: ${kustomize_csv} ${scorecard_files} ${kustomize}
	mkdir -p ${kustomize_config_dir} && \
	rm -f $@  && \
	cd ${kustomize_config_dir}  && \
	$(abspath ${kustomize}) create --resources ../../../config/scorecard,csv.yaml

# We have to use `cat` and pipe the manifest rather than using it as stdin due
# to a bug in operator-sdk.
# See https://github.com/operator-framework/operator-sdk/issues/4951
bundle_osdk_dir = ${build_v}/bundle_osdk
bundle_osdk_csv = ${bundle_osdk_dir}/manifests/cert-manager.clusterserviceversion.yaml
${bundle_osdk_csv}: ${operator_sdk} ${kustomize_config} ${kustomize}
	rm -rf ${bundle_osdk_dir} && \
	mkdir -p ${bundle_osdk_dir} && \
	cd ${bundle_osdk_dir} && \
	$(abspath ${kustomize}) build $(abspath ${kustomize_config_dir}) | $(abspath ${operator_sdk}) generate bundle \
		--verbose \
		--channels $(subst $(space),$(comma),${BUNDLE_CHANNELS}) \
		--default-channel=$(STABLE_CHANNEL) \
		--package ${OLM_PACKAGE_NAME} \
		--version ${BUNDLE_VERSION} \
		--output-dir .

bundle_dir = bundle
bundle_dockerfile = ${bundle_dir}/bundle.Dockerfile
bundle_csv = ${bundle_dir}/manifests/cert-manager.clusterserviceversion.yaml
bundle_csv_global_config = global-csv-config.yaml
fixup_csv = hack/fixup-csv
${bundle_csv}: ${bundle_osdk_csv} ${fixup_csv} ${cert_manager_logo} ${bundle_csv_global_config}
	rm -rf ${bundle_dir}
	cp -a ${bundle_osdk_dir} ${bundle_dir}
	${fixup_csv} \
		--logo ${cert_manager_logo} \
		--config ${bundle_csv_global_config} \
		< ${bundle_osdk_csv} > $@

# Update the `bundle/` directory.
#
# The `metadata/annotations.yaml` file is modified to set minimum supported
# OpenShift version to v4.6, which ensures that cert-manager will be included in
# the community-operator catalogs for all versions of OpenShift >= v4.6
# (OpenShift 4.6 = Kubernetes 1.19).
#
# This is also to comply with the static-tests in the community-operators-prod
# repository. See:
# * https://redhat-connect.gitbook.io/certified-operator-guide/ocp-deployment/operator-metadata/bundle-directory/managing-openshift-versions
# * https://redhat-openshift-ecosystem.github.io/community-operators-prod/packaging-required-criteria-ocp/#configure-the-openshift-distribution
# * https://github.com/redhat-openshift-ecosystem/operator-pipelines/pull/562
.PHONY: bundle-generate
bundle-generate: ## Create / update the OLM bundle files
bundle-generate: ${bundle_csv}
	yq -i '.annotations."com.redhat.openshift.versions"="v4.6"' $(bundle_dir)/metadata/annotations.yaml

.PHONY: bundle-build
bundle-build: ## Create a cert-manager OLM bundle image
bundle-build:
	docker build -f ${bundle_dockerfile} -t ${BUNDLE_IMG} ${bundle_dir}

.PHONY: bundle-push
bundle-push: ## Push the OLM bundle image
bundle-push:
	docker push ${BUNDLE_IMG}

.PHONY: catalog-build
catalog-build: ## Create a new catalog image
catalog-build: ${opm}
	${opm} index add \
		--container-tool docker \
		--mode semver \
		--tag ${CATALOG_IMG} \
		--bundles ${BUNDLE_IMG}

.PHONY: catalog-push
catalog-push: ## Push the catalog index image
catalog-push:
	docker push ${CATALOG_IMG}

define catalog_yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
 name: cert-manager-test-catalog
 namespace: olm
spec:
 sourceType: grpc
 image: ${CATALOG_IMG}
 grpcPodConfig:
  securityContextConfig: restricted
---
endef

.PHONY: catalog-deploy
catalog-deploy: ## Deploy the catalog to Kubernetes
catalog-deploy: | $(build)
	$(file > $(build)/catalog.yaml,$(catalog_yaml))
	kubectl apply -f $(build)/catalog.yaml

define subscription_yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
 name: cert-manager-subscription
 namespace: operators
spec:
 channel: $(firstword ${BUNDLE_CHANNELS})
 name: cert-manager
 source: cert-manager-test-catalog
 sourceNamespace: olm
endef

.PHONY: subscription-deploy
subscription-deploy:
	$(file > build/subscription.yaml,${subscription_yaml})
	kubectl apply -f build/subscription.yaml

.PHONY: bundle-validate
bundle-validate: ## Run static checks
bundle-validate: ${operator_sdk}
	${operator_sdk} bundle validate ${bundle_dir} --select-optional suite=operatorframework

.PHONY: deploy-olm
deploy-olm: ## Deploy olm in the cluster
deploy-olm: ${operator_sdk}
	${operator_sdk} olm status || ${operator_sdk} olm install --timeout 5m

.PHONY: kind-cluster
kind-cluster: ## Use Kind to create a Kubernetes cluster for E2E tests
kind-cluster: ${kind}
	 ${kind} get clusters | grep ${E2E_CLUSTER_NAME} || ${kind} create cluster --name ${E2E_CLUSTER_NAME}

# Give a sense of progress by streaming all the events until the ClusterServiceVersion has been installed,
# then check the cert-manager API and print the detected cert-manager version.
#
# Also works around a bug in `cmctl check api`, where it will return success if
# the CRDs are installed but the webhook has not been configured. See
# https://github.com/cert-manager/cert-manager/issues/6721
#
# Use process substitution instead of pipe, otherwise kubectl get --watch may hang. See
# https://stackoverflow.com/a/53382807
.PHONY: bundle-test
bundle-test: ## Build bundles and test locally as described at https://operator-framework.github.io/community-operators/testing-operators/
bundle-test: $(cmctl) bundle-build bundle-push catalog-build catalog-push kind-cluster deploy-olm catalog-deploy subscription-deploy
	timeout 5m sed '/install strategy completed/q' < <(kubectl get events --namespace operators --watch)
	$(cmctl) check api --wait=5m
	$(cmctl) version -o yaml

.PHONY: clean-kind-cluster
clean-kind-cluster: ${kind}
	 ${kind} delete cluster --name ${E2E_CLUSTER_NAME}

.PHONY: clean-bundle-test
clean-bundle-test: ${kind}
	 kubectl -n operators delete clusterserviceversions,subscriptions --all


# The desired version of OpenShift.
# This should be supplied when running `make crc-instance OPENSHIFT_VERSION=4.8`
# on your laptop, and the version you supply will then be added to the metadata
# of the VM so that it can be downloaded from the metadata API by the crc setup
# scripts that run inside the VM.
OPENSHIFT_VERSION ?= 4.14

# The path to the pull-secret which you download from https://console.redhat.com/openshift/create/local
PULL_SECRET ?=

# The name of the VM.
# Default is crc-OPENSHIFT_VERSION
CRC_INSTANCE_NAME ?= crc-$(subst .,-,${OPENSHIFT_VERSION})

# These scripts are added to the metadata of the VM startup-script installs make
# and creates a crc user, before downloading and running the crc.mk file to
# install crc, and then run crc setup and crc install
startup_script := hack/crc-instance-startup-script.sh
crc_makefile := hack/crc.mk

.PHONY: crc-instance
crc-instance: ## Create a Google Cloud Instance with a crc OpenShift cluster
crc-instance: ${PULL_SECRET} ${startup_script} ${crc_makefile}
	: $${PULL_SECRET:?"Please set PULL_SECRET to the path to the pull-secret downloaded from https://console.redhat.com/openshift/create/local"}
	gcloud compute instances create ${CRC_INSTANCE_NAME} \
		--enable-nested-virtualization \
		--min-cpu-platform="Intel Haswell" \
		--custom-memory 32GiB \
		--custom-cpu 8 \
		--image-family=rhel-8 \
		--image-project=rhel-cloud \
		--preemptible \
		--boot-disk-size=200GiB \
		--boot-disk-type=pd-ssd \
		--metadata-from-file=make-file=${crc_makefile},pull-secret=${PULL_SECRET},startup-script=${startup_script} \
		--metadata=openshift-version=${OPENSHIFT_VERSION}
	until gcloud compute ssh crc@${CRC_INSTANCE_NAME} -- sudo systemctl is-system-running --wait; do sleep 2; done >/dev/null

E2E_TEST ?=

.PHONY: crc-e2e
crc-e2e: ## Run cert-manager E2E tests on the crc-instance
crc-e2e: ${E2E_TEST}
	: $${E2E_TEST:?"Please set E2E_TEST to the path to the cert-manager E2E test binary"}
	gcloud compute ssh crc@${CRC_INSTANCE_NAME} -- rm -f ./e2e
	gcloud compute scp --compress ${E2E_TEST} crc@${CRC_INSTANCE_NAME}:e2e
	gcloud compute ssh crc@${CRC_INSTANCE_NAME} -- E2E_OPENSHIFT=true ./e2e --repo-root=/dev/null --ginkgo.focus="Vault\ Issuer" --ginkgo.skip="Gateway"



.PHONY: update-community-operators
update-community-operators: export UPSTREAM := k8s-operatorhub
update-community-operators: export FORK := wallrj
update-community-operators: export REPO=community-operators
update-community-operators:
	./hack/create-community-operators-pr.sh

.PHONY: update-community-operators-prod
update-community-operators-prod: export UPSTREAM := redhat-openshift-ecosystem
update-community-operators-prod: export FORK := wallrj
update-community-operators-prod: export REPO=community-operators-prod
update-community-operators-prod:
	./hack/create-community-operators-pr.sh
