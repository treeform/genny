## Test Nim-C-Nim sandwich bindings.
import generated/test

echo "Testing Nim-C-Nim sandwich"

echo "Testing simpleCall"
doAssert simpleCall(42) == 42, "simpleCall should return input"
doAssert simpleCall(0) == 0, "simpleCall should return 0"

echo "Testing SimpleObj"
let obj = simpleObj(10, 20, true)
doAssert obj.simpleA == 10, "simpleA should be 10"
doAssert obj.simpleB == 20, "simpleB should be 20"
doAssert obj.simpleC == true, "simpleC should be true"

echo "Testing SimpleRefObj"
let refObj = newSimpleRefObj()
refObj.simpleRefA = 100
doAssert refObj.simpleRefA == 100, "simpleRefA should be 100"
refObj.simpleRefB = 50
doAssert refObj.simpleRefB == 50, "simpleRefB should be 50"
refObj.doit()

echo "Testing SeqInt"
let seqInt = newSeqInt()
seqInt.add(1)
seqInt.add(2)
seqInt.add(3)
doAssert seqInt.len == 3, "seqInt should have 3 elements"
doAssert seqInt[0] == 1, "seqInt[0] should be 1"
doAssert seqInt[1] == 2, "seqInt[1] should be 2"
doAssert seqInt[2] == 3, "seqInt[2] should be 3"
seqInt[1] = 20
doAssert seqInt[1] == 20, "seqInt[1] should be 20 after set"
seqInt.delete(0)
doAssert seqInt.len == 2, "seqInt should have 2 elements after delete"
seqInt.clear()
doAssert seqInt.len == 0, "seqInt should be empty after clear"

echo "Testing getDatas"
let datas = getDatas()
doAssert datas.len == 3, "datas should have 3 elements"
echo "datas[0] = '", datas[0], "'"
doAssert $datas[0] == "a", "datas[0] should be a"
doAssert $datas[1] == "b", "datas[1] should be b"
doAssert $datas[2] == "c", "datas[2] should be c"

echo "All Nim-C-Nim sandwich tests passed!"
