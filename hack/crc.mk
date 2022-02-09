# Install and run crc on a Google Cloud Instance.
#
# This makefile is run on the VM to download crc and then run crc setup and crc
# install.
# It discovers the desired version of openshift from the VM metadata API.
#
MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := install
.DELETE_ON_ERROR:
.SUFFIXES:

LOCAL_OS ?= linux
LOCAL_ARCH ?= amd64
BIN ?= bin
BUILD ?= build

# The desired version of OpenShift.
# This should be supplied when running `make crc-instance OPENSHIFT_VERSION=4.8` on your laptop, and
# the version you supply will then be added to the metadata of the VM so that
# when this makefile is run on the VM it can be downloaded from the metadata
# API.
OPENSHIFT_VERSION ?= $(shell curl -H "Metadata-Flavor: Google" -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/openshift-version")

# Prevent fancy TTY output
export TERM=dumb

# This maps crc versions to OpenShift versions.
# I found these by trawling through the crc release notes:
# * https://github.com/code-ready/crc/releases
# TODO(wallrj): It may be possible to automate this by examining the
# release-info.js files that are published for each crc release:
# * https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/1.34.0/release-info.json
crc_version_4.6 := 1.22.0
crc_version_4.7 := 1.29.1
crc_version_4.8 := 1.33.1
crc_version_4.9 := 1.39.0
crc_version = ${crc_version_${OPENSHIFT_VERSION}}

# Download the crc tarball
crc_archive_name = crc-${LOCAL_OS}-${LOCAL_ARCH}.tar.xz
crc_archive = ${BUILD}/${crc_archive_name}.${crc_version}
${crc_archive}: URL = https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/${crc_version}/${crc_archive_name}
${crc_archive}:
	mkdir -p $(dir $@)
	curl --fail --silent --show-error --location --output $@ ${URL}

# Extract the crc tarball
crc = ${BIN}/crc-${crc_version}
${crc}: ${crc_archive}
	mkdir -p  $(dir $@)
	tar --strip-components 1 --directory $(dir $@) --extract --file \
		${crc_archive} crc-${LOCAL_OS}-${crc_version}-${LOCAL_ARCH}/crc
	mv $(dir $@)crc $@
	touch $@

# Download the RedHat pull-secret
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

# Setup crc and start a crc (nested) VM
.PHONY: install
install: ${crc} ${PULL_SECRET}
	${crc} config set consent-telemetry yes
	${crc} config set disable-update-check true
	${crc} config set cpus 8
	${crc} config set memory $$((1024 * 24))
	${crc} config set pull-secret-file ${PULL_SECRET}
	${crc} --log-level=debug setup
	${crc} --log-level=debug start
