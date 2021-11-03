#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

dnf install -y make
adduser crc --groups google-sudoers
sudo -u crc -i bash -c 'make -f <(curl  -H "Metadata-Flavor: Google" -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/make-file")'
