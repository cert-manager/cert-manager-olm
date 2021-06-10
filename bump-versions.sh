#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

last_replaced_version="0.15.3"
last_version="1.1.0"
next_version="1.3.1"

rm -rf bundle/cert-manager-operator/${next_version}

# Copy the last bundle
cp -a \
   bundle/cert-manager-operator/${last_version}/ \
   bundle/cert-manager-operator/${next_version}

pushd bundle/cert-manager-operator/${next_version}

# Rename the versioned CSVfile
mv \
    "manifests/cert-manager-operator.v${last_version}.clusterserviceversion.yaml" \
    "manifests/cert-manager-operator.v${next_version}.clusterserviceversion.yaml"

# Replace  versions in the new bundle
find . -name '*.yaml' | xargs sed -i "s/${last_version}/${next_version}/g"

# Update the "replaces" version
find . -name '*.yaml' | xargs sed -i "s/${last_replaced_version}/${last_version}/g"

popd

# Update current CSV
sed -i "s/${last_version}/${next_version}/g" bundle/cert-manager-operator/cert-manager-operator.package.yaml

# Update the bundle copied into the bundle Dockerfil
sed -i "s/${last_version}/${next_version}/g" bundle/Dockerfile

# Update the root Dockerfile
sed -i "s/${last_version}/${next_version}/g" Dockerfile

# Update UBI image Dockerfiles
sed -i "s/${last_version}/${next_version}/g" ubi-images/Dockerfile.*

# Update watches
sed -i "s/${last_version}/${next_version}/g" watches.yaml
