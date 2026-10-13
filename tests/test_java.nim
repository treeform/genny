import genny

const
  javaLongConst = 123
  javaDoubleConst = 1.5
  javaStringConst = "genny"
  javaTypedConst = 42'i32
  javaUnsignedConst = 0xFFFF_FFFF'u32
  javaBoolConst = true
  javaFloatConst = 0.25'f32
  javaEscapedConst = "a\0b\"\\\né😀"

exportConsts:
  javaLongConst
  javaDoubleConst
  javaStringConst
  javaTypedConst
  javaUnsignedConst
  javaBoolConst
  javaFloatConst
  javaEscapedConst

var initCount {.noinit.}: int
inc initCount

proc addInts(a, b: int): int =
  a + b

proc addInt32s(a, b: int32): int32 =
  a + b

proc mulFloats(a, b: float32): float32 =
  a * b

proc mulDoubles(a, b: float): float =
  a * b

proc negate(a: bool): bool =
  not a

proc echoByte(a: byte): byte =
  a

proc greet(name: string): string =
  "Hello, " & name & "!"

proc helloWorld(): string =
  "Hello world from Nim!"

var callCount: int

proc bump() =
  inc callCount

proc getCallCount(): int =
  callCount

proc getInitCount(): int =
  initCount

proc utf8Len(s: string): int =
  s.len

proc invalidUtf8(): string =
  "a\xffb"

proc clampTo(x, default: int): int =
  if x < 0: default else: x

exportProcs:
  addInts
  addInt32s
  mulFloats
  mulDoubles
  negate
  echoByte
  greet
  helloWorld
  bump
  getCallCount
  getInitCount
  utf8Len
  invalidUtf8
  clampTo

type
  Color = enum
    Red
    Green
    Blue

  Vec = object
    x*, y*: float32

  Tile = object
    pos*: Vec
    color*: Color
    solid*: bool

  Level {.size: 4.} = enum
    Low = 1
    Mid = "mid"
    High = (10, "high")

  Reading = object
    level*: Level
    amount*: int32

  Big {.bycopy.} = object
    a*, b*, c*, d*: int64

  Tracker = object
    live: bool

  Counter* = ref object
    count*: int
    color*: Color
    history*: seq[int]
    data*: pointer
    tracker: Tracker

  TestJavaError = object of ValueError

var
  lastError: ref TestJavaError
  destroyedCount: int

proc `=destroy`(t: Tracker) =
  if t.live:
    inc destroyedCount

proc `=copy`(a: var Tracker, b: Tracker) {.error.}

exportEnums:
  Color
  Level

exportObject Vec:
  discard

exportObject Tile:
  discard

exportObject Reading:
  discard

exportObject Big:
  discard

proc nextColor(c: Color): Color =
  Color((c.ord + 1) mod 3)

proc moveTile(t: Tile, dx, dy: float32): Tile =
  result = t
  result.pos.x += dx
  result.pos.y += dy

proc newCounter(start: int): Counter =
  Counter(count: start)

proc bumpCounter(c: Counter) =
  inc c.count
  c.history.add c.count

proc scaled(c: Counter, by: int): int =
  c.count * by

proc scaled(c: Counter, by: int64): int =
  c.count * by.int * 2

exportRefObject Counter:
  fields:
    count
    color
    history
    data
  constructor:
    newCounter(int)
  procs:
    bumpCounter
    scaled(Counter, int)
    scaled(Counter, int64)

proc makeCounter(start: int): Counter =
  Counter(count: start, tracker: Tracker(live: true))

proc getDestroyedCount(): int =
  destroyedCount

proc sameCount(a, b: Counter): bool =
  a.count == b.count

proc nextLevel(l: Level): Level =
  if l == Low: Mid else: High

proc boostReading(r: Reading): Reading =
  Reading(level: nextLevel(r.level), amount: r.amount * 2)

proc sumBig(b: Big): int64 =
  b.a + b.b + b.c + b.d

proc makeBig(x: int64): Big =
  Big(a: x, b: x + 1, c: x + 2, d: x + 3)

proc words(): seq[string] =
  @["alpha", "beta"]

exportSeq seq[string]:
  discard

proc fillBuffer(buf: pointer, len: int, value: int32) =
  let bytes = cast[ptr UncheckedArray[int32]](buf)
  for i in 0 ..< len div 4:
    bytes[i] = value + i.int32

proc checkError(): bool =
  lastError != nil

proc takeError(): string =
  result = lastError.msg
  lastError = nil

proc failIfNegative(x: int): int {.raises: [TestJavaError].} =
  if x < 0:
    raise newException(TestJavaError, "negative: " & $x & " ✗")
  x

exportProcs:
  fillBuffer
  nextColor
  moveTile
  words
  checkError
  takeError
  failIfNegative
  makeCounter
  getDestroyedCount
  sameCount
  nextLevel
  boostReading
  sumBig
  makeBig

writeFiles("tests/generated_java", "TestJava")

include generated_java/internal
