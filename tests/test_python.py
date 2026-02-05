"""Test Python bindings."""
import sys
sys.path.insert(0, "tests/generated")
import test

print("Testing Python bindings")

print("Testing simple_call")
assert test.simple_call(42) == 42, "simple_call should return input"
assert test.simple_call(0) == 0, "simple_call should return 0"

print("Testing SIMPLE_CONST")
assert test.SIMPLE_CONST == 123, "SIMPLE_CONST should be 123"

print("Testing SimpleObj")
obj = test.SimpleObj(10, 20, True)
assert obj.simple_a == 10, "simple_a should be 10"
assert obj.simple_b == 20, "simple_b should be 20"
assert obj.simple_c == True, "simple_c should be True"

print("Testing SimpleRefObj")
ref_obj = test.SimpleRefObj()
ref_obj.simple_ref_a = 100
assert ref_obj.simple_ref_a == 100, "simple_ref_a should be 100"
ref_obj.simple_ref_b = 50
assert ref_obj.simple_ref_b == 50, "simple_ref_b should be 50"
ref_obj.doit()

print("Testing SeqInt")
seq_int = test.SeqInt()
seq_int.append(1)
seq_int.append(2)
seq_int.append(3)
assert len(seq_int) == 3, "seq_int should have 3 elements"
assert seq_int[0] == 1, "seq_int[0] should be 1"
assert seq_int[1] == 2, "seq_int[1] should be 2"
assert seq_int[2] == 3, "seq_int[2] should be 3"
seq_int[1] = 20
assert seq_int[1] == 20, "seq_int[1] should be 20 after set"
del seq_int[0]
assert len(seq_int) == 2, "seq_int should have 2 elements after delete"
seq_int.clear()
assert len(seq_int) == 0, "seq_int should be empty after clear"

print("Testing get_datas")
datas = test.get_datas()
assert len(datas) == 3, "datas should have 3 elements"
assert datas[0] == "a", "datas[0] should be a"
assert datas[1] == "b", "datas[1] should be b"
assert datas[2] == "c", "datas[2] should be c"

print("All Python tests passed!")
