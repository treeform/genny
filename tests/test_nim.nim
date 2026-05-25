## Test Nim-C-Nim sandwich bindings.
import generated/test

echo "Testing Nim-C-Nim sandwich"

echo "Testing simpleConst"
doAssert simpleConst == 123, "simpleConst should be 123"

echo "Testing SimpleEnum"
doAssert ord(First) == 0, "First should be 0"
doAssert ord(Second) == 1, "Second should be 1"
doAssert ord(Third) == 2, "Third should be 2"

echo "Testing simpleCall"
doAssert simpleCall(42) == 42, "simpleCall should return input"
doAssert simpleCall(0) == 0, "simpleCall should return 0"

echo "Testing SimpleObj"
let obj = simpleObj(10, 20, true)
doAssert obj.simpleA == 10, "simpleA should be 10"
doAssert obj.simpleB == 20, "simpleB should be 20"
doAssert obj.simpleC == true, "simpleC should be true"

echo "Testing SimpleRefObj"
block:
  let refObj = newSimpleRefObj()
  refObj.simpleRefA = 100
  doAssert refObj.simpleRefA == 100, "simpleRefA should be 100"
  refObj.simpleRefB = 50
  doAssert refObj.simpleRefB == 50, "simpleRefB should be 50"
  refObj.doit()

echo "Testing issue #54 ref object method lifetime"
proc issue54CrashAfterAccess() =
  var s2 = newSimpleRefObj()
  s2.simpleRefA = 3
  doAssert s2.simpleRefA == 3, "simpleRefA should first be 3"
  s2.simpleRefA = 8
  doAssert s2.simpleRefA == 8, "simpleRefA should update to 8"
  s2.doit()

issue54CrashAfterAccess()
doAssert simpleCall(42) == 42, "execution should continue after issue #54 regression"

echo "Testing SeqInt"
block:
  let seqInt = newSeqInt()
  doAssert seqInt.len == 0, "seqInt should be empty"
  seqInt.add(42)
  doAssert seqInt.len == 1, "seqInt should have 1 element"
  doAssert seqInt[0] == 42, "seqInt[0] should be 42"
  seqInt.add(100)
  doAssert seqInt.len == 2, "seqInt should have 2 elements"
  doAssert seqInt[1] == 100, "seqInt[1] should be 100"
  seqInt[0] = 99
  doAssert seqInt[0] == 99, "seqInt[0] should be 99 after set"
  seqInt.delete(0)
  doAssert seqInt.len == 1, "seqInt should have 1 element after delete"
  doAssert seqInt[0] == 100, "seqInt[0] should be 100 after delete"
  seqInt.clear()
  doAssert seqInt.len == 0, "seqInt should be empty after clear"

echo "Testing RefObjWithSeq"
block:
  let refObjWithSeq = newRefObjWithSeq()
  doAssert refObjWithSeq.data.len == 0, "data should be empty"
  refObjWithSeq.data.add(10)
  doAssert refObjWithSeq.data.len == 1, "data should have 1 element"
  doAssert refObjWithSeq.data[0] == 10, "data[0] should be 10"

echo "Testing SimpleObjWithProc"
let objWithProc = simpleObjWithProc(1, 2, false)
doAssert objWithProc.simpleA == 1, "simpleA should be 1"
objWithProc.extraProc()

echo "Testing external value object import"
let external = externalObj(7, true)
doAssert external.externalA == 7, "externalA should be 7"
doAssert external.externalB == true, "externalB should be true"

echo "Testing getMessage"
doAssert getMessage() == "alpha\0omega", "getMessage should preserve embedded NUL"

echo "Testing SeqString via getDatas"
block:
  let datas = getDatas()
  doAssert datas.len == 3, "datas should have 3 elements"
  doAssert datas[0] == "a", "datas[0] should be a"
  doAssert datas[1] == "b", "datas[1] should be b"
  doAssert datas[2] == "c", "datas[2] should be c"

echo "All Nim-C-Nim sandwich tests passed!"
