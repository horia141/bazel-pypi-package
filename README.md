# Bazel PyPi Package

A [Bazel](bazel) macro for building Python packages and interacting with PyPi. The goal is to have the package configuration one would have in a `setup.py` file inside a Bazel BUILD file as a `pypi_package` rule. Interacting with [PyPi](pypi) is then done via Bazel commands, rather than the regualr commands, which are outside the build system.

## Rationale ##

[Bazel](bazel) offers the `py_library`, `py_test` and `py_binary` rules. These are great for working inside a single application codebase. However, many Python projects are libraries and are exported as packages in the [Python Package Index - PyPi](pypi). Bazel does not offer anything for integrating with it, at the moment.

## Installation ##

## Usage ##

[bazel]: http://bazel.io
[pypi]: https://pypi.python.org/pypi