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

var objectFields {.compiletime.}: seq[(NimNode, NimNode)]

proc toSnakeCase*(s: string): string =
  ## Converts NimType to nim_type.
  case s
  of "+": return "add"
  of "-": return "sub"
  of "*": return "mul"
  of "/": return "div"
  else: discard
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

proc getSeqName*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    result = &"Seq{sym[1]}"
  else:
    result = &"Seq{sym}"
  result[3] = toUpperAscii(result[3])

proc getName*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    sym.getSeqName()
  else:
    sym.repr

proc raises*(procSym: NimNode): bool =
  for pragma in procSym.getImpl()[4]:
    if pragma.kind == nnkExprColonExpr and pragma[0].repr == "raises":
      return pragma[1].len > 0

proc setObjectFields*(sym, fields: NimNode) =
  ## Records the explicit exported layout of a value type.
  objectFields.add((sym, fields))

proc getObjectFields*(sym: NimNode): NimNode =
  ## Returns concrete fields with consistent exported-name nodes.
  var fields: NimNode
  for (name, entries) in objectFields:
    if name.repr == sym.repr:
      fields = entries
      break
  if fields == nil:
    let implementation = sym.getTypeImpl()
    if implementation.kind != nnkObjectTy:
      error("Expected an object type or explicit fields", sym)
    fields = implementation[2]
  result = newNimNode(nnkRecList)
  for entry in fields:
    if entry.kind != nnkIdentDefs:
      error("Expected a value field declaration", entry)
    let field = newNimNode(nnkIdentDefs)
    for name in entry[0 .. ^3]:
      let plainName =
        if name.kind == nnkPostfix:
          name[1].strVal
        else:
          name.strVal
      field.add newTree(nnkPostfix, ident("*"), ident(plainName))
    field.add entry[^2]
    field.add newEmptyNode()
    result.add field

proc resolveExportType*(sym: NimNode): NimNode =
  ## Preserves exported aliases when generic procedures expose concrete types.
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    return resolveExportType(sym[1])
  if sym.kind == nnkBracketExpr and sym[0].repr != "seq" and
    sym[0].repr != "array":
      for (name, fields) in objectFields:
        if sameType(sym, name):
          return name
  result = sym

proc exportedProcType*(sym: NimNode): NimNode =
  ## Resolves exported aliases in a procedure signature.
  result = sym.getTypeInst().copyNimTree()
  result[0][0] = resolveExportType(result[0][0])
  for i in 1 ..< result[0].len:
    for j in 0 ..< result[0][i].len - 2:
      result[0][i][j] = ident(result[0][i][j].strVal.split('`')[0])
    result[0][i][^2] = resolveExportType(result[0][i][^2])
