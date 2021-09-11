proc test_simple_call*(a: int): int {.raises: [], cdecl, exportc, dynlib.} =
  simpleCall(a)

proc test_simple_ref_obj_unref*(x: SimpleRefObj) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc test_new_simple_ref_obj*(): SimpleRefObj {.raises: [], cdecl, exportc, dynlib.} =
  newSimpleRefObj()

proc test_simple_ref_obj_get_simple_ref_a*(simple_ref_obj: SimpleRefObj): int {.raises: [], cdecl, exportc, dynlib.} =
  simple_ref_obj.simpleRefA

proc test_simple_ref_obj_set_simple_ref_a*(simple_ref_obj: SimpleRefObj, simpleRefA: int) {.raises: [], cdecl, exportc, dynlib.} =
  simple_ref_obj.simpleRefA = simpleRefA

proc test_simple_ref_obj_get_simple_ref_b*(simple_ref_obj: SimpleRefObj): byte {.raises: [], cdecl, exportc, dynlib.} =
  simple_ref_obj.simpleRefB

proc test_simple_ref_obj_set_simple_ref_b*(simple_ref_obj: SimpleRefObj, simpleRefB: byte) {.raises: [], cdecl, exportc, dynlib.} =
  simple_ref_obj.simpleRefB = simpleRefB

proc test_simple_ref_obj_doit*(s: SimpleRefObj) {.raises: [], cdecl, exportc, dynlib.} =
  doit(s)

type SeqInt* = ref object
  s: seq[int]

proc test_new_seq_int*(): SeqInt {.raises: [], cdecl, exportc, dynlib.} =
  SeqInt()

proc test_seq_int_len*(s: SeqInt): int {.raises: [], cdecl, exportc, dynlib.} =
  s.s.len

proc test_seq_int_add*(s: SeqInt, v: int) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.add(v)

proc test_seq_int_get*(s: SeqInt, i: int): int {.raises: [], cdecl, exportc, dynlib.} =
  s.s[i]

proc test_seq_int_set*(s: SeqInt, i: int, v: int) {.raises: [], cdecl, exportc, dynlib.} =
  s.s[i] = v

proc test_seq_int_delete*(s: SeqInt, i: int) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.delete(i)

proc test_seq_int_clear*(s: SeqInt) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.setLen(0)

proc test_seq_int_unref*(s: SeqInt) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(s)

