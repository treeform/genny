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

type SimpleRefObjObj = object
  reference: pointer

type SimpleRefObj* = ref SimpleRefObjObj

proc test_simple_ref_obj_unref(x: SimpleRefObjObj) {.importc: "test_simple_ref_obj_unref", cdecl.}

proc `=destroy`(x: var SimpleRefObjObj) =
  test_simple_ref_obj_unref(x)

type SeqIntObj = object
  reference: pointer

type SeqInt* = ref SeqIntObj

proc test_seq_int_unref(x: SeqIntObj) {.importc: "test_seq_int_unref", cdecl.}

proc `=destroy`(x: var SeqIntObj) =
  test_seq_int_unref(x)

type RefObjWithSeqObj = object
  reference: pointer

type RefObjWithSeq* = ref RefObjWithSeqObj

proc test_ref_obj_with_seq_unref(x: RefObjWithSeqObj) {.importc: "test_ref_obj_with_seq_unref", cdecl.}

proc `=destroy`(x: var RefObjWithSeqObj) =
  test_ref_obj_with_seq_unref(x)

type SimpleObjWithProc* = object
  simpleA*: int
  simpleB*: byte
  simpleC*: bool

proc simpleObjWithProc*(simple_a: int, simple_b: byte, simple_c: bool): SimpleObjWithProc =
  result.simple_a = simple_a
  result.simple_b = simple_b
  result.simple_c = simple_c

type SeqStringObj = object
  reference: pointer

type SeqString* = ref SeqStringObj

proc test_seq_string_unref(x: SeqStringObj) {.importc: "test_seq_string_unref", cdecl.}

proc `=destroy`(x: var SeqStringObj) =
  test_seq_string_unref(x)

type GenRefIntObj = object
  reference: pointer

type GenRefInt* = ref GenRefIntObj

proc test_gen_ref_int_unref(x: GenRefIntObj) {.importc: "test_gen_ref_int_unref", cdecl.}

proc `=destroy`(x: var GenRefIntObj) =
  test_gen_ref_int_unref(x)

proc test_simple_call(a: int): int {.importc: "test_simple_call", cdecl.}

proc simpleCall*(a: int): int {.inline.} =
  result = test_simple_call(a)

proc test_new_simple_ref_obj(): SimpleRefObj {.importc: "test_new_simple_ref_obj", cdecl.}

proc newSimpleRefObj*(): SimpleRefObj {.inline.} =
  result = test_new_simple_ref_obj()

proc test_simple_ref_obj_get_simple_ref_a(simpleRefObj: SimpleRefObj): int {.importc: "test_simple_ref_obj_get_simple_ref_a", cdecl.}

proc simpleRefA*(simpleRefObj: SimpleRefObj): int {.inline.} =
  test_simple_ref_obj_get_simple_ref_a(simpleRefObj)

proc test_simple_ref_obj_set_simple_ref_a(simpleRefObj: SimpleRefObj, simpleRefA: int) {.importc: "test_simple_ref_obj_set_simple_ref_a", cdecl.}

proc `simpleRefA=`*(simpleRefObj: SimpleRefObj, simpleRefA: int) =
  test_simple_ref_obj_set_simple_ref_a(simpleRefObj, simpleRefA)

proc test_simple_ref_obj_get_simple_ref_b(simpleRefObj: SimpleRefObj): byte {.importc: "test_simple_ref_obj_get_simple_ref_b", cdecl.}

proc simpleRefB*(simpleRefObj: SimpleRefObj): byte {.inline.} =
  test_simple_ref_obj_get_simple_ref_b(simpleRefObj)

proc test_simple_ref_obj_set_simple_ref_b(simpleRefObj: SimpleRefObj, simpleRefB: byte) {.importc: "test_simple_ref_obj_set_simple_ref_b", cdecl.}

proc `simpleRefB=`*(simpleRefObj: SimpleRefObj, simpleRefB: byte) =
  test_simple_ref_obj_set_simple_ref_b(simpleRefObj, simpleRefB)

proc test_simple_ref_obj_doit(s: SimpleRefObj) {.importc: "test_simple_ref_obj_doit", cdecl.}

proc doit*(s: SimpleRefObj) {.inline.} =
  test_simple_ref_obj_doit(s)

proc test_seq_int_len(s: SeqInt): int {.importc: "test_seq_int_len", cdecl.}

proc len*(s: SeqInt): int =
  test_seq_int_len(s)

proc test_seq_int_add(s: SeqInt, v: int) {.importc: "test_seq_int_add", cdecl.}

proc add*(s: SeqInt, v: int) =
  test_seq_int_add(s, v)

proc test_seq_int_get(s: SeqInt, i: int): int {.importc: "test_seq_int_get", cdecl.}

proc `[]`*(s: SeqInt, i: int): int =
  test_seq_int_get(s, i)

proc test_seq_int_set(s: SeqInt, i: int, v: int) {.importc: "test_seq_int_set", cdecl.}

proc `[]=`*(s: SeqInt, i: int, v: int) =
  test_seq_int_set(s, i, v)

proc test_seq_int_delete(s: SeqInt, i: int) {.importc: "test_seq_int_delete", cdecl.}

