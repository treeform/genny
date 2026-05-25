import importlib.util
import os
import sys
from pathlib import Path

from pixie_python_checks import run


def bindings_dir():
    return Path(os.environ.get("PIXIE_BINDINGS_DIR", Path(__file__).resolve().parents[2] / "pixie" / "bindings" / "generated"))


def add_dll_dirs():
    if os.name == "nt":
        for entry in os.environ.get("PATH", "").split(os.pathsep):
            if entry and Path(entry).is_dir():
                os.add_dll_directory(entry)


def load_ctypes_pixie():
    module_path = bindings_dir() / "pixie.py"
    spec = importlib.util.spec_from_file_location("pixie", module_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["pixie"] = module
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    add_dll_dirs()
    run(load_ctypes_pixie(), "python")
    print("All Pixie Python tests passed!")
