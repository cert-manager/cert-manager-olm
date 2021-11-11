MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL: help
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:

# from https://suva.sh/posts/well-documented-makefiles/
.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# The desired version of OpenShift.
# This should be supplied when running `make crc-instance OPENSHIFT_VERSION=4.8`
# on your laptop, and the version you supply will then be added to the metadata
# of the VM so that it can be downloaded from the metadata API by the crc setup
# scripts that run inside the VM.
OPENSHIFT_VERSION ?= 4.9

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
	if gcloud compute instances list --filter=name=${CRC_INSTANCE_NAME}; then exit; fi
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
crc-e2e: crc-instance ${E2E_TEST}
	: $${E2E_TEST:?"Please set E2E_TEST to the path to the cert-manager E2E test binary"}
	gcloud compute ssh crc@${CRC_INSTANCE_NAME} -- rm -f ./e2e
	gcloud compute scp --compress ${E2E_TEST} crc@${CRC_INSTANCE_NAME}:e2e
	gcloud compute ssh crc@${CRC_INSTANCE_NAME} -- ./e2e --repo-root=/dev/null --ginkgo.focus="CA\ Issuer" --ginkgo.skip="Gateway"
