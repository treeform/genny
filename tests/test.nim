import genny

const simpleConst = 123

exportConsts:
  simpleConst

type SimpleEnum = enum
  First
  Second
  Third

exportEnums:
  SimpleEnum

proc simpleCall(a: int): int =
  ## Returns the integer passed in.
  return a

exportProcs:
  simpleCall

type SimpleObj = object
  simpleA*: int
  simpleB*: byte
  simpleC*: bool

exportObject SimpleObj:
  discard

type SimpleRefObj* = ref object
  simpleRefA*: int
  simpleRefB*: byte
  simpleRefC*: bool

proc newSimpleRefObj(): SimpleRefObj =
  ## Creates new SimpleRefObj.
  SimpleRefObj()

proc doit*(s: SimpleRefObj) =
  ## Does some thing with SimpleRefObj.
  echo s.simpleRefA

exportRefObject SimpleRefObj:
  fields:
    simpleRefA
    simpleRefB
  constructor:
    newSimpleRefObj()
  procs:
    doit(SimpleRefObj)

exportSeq seq[int]:
  discard

type RefObjWithSeq* = ref object
  data*: seq[byte]

proc newRefObjWithSeq(): RefObjWithSeq =
  ## Creates new SimpleRefObj.
  RefObjWithSeq()

exportRefObject RefObjWithSeq:
  fields:
    data
  constructor:
    newRefObjWithSeq()

type SimpleObjWithProc = object
  simpleA*: int
  simpleB*: byte
  simpleC*: bool

proc extraProc(s: SimpleObjWithProc) =
  discard

exportObject SimpleObjWithProc:
  procs:
    extraProc

# type ArrayObj = object
#   arr1*: array[3, int]
#   arr2*: array[3, array[3, int]]
#   arr3*: array[3, array[3, array[3, int]]]

# exportObject ArrayObj:
#   discard

# proc arrayCall1(a: array[2, int]) =
#   discard

# proc arrayCall2(): array[2, int] =
#   discard

# proc arrayCall3(a: array[2, int]): array[2, int] =
#   discard

# proc arrayCall4(a: array[3, array[3, float32]]): array[3, array[3, float32]] =
#   discard

# exportProcs:
#   arrayCall1
#   arrayCall2
#   arrayCall3
#   arrayCall4

proc getDatas(): seq[string] =
  @["a", "b", "c"]

exportSeq seq[string]:
  discard

exportProcs:
  getDatas

writeFiles("tests/generated", "test")

include generated/internal
