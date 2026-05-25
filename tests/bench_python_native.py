"""Small non-gating native CPython extension call overhead benchmark."""

import importlib.util
import sys
import sysconfig
import time
from pathlib import Path


ROOT = Path(__file__).parent / "generated"
NATIVE_PATH = ROOT / ("test" + sysconfig.get_config_var("EXT_SUFFIX"))


def load_native():
    if not NATIVE_PATH.exists():
        raise SystemExit(f"Missing native extension: {NATIVE_PATH}")

    spec = importlib.util.spec_from_file_location("test", NATIVE_PATH)
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
    native = load_native()
    bench("native", native.simple_call, iterations)


if __name__ == "__main__":
    main()
