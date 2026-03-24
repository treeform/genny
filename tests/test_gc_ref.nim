## Tests that exported ref objects are properly prevented from premature GC
## collection via GC_ref in genny-generated constructors.

import std/[osproc, os]
import genny

# Re-use the types and procs from test.nim.
import test

# When invoked with "--segfault-test", simulate the old broken codegen.
if paramCount() > 0 and paramStr(1) == "--segfault-test":
  # Create a ref object via the FFI constructor (which now has GC_ref).
  let obj = test_new_ref_obj_with_seq()
  for i in 0 ..< 10:
    test_ref_obj_with_seq_data_add(obj, byte(i))
  # Undo the GC_ref to simulate the OLD broken codegen (no GC_ref).
  GC_unref(obj)
  # The object now has refcount 0 from Nim's perspective.
  # Force ORC to destroy it.
  GC_fullCollect()
  # Scribble over the freed memory so any access crashes.
  let raw = cast[ptr UncheckedArray[byte]](obj)
  for i in 0 ..< 128:
    raw[i] = 0xFF
  # Attempt the unref that Python's __del__ would do — hits corrupted memory.
  test_ref_obj_with_seq_unref(obj)
  quit(0)

block:
  # Test that exported ref objects survive GC after GC_ref fix.
  let obj = test_new_simple_ref_obj()
  GC_fullCollect()
  test_simple_ref_obj_set_simple_ref_a(obj, 42)
  assert test_simple_ref_obj_get_simple_ref_a(obj) == 42
  test_simple_ref_obj_unref(obj)
  echo "PASS: ref object survives GC collection"

block:
  # Test that GC_ref is present by verifying the object isn't destroyed
  # after dropping all Nim-side references. Without GC_ref, the constructor
  # returns an object with refcount 0 that ORC can collect at any time.
  # With GC_ref, the refcount is 1 and the object survives until GC_unref.
  let obj = test_new_ref_obj_with_seq()
  for i in 0 ..< 100:
    test_ref_obj_with_seq_data_add(obj, byte(i mod 256))
  # Heavy allocation + GC to give ORC every opportunity to collect.
  for i in 0 ..< 10_000:
    discard newSeq[byte](1024)
  GC_fullCollect()
  # Object must still be intact — data length preserved.
  assert test_ref_obj_with_seq_data_len(obj) == 100,
    "RefObjWithSeq data was corrupted or collected by GC"
  assert test_ref_obj_with_seq_data_get(obj, 0) == 0
  assert test_ref_obj_with_seq_data_get(obj, 99) == 99
  test_ref_obj_with_seq_unref(obj)
  echo "PASS: ref object with seq data survives GC collection"

block:
  # Prove that without GC_ref, using a freed ref object crashes.
  # Runs the broken path in a subprocess so the test runner doesn't die.
  let exe = getAppFilename()
  let (output, exitCode) = execCmdEx(exe & " --segfault-test")
  assert exitCode != 0, "Expected crash from missing GC_ref, but process exited cleanly"
  echo "PASS: missing GC_ref causes crash (exit code: " & $exitCode & ")"
