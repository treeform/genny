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
const refObj = test.SimpleRefObj();
refObj.simpleRefA = 100;
console.assert(refObj.simpleRefA === 100, "simpleRefA should be 100");
refObj.simpleRefB = 50;
console.assert(refObj.simpleRefB === 50, "simpleRefB should be 50");
refObj.doit();

console.log("Testing getDatas");
const datas = test.getDatas();
console.assert(datas.length() === 3, "datas should have 3 elements");
console.assert(datas.get(0) === "a", "datas[0] should be a");
console.assert(datas.get(1) === "b", "datas[1] should be b");
console.assert(datas.get(2) === "c", "datas[2] should be c");

console.log("All Node.js tests passed!");
