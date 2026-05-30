import genny, generated/external_types

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

type testError = object of ValueError

var lastError: ref testError

proc takeError(): string =
  if lastError == nil:
    return ""
  result = lastError.msg
  lastError = nil

proc checkError(): bool =
  lastError != nil

proc maybeMessage(message: string, fail: bool): string {.raises: [testError].} =
  if fail:
    raise newException(testError, message)
  "ok:" & message

proc maybeNumber(value: int, fail: bool): int {.raises: [testError].} =
  if fail:
    raise newException(testError, "bad number " & $value)
  value

exportProcs:
  simpleCall
  checkError
  takeError
  maybeMessage
  maybeNumber

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

exportObject external_types.ExternalObj:
  discard

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

proc getMessage(): string =
  "alpha\0omega"

exportSeq seq[string]:
  discard

exportProcs:
  getDatas
  getMessage

writeFiles("tests/generated", "test")

include generated/internal
