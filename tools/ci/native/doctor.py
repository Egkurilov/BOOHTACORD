"""Report installed native versions and fail on source/runtime drift."""
import json
from .process import ROOT, VERSIONS, output, require_version
from tools.verify.toolchains.check import check_versions


def main():
    errors = check_versions(ROOT, VERSIONS)
    if errors:
        raise RuntimeError("\n".join(errors))
    require_version("node", output("node", "--version").removeprefix("v"))
    require_version("go", output("go", "version", cwd=ROOT / "backend").split()[2].removeprefix("go"))
    flutter = json.loads(output("flutter", "--version", "--machine"))
    require_version("flutter", flutter["frameworkVersion"])
    require_version("dart", flutter["dartSdkVersion"].split()[0])
    print("Native developer toolchains agree with tools/toolchains.json")


if __name__ == "__main__":
    main()
