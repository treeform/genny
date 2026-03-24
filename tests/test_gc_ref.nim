## Tests that exported ref objects are properly prevented from premature GC
## collection via GC_ref in genny-generated constructors.

import
  std/[osproc, os, strutils],
  genny,
  test

block:
  ## Verify that an exported ref object survives GC collection.
  let obj = test_new_simple_ref_obj()
  GC_fullCollect()
  test_simple_ref_obj_set_simple_ref_a(obj, 42)
  assert test_simple_ref_obj_get_simple_ref_a(obj) == 42
  test_simple_ref_obj_unref(obj)
  echo "PASS: ref object survives GC collection"

block:
  ## Verify that an exported ref object with heap data survives GC collection
  ## and retains its contents after heavy allocation pressure.
  let obj = test_new_ref_obj_with_seq()
  for i in 0 ..< 100:
    test_ref_obj_with_seq_data_add(obj, byte(i mod 256))

  # Heavy allocation + GC to give ORC every opportunity to collect.
  for i in 0 ..< 10_000:
    discard newSeq[byte](1024)
  GC_fullCollect()

  # Object must still be intact with data length preserved.
  assert test_ref_obj_with_seq_data_len(obj) == 100,
    "RefObjWithSeq data was corrupted or collected by GC."
  assert test_ref_obj_with_seq_data_get(obj, 0) == 0
  assert test_ref_obj_with_seq_data_get(obj, 99) == 99
  test_ref_obj_with_seq_unref(obj)
  echo "PASS: ref object with seq data survives GC collection"

block:
  ## Compile and run test_gc_ref_segfault.nim which reproduces the original bug:
  ## a ref object created without GC_ref, held only as a raw pointer.
  ## The subprocess should crash, proving the bug exists without the fix.
  let
    thisDir = parentDir(currentSourcePath())
    segfaultSrc = thisDir / "test_gc_ref_segfault.nim"
    segfaultBin = thisDir / "test_gc_ref_segfault"

  # Compile the segfault test.
  let (compileOutput, compileExit) = execCmdEx(
    "nim c --gc:orc -d:gennyNim -d:gennyPython -d:gennyNode -d:gennyC -d:gennyCpp -d:gennyZig " & segfaultSrc
  )
  assert compileExit == 0, "Failed to compile segfault test:\n" & compileOutput

  # Run it and expect a crash.
  let (runOutput, runExit) = execCmdEx(segfaultBin)
  assert runExit != 0, "Expected crash from missing GC_ref, but process exited cleanly."
  echo "PASS: missing GC_ref causes crash (exit code: " & $runExit & ")"
