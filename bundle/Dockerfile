FROM scratch

LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=cert-manager-operator
LABEL operators.operatorframework.io.bundle.channels.v1=alpha,stable
LABEL operators.operatorframework.io.bundle.channel.default.v1=stable

COPY bundle/cert-manager-operator/1.1.0/manifests /manifests/
COPY bundle/cert-manager-operator/1.1.0/metadata /metadata/

LABEL com.redhat.openshift.versions="v4.5,v4.6"
LABEL com.redhat.delivery.operator.bundle=true
# This is used to indicate support for OpenShift versions before 4.6. If you
# don't specify this flag, your operator won't be listed in 4.5 or earlier.
LABEL com.redhat.delivery.backport=true
