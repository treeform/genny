// Test Node.js bindings.
const test = require('./generated/test.js');

console.log("Testing Node.js bindings");

console.log("Testing simpleCall");
console.assert(test.simpleCall(42) === 42, "simpleCall should return input");
console.assert(test.simpleCall(0) === 0, "simpleCall should return 0");

console.log("Testing SIMPLE_CONST");
console.assert(test.SIMPLE_CONST === 123, "SIMPLE_CONST should be 123");

console.log("Testing SimpleObj");
const obj = test.simpleObj(10, 20, true);
console.assert(obj.simpleA === 10, "simpleA should be 10");
console.assert(obj.simpleB === 20, "simpleB should be 20");
console.assert(obj.simpleC === true, "simpleC should be true");

console.log("Testing SimpleRefObj");
const refObj = test.newSimpleRefObj();
console.assert(!refObj.isNull(), "refObj should not be null");
refObj.simpleRefA = 100;
console.assert(refObj.simpleRefA === 100, "simpleRefA should be 100");
refObj.simpleRefB = 50;
console.assert(refObj.simpleRefB === 50, "simpleRefB should be 50");
refObj.doit();

console.log("Testing SeqInt");
const seqInt = test.newSeqInt();
console.assert(!seqInt.isNull(), "seqInt should not be null");
console.assert(seqInt.length() === 0, "seqInt should be empty");
seqInt.add(42);
console.assert(seqInt.length() === 1, "seqInt should have 1 element");
console.assert(seqInt.get(0) === 42, "seqInt[0] should be 42");

console.log("All Node.js tests passed!");
