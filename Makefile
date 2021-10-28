MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:

OLM_PACKAGE_NAME ?= cert-manager
IMG_BASE ?= gcr.io/jetstack-richard/cert-manager
BUNDLE_IMG_BASE ?= ${IMG_BASE}-olm-bundle
BUNDLE_IMG ?= ${BUNDLE_IMG_BASE}:${CERT_MANAGER_VERSION}
CATALOG_VERSION ?= $(shell git describe --tags --always --dirty)
CATALOG_IMG ?= ${IMG_BASE}-olm-catalogue:${CATALOG_VERSION}
E2E_CLUSTER_NAME ?= cert-manager-olm
CERT_MANAGER_LOGO_URL ?= https://github.com/cert-manager/website/raw/3998bef91af7266c69f051a2f879be45eb0b3bbb/static/favicons/favicon-256.png
define CERT_MANAGER_VERSIONS
1.6.0
1.5.4
1.5.3
1.4.4
1.4.3
1.4.2
1.4.1
1.4.0
1.3.1
endef
CERT_MANAGER_VERSION ?= $(firstword ${CERT_MANAGER_VERSIONS})

KUSTOMIZE_VERSION ?= 4.1.3
KIND_VERSION ?= 0.9.0
OPERATOR_SDK_VERSION ?= 1.8.0
OPM_VERSION ?= 1.17.3

bin := bin
os := $(shell go env GOOS)
arch := $(shell go env GOARCH)

kustomize = ${bin}/kustomize-${KUSTOMIZE_VERSION}
kind = ${bin}/kind-${KIND_VERSION}
operator_sdk = ${bin}/operator-sdk-${OPERATOR_SDK_VERSION}
opm = ${bin}/opm-${OPM_VERSION}

${kustomize}: url := https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${os}_${arch}.tar.gz
${kustomize}:
	mkdir -p $(dir $@)
	curl -sSL ${url} | tar --directory $(dir $@) -xzf - kustomize
	mv $(dir $@)/kustomize $@

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

build_v = build/${CERT_MANAGER_VERSION}

cert_manager_manifest_upstream = ${build_v}/cert-manager.${CERT_MANAGER_VERSION}.upstream.yaml
${cert_manager_manifest_upstream}: url := https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml

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
	mkdir -p ${kustomize_config_dir}
	rm -f $@
	cd ${kustomize_config_dir}
	$(abspath ${kustomize}) create --resources ../../../config/scorecard,csv.yaml

# We have to use `cat` and pipe the manifest rather than using it as stdin due
# to a bug in operator-sdk.
# See https://github.com/operator-framework/operator-sdk/issues/4951
bundle_osdk_dir = ${build_v}/bundle_osdk
bundle_osdk_csv = ${bundle_osdk_dir}/manifests/cert-manager.clusterserviceversion.yaml
${bundle_osdk_csv}: ${operator_sdk} ${kustomize_config} ${kustomize}
	rm -rf ${bundle_osdk_dir}
	mkdir -p ${bundle_osdk_dir}
	cd ${bundle_osdk_dir}
	$(abspath ${kustomize}) build $(abspath ${kustomize_config_dir}) | $(abspath ${operator_sdk}) generate bundle \
		--verbose \
		--channels stable \
		--default-channel stable \
		--package ${OLM_PACKAGE_NAME} \
		--version ${CERT_MANAGER_VERSION} \
		--output-dir .

bundle_base =github.com/operator-framework/community-operators
bundle_dir = ${bundle_base}/${CERT_MANAGER_VERSION}
bundle_dockerfile = ${bundle_dir}/bundle.Dockerfile
bundle_csv = ${bundle_dir}/manifests/cert-manager.clusterserviceversion.yaml
bundle_csv_global_config = ${bundle_base}/global-csv-config.yaml
fixup_csv = hack/fixup-csv
${bundle_csv}: ${bundle_osdk_csv} ${fixup_csv} ${cert_manager_logo} ${bundle_csv_global_config}
	rm -rf ${bundle_dir}
	cp -a ${bundle_osdk_dir} ${bundle_dir}
	${fixup_csv} \
		--logo ${cert_manager_logo} \
		--config ${bundle_csv_global_config} \
		< ${bundle_osdk_csv} > $@

