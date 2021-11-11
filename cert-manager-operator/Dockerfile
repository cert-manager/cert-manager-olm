# Copyright 2020 The Jetstack cert-manager contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM alpine:3.11 as chart-get

RUN apk add wget tar
RUN wget https://charts.jetstack.io/charts/cert-manager-v1.1.0.tgz
# TODO: add some kind of verification
RUN tar xzf cert-manager-v1.1.0.tgz

FROM quay.io/jetstack/cert-manager-controller:v1.1.0 as cm-image

FROM quay.io/operator-framework/helm-operator:v1.2.0

### Required OpenShift Labels
LABEL name="cert-manager Operator" \
      vendor="Jetstack" \
      version="v1.1.0" \
      release="1" \
      summary="This is the cert-manager operator." \
      description="This operator will deploy cert-manager to the cluster."

# Required Licenses
COPY --from=cm-image /licenses /licenses/cert-manager

COPY --from=chart-get /cert-manager/ ${HOME}/helm-charts/cert-manager
COPY watches.yaml ${HOME}/watches.yaml
