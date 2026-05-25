type ExternalObj* {.bycopy.} = object
  externalA*: int32
  externalB*: bool

proc externalObj*(externalA: int32, externalB: bool): ExternalObj =
  result.externalA = externalA
  result.externalB = externalB
