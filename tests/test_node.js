// Test Node.js bindings.
const assert = require('assert');
const test = require('./generated/test.js');

console.log("Testing Node.js bindings");

console.log("Testing simpleCall");
console.assert(test.simpleCall(42) === 42, "simpleCall should return input");
console.assert(test.simpleCall(0) === 0, "simpleCall should return 0");

console.log("Testing exceptions");
console.assert(test.maybeMessage("hello", false) === "ok:hello", "maybeMessage should return on success");
console.assert(test.maybeNumber(7, false) === 7, "maybeNumber should return on success");
console.assert(test.checkError() === false, "checkError should start false");
assert.throws(
  () => test.maybeMessage("bad message", true),
  (err) => err instanceof test.testException && err.message.includes("bad message")
);
console.assert(test.checkError() === false, "thrown exception should consume the pending error");
assert.throws(
  () => test.maybeNumber(9, true),
  (err) => err instanceof test.testException && err.message.includes("bad number 9")
);

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

console.log("Testing getMessage");
console.assert(test.getMessage() === "alpha\0omega", "getMessage should preserve embedded NUL");

console.log("Testing getDatas");
const datas = test.getDatas();
console.assert(datas.length() === 3, "datas should have 3 elements");
console.assert(datas.get(0) === "a", "datas[0] should be a");
console.assert(datas.get(1) === "b", "datas[1] should be b");
console.assert(datas.get(2) === "c", "datas[2] should be c");

console.log("All Node.js tests passed!");
