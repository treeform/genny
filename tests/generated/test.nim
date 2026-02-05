import bumpy, chroma, unicode, vmath

export bumpy, chroma, unicode, vmath

when defined(windows):
  const libName = "test.dll"
elif defined(macosx):
  const libName = "libtest.dylib"
else:
  const libName = "libtest.so"

{.push dynlib: libName.}

type testError = object of ValueError

const simpleConst* = 123

type SimpleEnum* = enum
  First
  Second
  Third

type SimpleObj* = object
  simpleA*: int
  simpleB*: byte
  simpleC*: bool

proc simpleObj*(simple_a: int, simple_b: byte, simple_c: bool): SimpleObj =
  result.simple_a = simple_a
  result.simple_b = simple_b
  result.simple_c = simple_c

type SimpleRefObj* = object
  reference: pointer

proc test_simple_ref_obj_unref(x: pointer) {.importc: "test_simple_ref_obj_unref", cdecl.}

proc `=destroy`(x: var SimpleRefObj) =
  if x.reference != nil:
    test_simple_ref_obj_unref(x.reference)
    x.reference = nil

type SeqInt* = object
  reference: pointer

proc test_seq_int_unref(x: pointer) {.importc: "test_seq_int_unref", cdecl.}

proc `=destroy`(x: var SeqInt) =
  if x.reference != nil:
    test_seq_int_unref(x.reference)
    x.reference = nil

type RefObjWithSeq* = object
  reference: pointer

proc test_ref_obj_with_seq_unref(x: pointer) {.importc: "test_ref_obj_with_seq_unref", cdecl.}

proc `=destroy`(x: var RefObjWithSeq) =
  if x.reference != nil:
    test_ref_obj_with_seq_unref(x.reference)
    x.reference = nil

type SimpleObjWithProc* = object
  simpleA*: int
  simpleB*: byte
  simpleC*: bool

proc simpleObjWithProc*(simple_a: int, simple_b: byte, simple_c: bool): SimpleObjWithProc =
  result.simple_a = simple_a
  result.simple_b = simple_b
  result.simple_c = simple_c

type SeqString* = object
  reference: pointer

proc test_seq_string_unref(x: pointer) {.importc: "test_seq_string_unref", cdecl.}

proc `=destroy`(x: var SeqString) =
  if x.reference != nil:
    test_seq_string_unref(x.reference)
    x.reference = nil

proc test_simple_call(a: int): int {.importc: "test_simple_call", cdecl.}

proc simpleCall*(a: int): int {.inline.} =
  result = test_simple_call(a)

proc test_new_simple_ref_obj(): pointer {.importc: "test_new_simple_ref_obj", cdecl.}

proc newSimpleRefObj*(): SimpleRefObj {.inline.} =
  result = SimpleRefObj(reference: test_new_simple_ref_obj())

proc test_simple_ref_obj_get_simple_ref_a(simpleRefObj: pointer): int {.importc: "test_simple_ref_obj_get_simple_ref_a", cdecl.}

proc simpleRefA*(simpleRefObj: SimpleRefObj): int {.inline.} =
  test_simple_ref_obj_get_simple_ref_a(simpleRefObj.reference)

proc test_simple_ref_obj_set_simple_ref_a(simpleRefObj: pointer, simpleRefA: int) {.importc: "test_simple_ref_obj_set_simple_ref_a", cdecl.}

proc `simpleRefA=`*(simpleRefObj: SimpleRefObj, simpleRefA: int) =
  test_simple_ref_obj_set_simple_ref_a(simpleRefObj.reference, simpleRefA)

proc test_simple_ref_obj_get_simple_ref_b(simpleRefObj: pointer): byte {.importc: "test_simple_ref_obj_get_simple_ref_b", cdecl.}

proc simpleRefB*(simpleRefObj: SimpleRefObj): byte {.inline.} =
  test_simple_ref_obj_get_simple_ref_b(simpleRefObj.reference)

proc test_simple_ref_obj_set_simple_ref_b(simpleRefObj: pointer, simpleRefB: byte) {.importc: "test_simple_ref_obj_set_simple_ref_b", cdecl.}

proc `simpleRefB=`*(simpleRefObj: SimpleRefObj, simpleRefB: byte) =
  test_simple_ref_obj_set_simple_ref_b(simpleRefObj.reference, simpleRefB)

proc test_simple_ref_obj_doit(s: pointer) {.importc: "test_simple_ref_obj_doit", cdecl.}

proc doit*(s: SimpleRefObj) {.inline.} =
  test_simple_ref_obj_doit(s.reference)

proc test_seq_int_len(s: pointer): int {.importc: "test_seq_int_len", cdecl.}

proc len*(s: SeqInt): int =
  test_seq_int_len(s.reference)

proc test_seq_int_add(s: pointer, v: int) {.importc: "test_seq_int_add", cdecl.}

proc add*(s: SeqInt, v: int) =
  test_seq_int_add(s.reference, v)

proc test_seq_int_get(s: pointer, i: int): int {.importc: "test_seq_int_get", cdecl.}

