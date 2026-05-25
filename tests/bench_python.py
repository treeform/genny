"""Small non-gating ctypes call overhead benchmark."""

import importlib.util
import sys
import time
from pathlib import Path


ROOT = Path(__file__).parent / "generated"
CTYPES_PATH = ROOT / "test.py"


def load_ctypes():
    if not CTYPES_PATH.exists():
        raise SystemExit(f"Missing ctypes wrapper: {CTYPES_PATH}")

    spec = importlib.util.spec_from_file_location("test", CTYPES_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["test"] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def bench(label, func, iterations):
    for _ in range(1000):
        func(42)

    start = time.perf_counter()
    for _ in range(iterations):
        func(42)
    elapsed = time.perf_counter() - start
    print(f"{label}: {elapsed * 1e9 / iterations:.1f} ns/call")


def main():
    iterations = 200_000
    ctypes_mod = load_ctypes()
    bench("ctypes", ctypes_mod.simple_call, iterations)


if __name__ == "__main__":
    main()
