# README

These folders contain patches with operatorhub.io or OpenShift OperatorHub package specific
modifications.

## redhat-openshift-ecosystem/00-remove-default-seccompprofile.patch

This removes the seccompProfile fields in RedHat OpenShift OLM bundles
for backwards compatibility with OpenShift < 4.11.

TODO(wallrj): Remove this patch when we drop support for OpenShift 4.10.

Here is the reason for this patch:
> Note that while K8S restricted requires workloads to set
> seccompProfile=runtime/default, in OCP 4.10 and earlier, setting the
> seccompProfile explicitly disqualified the workload from the restricted SCC.
> To be compatible with 4.10 and 4.11, the seccompProfile value must be left
> unset(the SCC itself will default it to runtime/default so it is ok to leave
> it empty).
https://github.com/redhat-openshift-ecosystem/community-operators-prod/discussions/1417
