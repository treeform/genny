var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

var dll = {};

function TestException(message) {
  this.message = message;
  this.name = 'TestException';
}

const SimpleEnum = 'int8'

/**
 * Returns the integer passed in.
 */
function simpleCall(a){
  result = dll.test_simple_call(a)
  return result
}

const SimpleObj = Struct({
  'simpleA':'int64',
  'simpleB':'int8',
  'simpleC':'bool'
})
simpleObj = function(simple_a, simple_b, simple_c){
  var v = new SimpleObj();
  v.simple_a = simple_a
  v.simple_b = simple_b
  v.simple_c = simple_c
  return v;
}
SimpleObj.prototype.isEqual = function(other){
  return self.simpleA == other.simpleA && self.simpleB == other.simpleB && self.simpleC == other.simpleC;
};

SimpleRefObj = Struct({'nimRef': 'uint64'});
SimpleRefObj.prototype.isNull = function(){
  return this.nimRef == 0;
};
SimpleRefObj.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
SimpleRefObj.prototype.unref = function(){
  return dll.test_simple_ref_obj_unref(this)
};
function newSimpleRefObj(){
  var result = dll.test_new_simple_ref_obj()
  return result
}
Object.defineProperty(SimpleRefObj.prototype, 'simpleRefA', {
  get: function() {return dll.test_simple_ref_obj_get_simple_ref_a(this)},
  set: function(v) {dll.test_simple_ref_obj_set_simple_ref_a(this, v)}
});
Object.defineProperty(SimpleRefObj.prototype, 'simpleRefB', {
  get: function() {return dll.test_simple_ref_obj_get_simple_ref_b(this)},
  set: function(v) {dll.test_simple_ref_obj_set_simple_ref_b(this, v)}
});

SeqInt = Struct({'nimRef': 'uint64'});
SeqInt.prototype.isNull = function(){
  return this.nimRef == 0;
};
SeqInt.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
SeqInt.prototype.unref = function(){
  return dll.test_seq_int_unref(this)
};
function seqInt(){
  return dll.test_new_seq_int();
}
SeqInt.prototype.length = function(){
  return dll.test_seq_int_len(this)
};
SeqInt.prototype.get = function(index){
  return dll.test_seq_int_get(this, index)
};
SeqInt.prototype.set = function(index, value){
  dll.test_seq_int_set(this, index, value)
};
SeqInt.prototype.delete = function(index){
  dll.test_seq_int_delete(this, index)
};
SeqInt.prototype.add = function(value){
  dll.test_seq_int_add(this, value)
};
SeqInt.prototype.clear = function(){
  dll.test_seq_int_clear(this)
};
RefObjWithSeq = Struct({'nimRef': 'uint64'});
RefObjWithSeq.prototype.isNull = function(){
  return this.nimRef == 0;
};
RefObjWithSeq.prototype.isEqual = function(other){
  return this.nimRef == other.nimRef;
};
RefObjWithSeq.prototype.unref = function(){
  return dll.test_ref_obj_with_seq_unref(this)
};
function newRefObjWithSeq(){
  var result = dll.test_new_ref_obj_with_seq()
  return result
}
function RefObjWithSeqData(refObjWithSeq){
  this.refObjWithSeq = refObjWithSeq;
}
RefObjWithSeqData.prototype.length = function(){
  return dll.test_ref_obj_with_seq_data_len(this.ref_obj_with_seq)
};
RefObjWithSeqData.prototype.get = function(index){
  return dll.test_ref_obj_with_seq_data_get(this.ref_obj_with_seq, index)
};
RefObjWithSeqData.prototype.set = function(index, value){
  dll.test_ref_obj_with_seq_data_set(this.ref_obj_with_seq, index, value)
};
RefObjWithSeqData.prototype.delete = function(index){
  dll.test_ref_obj_with_seq_data_delete(this.ref_obj_with_seq, index)
};
RefObjWithSeqData.prototype.add = function(value){
  dll.test_ref_obj_with_seq_data_add(this.ref_obj_with_seq, value)
};
RefObjWithSeqData.prototype.clear = function(){
  dll.test_ref_obj_with_seq_data_clear(this.ref_obj_with_seq)
};
Object.defineProperty(RefObjWithSeq.prototype, 'data', {
  get: function() {return new RefObjWithSeqData(this)},
});


var dllPath = ""
if(process.platform == "win32") {
  dllPath = __dirname + '/test.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/libtest.dylib'
} else {
  dllPath = __dirname + '/libtest.so'
}

dll = ffi.Library(dllPath, {
  'test_simple_call': ['int64', ['int64']],
  'test_simple_ref_obj_unref': ['void', [SimpleRefObj]],
  'test_new_simple_ref_obj': [SimpleRefObj, []],
  'test_simple_ref_obj_get_simple_ref_a': ['int64', [SimpleRefObj]],
  'test_simple_ref_obj_set_simple_ref_a': ['void', [SimpleRefObj, 'int64']],
  'test_simple_ref_obj_get_simple_ref_b': ['int8', [SimpleRefObj]],
  'test_simple_ref_obj_set_simple_ref_b': ['void', [SimpleRefObj, 'int8']],
  'test_seq_int_unref': ['void', [SeqInt]],
  'test_new_seq_int': [SeqInt, []],
  'test_seq_int_len': ['uint64', [SeqInt]],
  'test_seq_int_get': ['int64', [SeqInt, 'uint64']],
  'test_seq_int_set': ['void', [SeqInt, 'uint64', 'int64']],
  'test_seq_int_delete': ['void', [SeqInt, 'uint64']],
  'test_seq_int_add': ['void', [SeqInt, 'int64']],
  'test_seq_int_clear': ['void', [SeqInt]],
  'test_ref_obj_with_seq_unref': ['void', [RefObjWithSeq]],
  'test_new_ref_obj_with_seq': [RefObjWithSeq, []],
  'test_ref_obj_with_seq_data_len': ['uint64', [RefObjWithSeq]],
  'test_ref_obj_with_seq_data_get': ['int8', [RefObjWithSeq, 'uint64']],
  'test_ref_obj_with_seq_data_set': ['void', [RefObjWithSeq, 'uint64', 'int8']],
  'test_ref_obj_with_seq_data_delete': ['void', [RefObjWithSeq, 'uint64']],
  'test_ref_obj_with_seq_data_add': ['void', [RefObjWithSeq, 'int8']],
  'test_ref_obj_with_seq_data_clear': ['void', [RefObjWithSeq]],
});

exports.SIMPLE_CONST = 123
exports.SimpleEnum = SimpleEnum
exports.FIRST = 0
exports.SECOND = 1
exports.THIRD = 2
exports.simpleCall = simpleCall
exports.SimpleObj = SimpleObj;
exports.simpleObj = simpleObj;
exports.SimpleRefObjType = SimpleRefObj
exports.SimpleRefObj = newSimpleRefObj
exports.SeqIntType = SeqInt
exports.RefObjWithSeqType = RefObjWithSeq
exports.RefObjWithSeq = newRefObjWithSeq