.PHONY: bundle-generate
bundle-generate: ## Create / update the OLM bundle files
bundle-generate: ${bundle_csv}

.PHONY: bundle-build
bundle-build: ## Create a cert-manager OLM bundle image
bundle-build: ${bundle_csv} ${bundle_dockerfile}
	docker build -f ${bundle_dockerfile} -t ${BUNDLE_IMG} ${bundle_dir}

.do-bundle-publish-for-version/%:
	$(MAKE) CERT_MANAGER_VERSION=$* bundle-build bundle-push

.PHONY: bundle-publish-all
bundle-publish-all: ## Build and push all bundle versions
bundle-publish-all: $(addprefix .do-bundle-publish-for-version/,${CERT_MANAGER_VERSIONS})

.PHONY: bundle-push
bundle-push: ## Push the OLM bundle image
bundle-push:
	docker push ${BUNDLE_IMG}

empty :=
space := $(empty) $(empty)
comma := ,
comma-separate = $(subst ${space},${comma},$(strip $1))
bundle_images = $(addprefix ${BUNDLE_IMG_BASE}\:,${CERT_MANAGER_VERSIONS})
docker-image-digest = $(shell docker inspect $1 --format='{{index .RepoDigests 0}}')
.PHONY: catalog-build
catalog-build: ## Create a new catalog image
catalog-build: ${opm} bundle-publish-all
	${opm} index add \
		--container-tool docker \
		--mode semver \
		--tag ${CATALOG_IMG} \
		--bundles $(call comma-separate,$(call docker-image-digest,${bundle_images}))

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
---
endef

.PHONY: catalog-deploy
catalog-deploy: ## Deploy the catalog to Kubernetes
catalog-deploy:
	$(file > build/catalog.yaml,${catalog_yaml})
	kubectl apply -f build/catalog.yaml

define subscription_yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
 name: cert-manager-subscription
 namespace: operators
spec:
 channel: stable
 name: cert-manager
 startingCSV: cert-manager.v$(lastword ${CERT_MANAGER_VERSIONS})
 source: cert-manager-test-catalog
 sourceNamespace: olm
endef

.PHONY: subscription-deploy
subscription-deploy:
	$(file > build/subscription.yaml,${subscription_yaml})
	kubectl apply -f build/subscription.yaml

.PHONY: bundle-validate
bundle-validate: ## Run static checks
bundle-validate: ${bundle_csv} ${operator_sdk}
	${operator_sdk} bundle validate ${bundle_dir} --select-optional suite=operatorframework

.PHONY: deploy-olm
deploy-olm: ## Deploy olm in the cluster
deploy-olm: ${operator_sdk}
	${operator_sdk} olm status || ${operator_sdk} olm install --timeout 5m

.PHONY: kind-cluster
kind-cluster: ## Use Kind to create a Kubernetes cluster for E2E tests
kind-cluster: ${kind}
	 ${kind} get clusters | grep ${E2E_CLUSTER_NAME} || ${kind} create cluster --name ${E2E_CLUSTER_NAME}

.PHONY: bundle-test
bundle-test: ## Build bundles and test locally as described at https://operator-framework.github.io/community-operators/testing-operators/
bundle-test: catalog-build catalog-push kind-cluster deploy-olm catalog-deploy subscription-deploy

.PHONY: clean-kind-cluster
clean-kind-cluster: ${kind}
	 ${kind} delete cluster --name ${E2E_CLUSTER_NAME}

.PHONY: clean-bundle-test
clean-bundle-test: ${kind}
	 kubectl -n operators delete clusterserviceversions,subscriptions --all
