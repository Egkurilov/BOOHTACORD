"""Identical locked web check for developers and CI."""
import sys
from .process import client, output, require_version, run


def main():
    require_version("node", output("node", "--version").removeprefix("v"))
    run("npm", "ci", cwd=client("web"))
    run("node", "--test", "tools/verify/dependencies/web_imports.test.mjs")
    run(sys.executable, "-m", "tools.verify.dependencies.web")
    for args in (("test",), ("run", "build")):
        run("npm", *args, cwd=client("web"))


if __name__ == "__main__":
    main()