proc delete*(s: SeqInt, i: int) =
  test_seq_int_delete(s, i)

proc test_seq_int_clear(s: SeqInt) {.importc: "test_seq_int_clear", cdecl.}

proc clear*(s: SeqInt) =
  test_seq_int_clear(s)

proc test_new_seq_int*(): SeqInt {.importc: "test_new_seq_int", cdecl.}

proc newSeqInt*(): SeqInt =
  test_new_seq_int()

proc test_new_ref_obj_with_seq(): RefObjWithSeq {.importc: "test_new_ref_obj_with_seq", cdecl.}

proc newRefObjWithSeq*(): RefObjWithSeq {.inline.} =
  result = test_new_ref_obj_with_seq()

type RefObjWithSeqData = object
    refObjWithSeq: RefObjWithSeq

proc data*(refObjWithSeq: RefObjWithSeq): RefObjWithSeqData =
  RefObjWithSeqData(refObjWithSeq: refObjWithSeq)

proc test_ref_obj_with_seq_data_len(s: RefObjWithSeq): int {.importc: "test_ref_obj_with_seq_data_len", cdecl.}

proc len*(s: RefObjWithSeqData): int =
  test_ref_obj_with_seq_data_len(s.refObjWithSeq)

proc test_ref_obj_with_seq_data_add(s: RefObjWithSeq, v: byte) {.importc: "test_ref_obj_with_seq_data_add", cdecl.}

proc add*(s: RefObjWithSeqData, v: byte) =
  test_ref_obj_with_seq_data_add(s.refObjWithSeq, v)

proc test_ref_obj_with_seq_data_get(s: RefObjWithSeq, i: int): byte {.importc: "test_ref_obj_with_seq_data_get", cdecl.}

proc `[]`*(s: RefObjWithSeqData, i: int): byte =
  test_ref_obj_with_seq_data_get(s.refObjWithSeq, i)

proc test_ref_obj_with_seq_data_set(s: RefObjWithSeq, i: int, v: byte) {.importc: "test_ref_obj_with_seq_data_set", cdecl.}

proc `[]=`*(s: RefObjWithSeqData, i: int, v: byte) =
  test_ref_obj_with_seq_data_set(s.refObjWithSeq, i, v)

proc test_ref_obj_with_seq_data_delete(s: RefObjWithSeq, i: int) {.importc: "test_ref_obj_with_seq_data_delete", cdecl.}

proc delete*(s: RefObjWithSeqData, i: int) =
  test_ref_obj_with_seq_data_delete(s.refObjWithSeq, i)

proc test_ref_obj_with_seq_data_clear(s: RefObjWithSeq) {.importc: "test_ref_obj_with_seq_data_clear", cdecl.}

proc clear*(s: RefObjWithSeqData) =
  test_ref_obj_with_seq_data_clear(s.refObjWithSeq)

proc test_simple_obj_with_proc_extra_proc(s: SimpleObjWithProc) {.importc: "test_simple_obj_with_proc_extra_proc", cdecl.}

proc extraProc*(s: SimpleObjWithProc) {.inline.} =
  test_simple_obj_with_proc_extra_proc(s)

proc test_seq_string_len(s: SeqString): int {.importc: "test_seq_string_len", cdecl.}

proc len*(s: SeqString): int =
  test_seq_string_len(s)

proc test_seq_string_add(s: SeqString, v: string) {.importc: "test_seq_string_add", cdecl.}

proc add*(s: SeqString, v: string) =
  test_seq_string_add(s, v)

proc test_seq_string_get(s: SeqString, i: int): string {.importc: "test_seq_string_get", cdecl.}

proc `[]`*(s: SeqString, i: int): string =
  test_seq_string_get(s, i)

proc test_seq_string_set(s: SeqString, i: int, v: string) {.importc: "test_seq_string_set", cdecl.}

proc `[]=`*(s: SeqString, i: int, v: string) =
  test_seq_string_set(s, i, v)

proc test_seq_string_delete(s: SeqString, i: int) {.importc: "test_seq_string_delete", cdecl.}

proc delete*(s: SeqString, i: int) =
  test_seq_string_delete(s, i)

proc test_seq_string_clear(s: SeqString) {.importc: "test_seq_string_clear", cdecl.}

proc clear*(s: SeqString) =
  test_seq_string_clear(s)

proc test_new_seq_string*(): SeqString {.importc: "test_new_seq_string", cdecl.}

proc newSeqString*(): SeqString =
  test_new_seq_string()

proc test_get_datas(): SeqString {.importc: "test_get_datas", cdecl.}

proc getDatas*(): SeqString {.inline.} =
  result = test_get_datas()

proc test_new_gen_ref_int(v: int): GenRef[int] {.importc: "test_new_gen_ref_int", cdecl.}

proc newGenRef*(v: int): GenRef[int] {.inline.} =
  result = test_new_gen_ref_int(v)

proc test_gen_ref_int_noop_gen_ref_int(x: GenRef[int]): GenRef[int] {.importc: "test_gen_ref_int_noop_gen_ref_int", cdecl.}

proc noop*(x: GenRef[int]): GenRef[int] {.inline.} =
  result = test_gen_ref_int_noop_gen_ref_int(x)

