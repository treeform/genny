import os
import sys
from pathlib import Path

from pixie_python_checks import run


def bindings_dir():
    return Path(os.environ.get("PIXIE_BINDINGS_DIR", Path(__file__).resolve().parents[2] / "pixie" / "bindings" / "generated"))


if os.name == "nt":
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if entry and Path(entry).is_dir():
            os.add_dll_directory(entry)

sys.path.insert(0, str(bindings_dir()))
import pixie  # noqa: E402


if __name__ == "__main__":
    run(pixie, "python_native")
    print("All Pixie native Python tests passed!")
