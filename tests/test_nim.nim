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

echo "All Nim-C-Nim sandwich tests passed!"
