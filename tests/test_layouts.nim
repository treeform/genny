import
  std/[complex, macros, os],
  genny

const GeneratedDir = getTempDir() / "genny_layouts_test"

type
  Packed[T] = object
    data: array[3, T]
  Packed32 = Packed[float32]
  ForeignComplex = object
    re, im: float32
  ForeignPacked = object
    values: array[3, float32]

proc newPacked(): Packed32 =
  ## Creates a value with a private backing array.
  Packed32(data: [1.0'f, 2.0'f, 3.0'f])

proc `==`(a, b: Packed32): bool =
  ## Distinguishes native overloaded equality from exported field equality.
  false

proc sumValues(values: openArray[int]): int =
  ## Sums values accepted through a sequence binding.
  for value in values:
    result += value

proc consume(value: sink string): int =
  ## Returns the length of an owned string argument.
  value.len

exportObject complex.Complex32:
  fields:
    re: float32
    im: float32
  procs:
    `+`(Complex32, Complex32)

exportObject Packed32:
  fields:
    values: array[3, float32]
  constructor:
    newPacked()

exportSeq seq[int]:
  discard

exportProcs:
  `+`(Complex32, Complex32)
  sumValues
  consume

writeFiles(GeneratedDir, "layouts")

macro includeBindings(): untyped =
  ## Loads generated declarations without writing into the source checkout.
  parseStmt(readFile(GeneratedDir / "internal.nim"))

includeBindings()

doAssert sizeof(Complex32) == sizeof(ForeignComplex)
doAssert alignof(Complex32) == alignof(ForeignComplex)
doAssert sizeof(Packed32) == sizeof(ForeignPacked)
doAssert alignof(Packed32) == alignof(ForeignPacked)
let
  first = layouts_complex32(1.0'f, 2.0'f)
  second = layouts_complex32(3.0'f, 4.0'f)
  combined = layouts_complex32_add(first, second)
  packed = layouts_packed32()
  values = layouts_new_seq_int()
doAssert combined.re == 4.0'f and combined.im == 6.0'f
doAssert layouts_complex32_eq(combined, complex32(4.0'f, 6.0'f))
doAssert not (packed == newPacked())
doAssert layouts_packed32_eq(packed, newPacked())
doAssert cast[ForeignPacked](packed).values == [1.0'f, 2.0'f, 3.0'f]
layouts_seq_int_add(values, 4)
layouts_seq_int_add(values, 7)
doAssert layouts_sum_values(values) == 11
doAssert layouts_consume("owned") == 5
