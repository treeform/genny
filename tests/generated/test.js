const koffi = require('koffi');
const path = require('path');

// Determine library path based on platform.
let libName;
if (process.platform === 'win32') {
  libName = 'test.dll';
} else if (process.platform === 'darwin') {
  libName = 'libtest.dylib';
} else {
  libName = 'libtest.so';
}

const lib = koffi.load(path.join(__dirname, libName));

class testException extends Error {
  constructor(message) {
    super(message);
    this.name = 'testException';
  }
}

const test_simple_call = lib.func('test_simple_call', 'int64', ['int64']);
const test_simple_ref_obj_unref = lib.func('test_simple_ref_obj_unref', 'void', ['uint64']);
const test_new_simple_ref_obj = lib.func('test_new_simple_ref_obj', 'uint64', []);
const test_simple_ref_obj_get_simple_ref_a = lib.func('test_simple_ref_obj_get_simple_ref_a', 'int64', ['uint64']);
const test_simple_ref_obj_set_simple_ref_a = lib.func('test_simple_ref_obj_set_simple_ref_a', 'void', ['uint64', 'int64']);
const test_simple_ref_obj_get_simple_ref_b = lib.func('test_simple_ref_obj_get_simple_ref_b', 'uint8', ['uint64']);
const test_simple_ref_obj_set_simple_ref_b = lib.func('test_simple_ref_obj_set_simple_ref_b', 'void', ['uint64', 'uint8']);
const test_simple_ref_obj_doit = lib.func('test_simple_ref_obj_doit', 'void', ['uint64']);
const test_seq_int_unref = lib.func('test_seq_int_unref', 'void', ['uint64']);
const test_new_seq_int = lib.func('test_new_seq_int', 'uint64', []);
const test_seq_int_len = lib.func('test_seq_int_len', 'int64', ['uint64']);
const test_seq_int_get = lib.func('test_seq_int_get', 'int64', ['uint64', 'int64']);
const test_seq_int_set = lib.func('test_seq_int_set', 'void', ['uint64', 'int64', 'int64']);
const test_seq_int_delete = lib.func('test_seq_int_delete', 'void', ['uint64', 'int64']);
const test_seq_int_add = lib.func('test_seq_int_add', 'void', ['uint64', 'int64']);
const test_seq_int_clear = lib.func('test_seq_int_clear', 'void', ['uint64']);
const test_ref_obj_with_seq_unref = lib.func('test_ref_obj_with_seq_unref', 'void', ['uint64']);
const test_new_ref_obj_with_seq = lib.func('test_new_ref_obj_with_seq', 'uint64', []);
const test_ref_obj_with_seq_data_len = lib.func('test_ref_obj_with_seq_data_len', 'int64', ['uint64']);
const test_ref_obj_with_seq_data_get = lib.func('test_ref_obj_with_seq_data_get', 'uint8', ['uint64', 'int64']);
const test_ref_obj_with_seq_data_set = lib.func('test_ref_obj_with_seq_data_set', 'void', ['uint64', 'int64', 'uint8']);
const test_ref_obj_with_seq_data_delete = lib.func('test_ref_obj_with_seq_data_delete', 'void', ['uint64', 'int64']);
const test_ref_obj_with_seq_data_add = lib.func('test_ref_obj_with_seq_data_add', 'void', ['uint64', 'uint8']);
const test_ref_obj_with_seq_data_clear = lib.func('test_ref_obj_with_seq_data_clear', 'void', ['uint64']);
const test_simple_obj_with_proc_extra_proc = lib.func('test_simple_obj_with_proc_extra_proc', 'void', ['uint64']);
const test_seq_string_unref = lib.func('test_seq_string_unref', 'void', ['uint64']);
const test_new_seq_string = lib.func('test_new_seq_string', 'uint64', []);
const test_seq_string_len = lib.func('test_seq_string_len', 'int64', ['uint64']);
const test_seq_string_get = lib.func('test_seq_string_get', 'str', ['uint64', 'int64']);
const test_seq_string_set = lib.func('test_seq_string_set', 'void', ['uint64', 'int64', 'str']);
const test_seq_string_delete = lib.func('test_seq_string_delete', 'void', ['uint64', 'int64']);
const test_seq_string_add = lib.func('test_seq_string_add', 'void', ['uint64', 'str']);
const test_seq_string_clear = lib.func('test_seq_string_clear', 'void', ['uint64']);
const test_get_datas = lib.func('test_get_datas', 'uint64', []);

/**
 * Returns the integer passed in.
 */
function simpleCall(a) {
  return test_simple_call(a);
}

const SimpleObj = koffi.struct('SimpleObj', {
  simpleA: 'int64',
  simpleB: 'uint8',
  simpleC: 'bool'
});

function simpleObj(simple_a, simple_b, simple_c) {
  return {
    simpleA: simple_a,
    simpleB: simple_b,
    simpleC: simple_c
  };
}

class SimpleRefObj {
  constructor(ref) {
    this.ref = ref;
  }
  isNull() {
    return this.ref === 0n || this.ref === 0;
  }
  isEqual(other) {
    return this.ref === other.ref;
  }
}
function newSimpleRefObj() {
  const ref = test_new_simple_ref_obj();
  return new SimpleRefObj(ref);
}

