## Reproduces the original genny bug: a ref object returned across FFI
## without GC_ref, causing use-after-free when ORC collects it.
## This file is compiled and run as a subprocess by test_gc_ref.nim.

import
  genny,
  test

# Call the genny-generated constructor which now has GC_ref.
let obj = test_new_ref_obj_with_seq()
for i in 0 ..< 10:
  test_ref_obj_with_seq_data_add(obj, byte(i))

# Undo the GC_ref to reproduce the original bug: the constructor
# returned the object WITHOUT calling GC_ref.
GC_unref(obj)

# Now the ref has no Nim-side GC root — only the local `let obj` binding.
# But `let obj` is a ref on the stack, which keeps it alive during this scope.
# To simulate the FFI case (Python holding a raw integer, no stack ref),
# we need to trick Nim into not seeing the local ref.
# Cast to raw pointer and back to prevent the compiler from tracking it.
let raw = cast[uint64](obj)

# Force GC to collect — without GC_ref, the object is eligible for collection
# since the compiler may not see `raw` as a root.
GC_fullCollect()

# Allocate heavily to reuse the freed memory.
var junk: seq[seq[byte]]
for i in 0 ..< 50_000:
  junk.add newSeq[byte](64)
GC_fullCollect()

# Scribble over the memory to guarantee corruption.
let rawBytes = cast[ptr UncheckedArray[byte]](raw)
for i in 0 ..< 128:
  rawBytes[i] = 0xFF

# Reconstruct the ref and try to unref — simulates Python's __del__.
let dangling = cast[RefObjWithSeq](raw)
echo "data len: ", dangling.data.len
GC_unref(dangling)