proc `[]`*(s: SeqInt, i: int): int =
  test_seq_int_get(s.reference, i)

proc test_seq_int_set(s: pointer, i: int, v: int) {.importc: "test_seq_int_set", cdecl.}

proc `[]=`*(s: SeqInt, i: int, v: int) =
  test_seq_int_set(s.reference, i, v)

proc test_seq_int_delete(s: pointer, i: int) {.importc: "test_seq_int_delete", cdecl.}

proc delete*(s: SeqInt, i: int) =
  test_seq_int_delete(s.reference, i)

proc test_seq_int_clear(s: pointer) {.importc: "test_seq_int_clear", cdecl.}

proc clear*(s: SeqInt) =
  test_seq_int_clear(s.reference)

proc test_new_seq_int*(): pointer {.importc: "test_new_seq_int", cdecl.}

proc newSeqInt*(): SeqInt =
  SeqInt(reference: test_new_seq_int())

proc test_new_ref_obj_with_seq(): pointer {.importc: "test_new_ref_obj_with_seq", cdecl.}

proc newRefObjWithSeq*(): RefObjWithSeq {.inline.} =
  result = RefObjWithSeq(reference: test_new_ref_obj_with_seq())

type RefObjWithSeqData = object
    refObjWithSeq: RefObjWithSeq

proc data*(refObjWithSeq: RefObjWithSeq): RefObjWithSeqData =
  RefObjWithSeqData(refObjWithSeq: refObjWithSeq)

proc test_ref_obj_with_seq_data_len(s: pointer): int {.importc: "test_ref_obj_with_seq_data_len", cdecl.}

proc len*(s: RefObjWithSeqData): int =
  test_ref_obj_with_seq_data_len(s.refObjWithSeq.reference)

proc test_ref_obj_with_seq_data_add(s: pointer, v: byte) {.importc: "test_ref_obj_with_seq_data_add", cdecl.}

proc add*(s: RefObjWithSeqData, v: byte) =
  test_ref_obj_with_seq_data_add(s.refObjWithSeq.reference, v)

proc test_ref_obj_with_seq_data_get(s: pointer, i: int): byte {.importc: "test_ref_obj_with_seq_data_get", cdecl.}

proc `[]`*(s: RefObjWithSeqData, i: int): byte =
  test_ref_obj_with_seq_data_get(s.refObjWithSeq.reference, i)

proc test_ref_obj_with_seq_data_set(s: pointer, i: int, v: byte) {.importc: "test_ref_obj_with_seq_data_set", cdecl.}

proc `[]=`*(s: RefObjWithSeqData, i: int, v: byte) =
  test_ref_obj_with_seq_data_set(s.refObjWithSeq.reference, i, v)

proc test_ref_obj_with_seq_data_delete(s: pointer, i: int) {.importc: "test_ref_obj_with_seq_data_delete", cdecl.}

proc delete*(s: RefObjWithSeqData, i: int) =
  test_ref_obj_with_seq_data_delete(s.refObjWithSeq.reference, i)

proc test_ref_obj_with_seq_data_clear(s: pointer) {.importc: "test_ref_obj_with_seq_data_clear", cdecl.}

proc clear*(s: RefObjWithSeqData) =
  test_ref_obj_with_seq_data_clear(s.refObjWithSeq.reference)

proc test_simple_obj_with_proc_extra_proc(s: SimpleObjWithProc) {.importc: "test_simple_obj_with_proc_extra_proc", cdecl.}

proc extraProc*(s: SimpleObjWithProc) {.inline.} =
  test_simple_obj_with_proc_extra_proc(s)

proc test_seq_string_len(s: pointer): int {.importc: "test_seq_string_len", cdecl.}

proc len*(s: SeqString): int =
  test_seq_string_len(s.reference)

proc test_seq_string_add(s: pointer, v: string) {.importc: "test_seq_string_add", cdecl.}

proc add*(s: SeqString, v: string) =
  test_seq_string_add(s.reference, v)

proc test_seq_string_get(s: pointer, i: int): string {.importc: "test_seq_string_get", cdecl.}

proc `[]`*(s: SeqString, i: int): string =
  test_seq_string_get(s.reference, i)

proc test_seq_string_set(s: pointer, i: int, v: string) {.importc: "test_seq_string_set", cdecl.}

proc `[]=`*(s: SeqString, i: int, v: string) =
  test_seq_string_set(s.reference, i, v)

proc test_seq_string_delete(s: pointer, i: int) {.importc: "test_seq_string_delete", cdecl.}

proc delete*(s: SeqString, i: int) =
  test_seq_string_delete(s.reference, i)

proc test_seq_string_clear(s: pointer) {.importc: "test_seq_string_clear", cdecl.}

proc clear*(s: SeqString) =
  test_seq_string_clear(s.reference)

proc test_new_seq_string*(): pointer {.importc: "test_new_seq_string", cdecl.}

proc newSeqString*(): SeqString =
  SeqString(reference: test_new_seq_string())

proc test_get_datas(): pointer {.importc: "test_get_datas", cdecl.}

proc getDatas*(): SeqString {.inline.} =
  result = SeqString(reference: test_get_datas())

