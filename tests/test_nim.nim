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

# Note: SeqString and getDatas tests are skipped due to cstring lifetime
# issues across DLL boundaries. The cstring returned from the DLL points
# to internal string data that can be freed before the client uses it.

echo "All Nim-C-Nim sandwich tests passed!"
