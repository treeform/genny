import macros, strformat, strutils

const basicTypes* = [
  "bool",
  "int8",
  "uint8",
  "int16",
  "uint16",
  "int32",
  "uint32",
  "int64",
  "uint64",
  "int",
  "uint",
  "float32",
  "float64",
  "float"
]

proc toSnakeCase*(s: string): string =
  ## Converts NimType to nim_type.
  var prevCap = false
  for i, c in s:
    if c in {'A' .. 'Z'}:
      if result.len > 0 and result[^1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c

proc toCapSnakeCase*(s: string): string =
  ## Converts NimType to NIM_TYPE.
  var prevCap = false
  for i, c in s:
    if c in {'A' .. 'Z'}:
      if result.len > 0 and result[^1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
    else:
      prevCap = false
    result.add c.toUpperAscii()

proc toCamelCase*(s: string): string =
  ## Converts nim_type to NimType.
  var cap = true
  for i, c in s:
    if c == '_':
      cap = true
    else:
      if cap:
        result.add c.toUpperAscii()
        cap = false
      else:
        result.add c

proc toVarCase*(s: string): string =
  ## Converts NimType to nimType.
  var i = 0
  while i < s.len:
    if s[i] notin {'A' .. 'Z'}:
      break

    result.add s[i].toLowerAscii()
    inc i

  if i < s.len:
    result.add s[i .. ^1]

proc getName*(sym: NimNode): string =
  if sym.kind == nnkSym:
    let impl = sym.getImpl()
    if impl.kind == nnkProcDef and impl[5].kind != nnkEmpty:
      # generic procedure instance
      # for now, just add every type to the name
      #
      # we could only add the generic one, but that requires smart
      # matching between the impl & the TypeInst
      var res= sym.repr
      for param in sym.getTypeInst()[0][1..^1]:
        res &= capitalizeAscii(param[1].getName())
      res
    else:
      sym.repr
  elif sym.kind == nnkBracketExpr:
    for gen in sym:
      result &= capitalizeAscii(gen.getName())
    result
  else:
    sym.repr

proc getSeqName*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    sym.getName()
  else:
    "Seq" & sym.getName()


proc raises*(procSym: NimNode): bool =
  for pragma in procSym.getImpl()[4]:
    if pragma.kind == nnkExprColonExpr and pragma[0].repr == "raises":
      return pragma[1].len > 0
