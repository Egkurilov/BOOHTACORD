"""Identical locked web check for developers and CI."""
from .process import client, output, require_version, run


def main():
    require_version("node", output("node", "--version").removeprefix("v"))
    for args in (("ci",), ("test",), ("run", "build")):
        run("npm", *args, cwd=client("web"))


if __name__ == "__main__":
    main()
