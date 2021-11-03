#!/usr/bin/make -f
MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := openshift
.DELETE_ON_ERROR:
.SUFFIXES:

LOCAL_OS ?= linux
LOCAL_ARCH ?= amd64
BIN ?= bin
BUILD ?= build
OPENSHIFT_VERSION ?= $(shell curl -H "Metadata-Flavor: Google" -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/openshift-version")

# Prevent fancy TTY output from tools like kind
export TERM=dumb

crc_version_4.6 := 1.22.0
crc_version_4.7 := 1.29.1
crc_version_4.8 := 1.33.1
crc_version_4.9 := 1.34.0
crc_version = ${crc_version_${OPENSHIFT_VERSION}}

crc_archive_name = crc-${LOCAL_OS}-${LOCAL_ARCH}.tar.xz
crc_archive = ${BUILD}/${crc_archive_name}.${crc_version}
${crc_archive}: URL = https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/${crc_version}/${crc_archive_name}
${crc_archive}:
	mkdir -p $(dir $@)
	curl --fail --silent --show-error --location --output $@ ${URL}

crc = ${BIN}/crc-${crc_version}
${crc}: ${crc_archive}
	mkdir -p  $(dir $@)
	tar --strip-components 1 --directory $(dir $@) --extract --file \
		${crc_archive} crc-${LOCAL_OS}-${crc_version}-${LOCAL_ARCH}/crc
	mv $(dir $@)crc $@
	touch $@

PULL_SECRET ?= ${BUILD}/pull-secret
${PULL_SECRET}: URL := "http://metadata.google.internal/computeMetadata/v1/instance/attributes/pull-secret"
${PULL_SECRET}:
	mkdir -p $(dir $@)
	curl ${URL} \
		--silent \
		--show-error \
		--location \
		--fail \
		--header "Metadata-Flavor: Google" \
		--output $@

.PHONY: openshift
openshift: ${crc} ${PULL_SECRET}
	${crc} config set consent-telemetry yes
	${crc} config set disable-update-check true
	${crc} config set cpus 8
	${crc} config set memory $$((1024 * 24))
	${crc} config set pull-secret-file ${PULL_SECRET}
	${crc} --log-level=debug setup
	${crc} --log-level=debug start

startup_script := hack/crc-instance-startup-script.sh

.PHONY: crc-instance
crc-instance: ${PULL_SECRET} ${startup_script}
	gcloud compute instances create crc-$(subst .,-,${OPENSHIFT_VERSION}) \
		--enable-nested-virtualization \
		--min-cpu-platform="Intel Haswell" \
		--custom-memory 32GiB \
		--custom-cpu 8 \
		--image-family=rhel-8 \
		--image-project=rhel-cloud \
		--preemptible \
		--boot-disk-size=200GiB \
		--boot-disk-type=pd-ssd \
		--metadata-from-file=make-file=$(abspath $(lastword $(MAKEFILE_LIST))),pull-secret=${PULL_SECRET},startup-script=${startup_script} \
		--metadata=openshift-version=${OPENSHIFT_VERSION}
