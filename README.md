# cert-manager operator deployment
Definitions for the cert-manager operator published via Red Hat's Operator Lifecycle Manager (OLM)

This repository contains all files that are used to build the [operator](https://operatorhub.io/what-is-an-operator) to deploy cert-manager.
This is to allow users of OpenShift and OperatorHub to easily install cert-manager into their clusters. It is currently an experimental deployment method.
This includes the operator itself, based on the Helm operator as well as Dockerfiles to build [UBI](https://connect.redhat.com/about/faq/what-red-hat-universal-base-image-ubi-0) based images.

This repository contains all files that are used by the RedHat image builder to release the operator.

For more info on cert-manager, please see [the cert-manager repository](https://github.com/jetstack/cert-manager) ot [cert-manager.io](https://cert-manager.io )