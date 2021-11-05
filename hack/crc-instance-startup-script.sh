#!/usr/bin/env bash
#
# This is a startup-script which will be run every time the Google Cloud instance boots,
# so it must be idempotent.
# https://cloud.google.com/compute/docs/instances/startup-scripts/linux

set -o errexit
set -o nounset
set -o pipefail

command -v make || dnf install -y make
adduser crc --groups google-sudoers || true
sudo -u crc -i bash -c 'make -f <(curl  -H "Metadata-Flavor: Google" -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/make-file")'
