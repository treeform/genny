"""Exercise explicit layouts and generic signatures through native Python."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "generated"))
import layouts  # noqa: E402

left = layouts.Complex32(1, 2)
right = layouts.Complex32(3, 4)
combined = left.add(right)
assert (combined.re, combined.im) == (4, 6)
assert combined == layouts.Complex32(4, 6)
assert layouts.add(left, right) == combined

packed = layouts.Packed32()
assert packed.values == [1, 2, 3]
packed.values = [4, 5, 6]
assert packed.values == [4, 5, 6]

values = layouts.SeqInt()
values.add(4)
values.add(7)
assert layouts.sum_values(values) == 11
assert layouts.consume("owned") == 5
print("Native Python layout regressions passed")
