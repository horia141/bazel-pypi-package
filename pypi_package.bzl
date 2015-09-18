"""A Bazel macro for building Python packages and interacting with PyPi"""


_SETUP_PY_TEMPLATE = """from setuptools import setup

def readme():
    with open("{long_description}") as f:
        return f.read()

setup(
    name = "{name}",
    version = "{version}",
    description = "{description}",
    long_description = readme(),
    classifiers = [{classifiers}],
    keywords = "{keywords}",
    url = "{url}",
    author = "{author}",
    author_email = "{author_email}",
    license = "{license}",
    packages=[{packages}],
    install_requires=[{install_requires}],
    test_suite = "{test_suite}",
    tests_require=[{tests_require}],
    zip_safe=False,
)
"""

_MANIFEST_IN_TEMPLATE = """include {long_description}"""

_REGISTER_INVOKER_TEMPLATE = """
#/bin/bash

for key in "$$@"
do
  case $$key in
    --pypi_user=*)
      user="$${key#*=}"
      shift
      ;;
    --pypi_pass=*)
      pass="$${key#*=}"
      shift
      ;;
  esac
done

# Painful levels of embedding.
cat << EOF > .pypirc
[distutils]
index-servers = pypi

[pypi]
repository = https://pypi.python.org/pypi
username = $$user
password = $$pass
EOF

HOME=`pwd` python setup.py register -r pypi

rm .pypirc
"""

_UPLOAD_INVOKER_TEMPLATE = """
#/bin/bash

for key in "$$@"
do
  case $$key in
    --pypi_user=*)
      user="$${key#*=}"
      shift
      ;;
    --pypi_pass=*)
      pass="$${key#*=}"
      shift
      ;;
  esac
done

python setup.py sdist
python setup.py bdist_wheel
twine upload dist/* -u $$user -p $$pass
"""

def pypi_package(name, version, description, long_description, classifiers, keywords, url,
                 author, author_email, license, packages, install_requires = [],
                 test_suite = "nose.collector", tests_require = ["nose"],
		 visibility=["//visibility:public"]):
    """A `pypi_package` is a python package and modulates interaction with the PyPi repository.

    The arguments to this rule correspond to the ones for the `setup` function from 
    https://packaging.python.org/en/latest/distributing. Check it out for the full details of
    building a Python package. The only difference is that some arguments accept Bazel lables
    rather than strings.

    The name must be of the format `{name}_pkg`. One can then run `{name}_register` to register
    the package with PyPi for the first time or `{name}_upload` to add the current code under
    the `version` number. For both these binaries you need to specify the `pypi_user` and
     `pypi_pass` argument, with your credentials for PyPi. See the README.md file for more details.

    Args:
      name: A unique name for this rule. Must end with `_pkg`.
      version: A version string which uniquely identifies the current version of the code. See
          https://packaging.python.org/en/latest/distributing/#version for more details.
      description: A string with the short description of the package.
      long_description: A label with the "long" description of the package. Usually a README.md
          or README.rst file.
      classifiers: A list of strings, containing Trove classifiers. See
          https://packaging.python.org/en/latest/distributing/#classifiers for more details.
      keywords: A string of space separated keywords.
      url: A homepage for the project.
      author: Details about the author.
      author_email: The email for the author.
      license: The type of license to use.
      packages: A list of `py_library` labels to be included in the package.
      install_requires: A list of strings or `_pkg` labels which are names of required packages
          for this one.
      test_suite: Name of the test suite runner.
      tests_require: A list of strings or `_pkg` labels which are names of required testing
          packages for this one.
      visibility: Rule visibility.
    """
      
    if not name.endswith('_pkg'):
       fail('pypi_package name must end in "_pkg"')

    short_name = name[0:-4]

    setup_py = _SETUP_PY_TEMPLATE.format(
        name = short_name,
        version = version,
        description = description,
        long_description=long_description,
        classifiers = ', '.join(['"%s"' % c for c in classifiers]),
        keywords = keywords,
        url = url,
        author = author,
        author_email = author_email,
	packages = ', '.join(['"%s"' % p[1:] for p in packages]),
	install_requires = ', '.join(['"%s"' % _translate_package_name(i) for i in install_requires]),
        license = license,
        test_suite = test_suite,
        tests_require = ', '.join(['"%s"' % _translate_package_name(r) for r in tests_require])
    )

    manifest_in = _MANIFEST_IN_TEMPLATE.format(
        long_description = long_description,
    )

    register_invoker = _REGISTER_INVOKER_TEMPLATE

    upload_invoker = _UPLOAD_INVOKER_TEMPLATE

    native.genrule(
        name = name,
        srcs = packages + [long_description],
        outs = ["setup.py", "MANIFEST.in"],
        cmd = ("echo '%s' > $(location setup.py)" % setup_py) + 
            (" && echo '%s' > $(location MANIFEST.in)" % manifest_in) +
            (" && mkdir $(GENDIR)/%s" % short_name) +
            (" && cp $(SRCS) $(GENDIR)/%s" % short_name) +
            (" && mv $(GENDIR)/%s/%s $(GENDIR)" % (short_name, long_description)),
	visibility = visibility,
    )

    native.genrule(
        name = short_name + "_register_invoker",
	srcs = [":" + name],
	outs = ["register_invoker.sh"],
	cmd = ("echo '%s' > $(location register_invoker.sh)" % register_invoker),
	visibility = visibility,
    )

    native.sh_binary(
        name = short_name + "_register",
	srcs = [":" + short_name + "_register_invoker"],
	data = packages + [":" + name, long_description],
	visibility = visibility,
    )

    native.genrule(
        name = short_name + "_upload_invoker",
	srcs = [":" + name],
	outs = ["upload_invoker.sh"],
	cmd = ("echo '%s' > $(location upload_invoker.sh)" % upload_invoker),
	visibility = visibility,
    )

    native.sh_binary(
        name = short_name + "_upload",
	srcs = [":" + short_name + "_upload_invoker"],
	data = packages + [":" + name, long_description],
	visibility = visibility,
    )


def _translate_package_name(name):
    if not name.endswith('_pkg'):
        return name

    idx = name.find('//:')
    return name[idx+3:-4]