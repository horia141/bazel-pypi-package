# Bazel PyPi Package

A [Bazel][bazel] macro for building Python packages and interacting with PyPi. The goal is to have the package configuration one would have in a `setup.py` file inside a Bazel BUILD file as a `pypi_package` rule. Interacting with [PyPi][pypi] is then done via Bazel commands, rather than the regualr commands, which are outside the build system.

## Rationale ##

[Bazel][bazel] offers the `py_library`, `py_test` and `py_binary` rules. These are great for working inside a single application codebase. However, many Python projects are libraries, and are exported as packages in the [Python Package Index - PyPi][pypi]. [Bazel][bazel] does not offer anything for integrating with it, at the moment. As such, all the interaction is done through the regular mechanisms described in [Packaging and Distributing Projects][dist]. This implies the existance of the `setup.py`, `MANIFEST.in` and `.pypirc` files, as well as the existance of `build`, `dist`, `*.egg-info` and other top-level directories which contain Python build artifacts. This state of affairs is quite messy. There are two separate build systems present, each with their configuration and each producing different forms of output clutter. Ideally we'd want only one - [Bazel][bazel].

The goal of this project is to correct this state of affairs, by providing a small set of tools which encapsulate all the configuration and steps necessary for managing the interaction with the Python package index. At some point in the future, it should be integrated with regular [Bazel][bazel].

## Installation and Usage

[Bazel][bazel] doesn't yet allow importing macro libraries in the workspace. Therefore, one has to copy `pypi_package.bzl` in a location from which other BUILD files can load it.

The following usage example is borrowed from the [tabletest][tabletest] package, which is a small utility library for writing neater unit-tests.

In a BUILD file, one has to first import the macro, like so:

```Python
load("/tools/pypi_package", "pypi_package")
```

We define a regular Python library, which will be included in the package. In general, we can have more than one such library.

```Python
py_library(
    name = "tabletest",
    srcs = ["tabletest/__init__.py"],
    visibility = ["//visibility:public"],
    srcs_version = "PY2"
)
```

In a manner similar to the configuration for the `setup` function, we then write the `pypi_package` rule as:

```Python
pypi_package(
    name = "tabletest_pkg",
    version = "1.0.2",
    description = "Unit testing module for table-like test, for Python 2.",
    long_description = "README.md",
    classifiers = [
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX",
        "Programming Language :: Python :: 2",
        "Programming Language :: Python :: 2.6",
        "Programming Language :: Python :: 2.7",
        "Topic :: Software Development :: Testing",
        "Topic :: Software Development :: Libraries :: Python Modules"
    ],
    keywords = "unittest test table testing",
    url = "http://github.com/horia141/tabletest",
    author = "Horia Coman",
    author_email = "horia141@gmail.com",
    license = "MIT",
    packages = [":tabletest"],
    test_suite = "nose.collector",
    tests_require = ["nose"],
)
```

We must first register the package with [PyPi][pypi]. This is achieved by running the following binary:

```bash
bazel run //:tabletest_register -- --pypi_user=[your username] --pypi_pass=[your password]
```

After registering (which should be done only once, but is otherwise idempotent), we can upload the current version of the code (the result of building the `py_library` rule from above) to the package index via:

```bash
bazel run //:tabletest_upload -- --pypi_user=[your username] --pypi_pass=[your password]
```

The name of the `pypi_package` rule needs to end in `_pkg` and the prefix for it will be used to generate the `_register` and `_upload` binaries.

Each time a new version needs to be updated, the `version` field must be updated.

The rule tries to mimick the behavior of the `setup.py` file as described [here][dist], but with extra integration with [Bazel][bazel], such as accepting labels for local libraries and the `README.md` file etc.

== Requirements ==

A working installation of [Bazel][bazel] and everything in [Packaging and Distributing Projects][dist].

[bazel]: http://bazel.io
[pypi]: https://pypi.python.org/pypi
[dist]: https://packaging.python.org/en/latest/distributing/
[tabletest]: https://github.com/horia141/tabletest