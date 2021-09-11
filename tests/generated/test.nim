import bumpy, chroma, unicode, vmath

export bumpy, chroma, unicode, vmath

when defined(windows):
  const libName = "test.dll"
elif defined(macosx):
  const libName = "libtest.dylib"
else:
  const libName = "libtest.so"

{.push dynlib: libName.}

type PixieError = object of ValueError

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