Object.defineProperty(SimpleRefObj.prototype, 'simpleRefA', {
  get: function() { return test_simple_ref_obj_get_simple_ref_a(this.ref); },
  set: function(v) { test_simple_ref_obj_set_simple_ref_a(this.ref, v); }
});
Object.defineProperty(SimpleRefObj.prototype, 'simpleRefB', {
  get: function() { return test_simple_ref_obj_get_simple_ref_b(this.ref); },
  set: function(v) { test_simple_ref_obj_set_simple_ref_b(this.ref, v); }
});

/**
 * Does some thing with SimpleRefObj.
 */
SimpleRefObj.prototype.doit = function() {
  test_simple_ref_obj_doit(this.ref);
}

class SeqInt {
  constructor(ref) {
    this.ref = ref;
  }
  isNull() {
    return this.ref === 0n || this.ref === 0;
  }
  isEqual(other) {
    return this.ref === other.ref;
  }
}
function newSeqInt() {
  return new SeqInt(test_new_seq_int());
}

SeqInt.prototype.length = function() {
  return test_seq_int_len(this.ref);
};
SeqInt.prototype.get = function(index) {
  return test_seq_int_get(this.ref, index);
};
SeqInt.prototype.set = function(index, value) {
  test_seq_int_set(this.ref, index, value);
};
SeqInt.prototype.delete = function(index) {
  test_seq_int_delete(this.ref, index);
};
SeqInt.prototype.add = function(value) {
  test_seq_int_add(this.ref, value);
};
SeqInt.prototype.clear = function() {
  test_seq_int_clear(this.ref);
};
class RefObjWithSeq {
  constructor(ref) {
    this.ref = ref;
  }
  isNull() {
    return this.ref === 0n || this.ref === 0;
  }
  isEqual(other) {
    return this.ref === other.ref;
  }
}
function newRefObjWithSeq() {
  const ref = test_new_ref_obj_with_seq();
  return new RefObjWithSeq(ref);
}

class RefObjWithSeqData {
  constructor(refObjWithSeq) {
    this.refObjWithSeq = refObjWithSeq;
  }
}
RefObjWithSeqData.prototype.length = function() {
  return test_ref_obj_with_seq_data_len(this.refObjWithSeq.ref);
};
RefObjWithSeqData.prototype.get = function(index) {
  return test_ref_obj_with_seq_data_get(this.refObjWithSeq.ref, index);
};
RefObjWithSeqData.prototype.set = function(index, value) {
  test_ref_obj_with_seq_data_set(this.refObjWithSeq.ref, index, value);
};
RefObjWithSeqData.prototype.delete = function(index) {
  test_ref_obj_with_seq_data_delete(this.refObjWithSeq.ref, index);
};
RefObjWithSeqData.prototype.add = function(value) {
  test_ref_obj_with_seq_data_add(this.refObjWithSeq.ref, value);
};
RefObjWithSeqData.prototype.clear = function() {
  test_ref_obj_with_seq_data_clear(this.refObjWithSeq.ref);
};
Object.defineProperty(RefObjWithSeq.prototype, 'data', {
  get: function() { return new RefObjWithSeqData(this); }
});

const SimpleObjWithProc = koffi.struct('SimpleObjWithProc', {
  simpleA: 'int64',
  simpleB: 'uint8',
  simpleC: 'bool'
});

function simpleObjWithProc(simple_a, simple_b, simple_c) {
  return {
    simpleA: simple_a,
    simpleB: simple_b,
    simpleC: simple_c
  };
}

function simpleObjWithProcExtraProc(s) {
  test_simple_obj_with_proc_extra_proc(s);
}

class SeqString {
  constructor(ref) {
    this.ref = ref;
  }
  isNull() {
    return this.ref === 0n || this.ref === 0;
  }
  isEqual(other) {
    return this.ref === other.ref;
  }
}
function newSeqString() {
  return new SeqString(test_new_seq_string());
}

SeqString.prototype.length = function() {
  return test_seq_string_len(this.ref);
};
SeqString.prototype.get = function(index) {
  return test_seq_string_get(this.ref, index);
};
SeqString.prototype.set = function(index, value) {
  test_seq_string_set(this.ref, index, value);
};
SeqString.prototype.delete = function(index) {
  test_seq_string_delete(this.ref, index);
};
SeqString.prototype.add = function(value) {
  test_seq_string_add(this.ref, value);
};
SeqString.prototype.clear = function() {
  test_seq_string_clear(this.ref);
};
function getDatas() {
  return test_get_datas();
}


exports.SIMPLE_CONST = 123;
exports.SimpleEnum = 'int8';
exports.FIRST = 0;
exports.SECOND = 1;
exports.THIRD = 2;
exports.simpleCall = simpleCall;
exports.SimpleObj = SimpleObj;
exports.simpleObj = simpleObj;
exports.SimpleRefObj = SimpleRefObj;
exports.newSimpleRefObj = newSimpleRefObj;
exports.SeqInt = SeqInt;
exports.newSeqInt = newSeqInt;
exports.RefObjWithSeq = RefObjWithSeq;
exports.newRefObjWithSeq = newRefObjWithSeq;
exports.SimpleObjWithProc = SimpleObjWithProc;
exports.simpleObjWithProc = simpleObjWithProc;
exports.simpleObjWithProcExtraProc = simpleObjWithProcExtraProc;
exports.SeqString = SeqString;
exports.newSeqString = newSeqString;
exports.getDatas = getDatas;
