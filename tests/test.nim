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

writeFiles("tests/generated", "test")

include generated/internal
