# README

This directory contains directories containing automatically generated OLM bundles
which should be copied to https://github.com/operator-framework/community-operators with pull requests.

Each sub-directory contains the bundle files for a particular version of cert-manager.
And each of these need to be added to two locations, as described in [Where to contribute][] documentation on OperatorHub:
[community-operators][] and [upstream-community-operators][].

[Where to contribute]: https://operator-framework.github.io/community-operators/contributing-where-to/
[community-operators]: https://github.com/operator-framework/community-operators/tree/master/community-operators
[upstream-community-operators]: https://github.com/operator-framework/community-operators/tree/master/upstream-community-operators

The `global-csv-config.yaml` file contains CSV field values which are common to all bundle CSV files.
