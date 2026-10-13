## Library for the Java hot reload test. Built several times with different
## defines; the loader comes from the generated C built with
## -DGENNY_JAVA_HOT_RELOAD.
import genny

const reloadVersion {.intdefine.} = 1

type
  Box* = ref object
    value*: int

proc newBox(value: int): Box =
  Box(value: value)

exportRefObject Box:
  fields:
    value
  constructor:
    newBox(int)

proc version(): int =
  reloadVersion

proc bonus(): int =
  7

when defined(reloadDropSymbol):
  # Same API without `bonus`: a loader built from the full API rejects it.
  exportProcs:
    version
  writeFiles("tests/generated_java_reload_drop", "TestReload")
  include generated_java_reload_drop/internal
else:
  exportProcs:
    version
    bonus
  writeFiles("tests/generated_java_reload", "TestReload")
  include generated_java_reload/internal
