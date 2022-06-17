when not defined(gcArc) and not defined(gcOrc):
  {.error: "Please use --gc:arc or --gc:orc when using Genny.".}

when (NimMajor, NimMinor, NimPatch) == (1, 6, 2):
  {.error: "Nim 1.6.2 not supported with Genny due to FFI issues.".}
proc test_simple_call*(a: int): int {.raises: [], cdecl, exportc, dynlib.} =
  simpleCall(a)

proc test_simple_obj*(simple_a: int, simple_b: byte, simple_c: bool): SimpleObj {.raises: [], cdecl, exportc, dynlib.} =
  result.simple_a = simple_a
  result.simple_b = simple_b
  result.simple_c = simple_c

proc test_simple_obj_eq*(a, b: SimpleObj): bool {.raises: [], cdecl, exportc, dynlib.}=
  a.simple_a == b.simple_a and a.simple_b == b.simple_b and a.simple_c == b.simple_c

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

proc test_ref_obj_with_seq_unref*(x: RefObjWithSeq) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc test_new_ref_obj_with_seq*(): RefObjWithSeq {.raises: [], cdecl, exportc, dynlib.} =
  newRefObjWithSeq()

proc test_ref_obj_with_seq_data_len*(ref_obj_with_seq: RefObjWithSeq): int {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data.len

proc test_ref_obj_with_seq_data_add*(ref_obj_with_seq: RefObjWithSeq, v: byte) {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data.add(v)

proc test_ref_obj_with_seq_data_get*(ref_obj_with_seq: RefObjWithSeq, i: int): byte {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data[i]

proc test_ref_obj_with_seq_data_set*(ref_obj_with_seq: RefObjWithSeq, i: int, v: byte) {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data[i] = v

proc test_ref_obj_with_seq_data_delete*(ref_obj_with_seq: RefObjWithSeq, i: int) {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data.delete(i)

proc test_ref_obj_with_seq_data_clear*(ref_obj_with_seq: RefObjWithSeq) {.raises: [], cdecl, exportc, dynlib.} =
  ref_obj_with_seq.data.setLen(0)

proc test_simple_obj_with_proc*(simple_a: int, simple_b: byte, simple_c: bool): SimpleObjWithProc {.raises: [], cdecl, exportc, dynlib.} =
  result.simple_a = simple_a
  result.simple_b = simple_b
  result.simple_c = simple_c

proc test_simple_obj_with_proc_eq*(a, b: SimpleObjWithProc): bool {.raises: [], cdecl, exportc, dynlib.}=
  a.simple_a == b.simple_a and a.simple_b == b.simple_b and a.simple_c == b.simple_c

proc test_simple_obj_with_proc_extra_proc*(s: SimpleObjWithProc) {.raises: [], cdecl, exportc, dynlib.} =
  extraProc(s)

type SeqString* = ref object
  s: seq[string]

proc test_new_seq_string*(): SeqString {.raises: [], cdecl, exportc, dynlib.} =
  SeqString()

proc test_seq_string_len*(s: SeqString): int {.raises: [], cdecl, exportc, dynlib.} =
  s.s.len

proc test_seq_string_add*(s: SeqString, v: cstring) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.add(v.`$`)

proc test_seq_string_get*(s: SeqString, i: int): cstring {.raises: [], cdecl, exportc, dynlib.} =
  s.s[i].cstring

proc test_seq_string_set*(s: SeqString, i: int, v: cstring) {.raises: [], cdecl, exportc, dynlib.} =
  s.s[i] = v.`$`

proc test_seq_string_delete*(s: SeqString, i: int) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.delete(i)

proc test_seq_string_clear*(s: SeqString) {.raises: [], cdecl, exportc, dynlib.} =
  s.s.setLen(0)

proc test_seq_string_unref*(s: SeqString) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(s)

proc test_get_datas*(): SeqString {.raises: [], cdecl, exportc, dynlib.} =
  SeqString(s: getDatas())

proc test_gen_simple_int*(a: int): GenSimple[int] {.raises: [], cdecl, exportc, dynlib.} =
  result.a = a

proc test_gen_simple_int_eq*(a, b: GenSimple[int]): bool {.raises: [], cdecl, exportc, dynlib.}=
  a.a == b.a

proc test_gen_ref_int_unref*(x: GenRef[int]) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc test_new_gen_ref_int*(v: int): GenRef[int] {.raises: [], cdecl, exportc, dynlib.} =
  newGenRef(v)

proc test_gen_ref_int_noop_gen_ref_int*(x: GenRef[int]): GenRef[int] {.raises: [], cdecl, exportc, dynlib.} =
  noop(x)

