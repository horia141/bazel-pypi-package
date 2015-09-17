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
    packages=["{name}"],
    zip_safe=False,
    test_suite = "{test_suite}",
    tests_require={tests_require},
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
                 author, author_email, license, package, test_suite = "nose.collector",
                 tests_require = ["nose"], visibility=None):
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
        license = license,
        test_suite = test_suite,
        tests_require = ', '.join(['"%s"' % r for r in tests_require])
    )

    manifest_in = _MANIFEST_IN_TEMPLATE.format(
        long_description = long_description,
    )

    register_invoker = _REGISTER_INVOKER_TEMPLATE

    upload_invoker = _UPLOAD_INVOKER_TEMPLATE

    native.genrule(
        name = name,
        srcs = [package, long_description],
        outs = ["setup.py", "MANIFEST.in"],
        cmd = ("echo '%s' > $(location setup.py)" % setup_py) + 
            (" && echo '%s' > $(location MANIFEST.in)" % manifest_in) +
            (" && mkdir $(GENDIR)/%s" % short_name) +
            (" && cp $(SRCS) $(GENDIR)/%s" % short_name) +
            (" && mv $(GENDIR)/%s/%s $(GENDIR)" % (short_name, long_description)),
    )

    native.genrule(
        name = short_name + "_register_invoker",
	srcs = [":" + name],
	outs = ["register_invoker.sh"],
	cmd = ("echo '%s' > $(location register_invoker.sh)" % register_invoker)
    )

    native.sh_binary(
        name = short_name + "_register",
	srcs = [":" + short_name + "_register_invoker"],
	data = [":" + name, long_description, package]
    )

    native.genrule(
        name = short_name + "_upload_invoker",
	srcs = [":" + name],
	outs = ["upload_invoker.sh"],
	cmd = ("echo '%s' > $(location upload_invoker.sh)" % upload_invoker)
    )

    native.sh_binary(
        name = short_name + "_upload",
	srcs = [":" + short_name + "_upload_invoker"],
	data = [":" + name, long_description, package]
    )
