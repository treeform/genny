"""Test native CPython bindings."""

import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).parent / "generated"))
import test  # noqa: E402


def test_module_values():
    assert test.simple_call(42) == 42
    assert test.simple_call(0) == 0

    assert test.SIMPLE_CONST == 123
    assert test.FIRST == 0
    assert test.SECOND == 1
    assert test.THIRD == 2
    assert test.SimpleEnum is int


def test_value_objects():
    obj = test.SimpleObj(10, 20, True)
    assert obj.simple_a == 10
    assert obj.simple_b == 20
    assert obj.simple_c is True

    obj.simple_a = 11
    obj.simple_b = 21
    obj.simple_c = False
    assert obj == test.SimpleObj(11, 21, False)
    assert obj != test.SimpleObj(12, 21, False)


def test_ref_object_fields_and_methods():
    ref_obj = test.SimpleRefObj()
    assert bool(ref_obj)

    ref_obj.simple_ref_a = 100
    ref_obj.simple_ref_b = 50
    assert ref_obj.simple_ref_a == 100
    assert ref_obj.simple_ref_b == 50
    assert ref_obj.doit() is None


def test_seq_int():
    seq_int = test.SeqInt()
    seq_int.append(1)
    seq_int.add(2)
    seq_int.append(3)

    assert len(seq_int) == 3
    assert list(seq_int) == [1, 2, 3]

    seq_int[1] = 20
    assert seq_int[1] == 20

    del seq_int[0]
    assert list(seq_int) == [20, 3]

    seq_int.clear()
    assert len(seq_int) == 0


def test_seq_string_return():
    datas = test.get_datas()
    assert isinstance(datas, test.SeqString)
    assert len(datas) == 3
    assert list(datas) == ["a", "b", "c"]


def test_bound_seq_field():
    ref_obj = test.RefObjWithSeq()
    data = ref_obj.data
    data.append(5)
    data.add(6)

    assert len(data) == 2
    assert list(ref_obj.data) == [5, 6]

    data[0] = 7
    assert list(ref_obj.data) == [7, 6]

    del data[0]
    assert list(ref_obj.data) == [6]

    data.clear()
    assert len(ref_obj.data) == 0


def test_value_object_methods():
    obj = test.SimpleObjWithProc(1, 2, True)
    assert obj.extra_proc() is None


def main():
    for name, func in sorted(globals().items()):
        if name.startswith("test_") and callable(func):
            func()
    print("All native Python tests passed!")


if __name__ == "__main__":
    main()
