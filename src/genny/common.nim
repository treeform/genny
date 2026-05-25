import macros, strformat, strutils

type ObjectField* = tuple[name: string, typ: NimNode]

var
  exportedValueTypes {.compiletime.}: seq[(string, NimNode)]
  exportedValueTypeAliases {.compiletime.}: seq[(string, string)]

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

proc stripSinkCommon(sym: NimNode): NimNode =
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc normalizeTypeRepr(s: string): string =
  s.replace("system.", "")

proc registerValueObjectTypeAliasRepr*(name, alias: string) =
  let normalizedAlias = alias.normalizeTypeRepr()
  for (existingAlias, existingName) in exportedValueTypeAliases:
    if existingAlias == normalizedAlias and existingName == name:
      return
  exportedValueTypeAliases.add((normalizedAlias, name))

proc registerValueObjectTypeAlias*(name: string, typ: NimNode) =
  registerValueObjectTypeAliasRepr(name, typ.repr)

proc registerValueObjectType*(sym: NimNode) =
  let name = sym.repr
  for (existingName, _) in exportedValueTypes:
    if existingName == name:
      return
  exportedValueTypes.add((name, sym))
  var aliases = @[sym.repr, sym.getTypeInst().repr, sym.getType().repr]
  let impl = sym.getImpl()
  if impl.kind == nnkTypeDef:
    aliases.add(impl[2].repr)
  for alias in aliases:
    registerValueObjectTypeAliasRepr(name, alias)

proc exportedValueTypeName*(sym: NimNode): string =
  let typ = sym.stripSinkCommon()
  let typRepr = typ.repr.normalizeTypeRepr()
  for (alias, name) in exportedValueTypeAliases:
    if typRepr == alias:
      return name
  for (name, exportedType) in exportedValueTypes:
    if typ.sameType(exportedType) or typ.sameType(exportedType.getTypeInst()):
      return name

proc getSeqName*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    result = &"Seq{sym[1]}"
  else:
    result = &"Seq{sym}"
  result[3] = toUpperAscii(result[3])

proc getName*(sym: NimNode): string =
  let valueName = sym.exportedValueTypeName()
  if valueName.len > 0:
    valueName
  elif sym.kind == nnkBracketExpr:
    sym.getSeqName()
  else:
    sym.repr

proc getParamName*(sym: NimNode): string =
  sym.repr.split("`")[0]

proc usePrefixName*(sym: NimNode): bool =
  if sym.kind != nnkSym:
    return true
  let impl = sym.getImpl()
  impl.kind != nnkNilLit and impl[2].kind != nnkEnumTy

proc arrayCount*(sym: NimNode): int =
  let bounds = sym[1].repr
  if ".." in bounds:
    let parts = bounds.split("..")
    parseInt(parts[1].strip()) - parseInt(parts[0].strip()) + 1
  else:
    parseInt(bounds)

proc normalizedOperatorName*(name: string): string =
  result = name
  result.removePrefix("`")
  result.removeSuffix("`")

proc isOperatorName*(name: string): bool =
  name.normalizedOperatorName() in ["+", "-", "*", "/"]

proc operatorProcName*(name: string): string =
  case name.normalizedOperatorName()
  of "+": "add"
  of "-": "sub"
  of "*": "mul"
  of "/": "div"
  else: name

proc nimCallableName*(name: string): string =
  let normalized = name.normalizedOperatorName()
  if normalized.isOperatorName:
    &"`{normalized}`"
  else:
    name

proc cppOperatorName*(name: string): string =
  "operator" & name.normalizedOperatorName()

proc pythonOperatorName*(name: string): string =
  case name.normalizedOperatorName()
  of "+": "__add__"
  of "-": "__sub__"
  of "*": "__mul__"
  of "/": "__truediv__"
  else: name

proc objectFieldName*(property: NimNode): string =
  if property.kind == nnkPostfix:
    property[1].repr
  else:
    property.repr

proc objectFields*(sym: NimNode, explicitFields: seq[ObjectField]): seq[ObjectField] =
  if explicitFields.len > 0:
    return explicitFields

  let typ = sym.getType()
  if typ.len > 2:
    for fieldSym in typ[2]:
      result.add((fieldSym.repr, fieldSym.getTypeInst()))

  if result.len == 0:
    let impl = sym.getImpl()
    if impl.kind == nnkTypeDef and impl[2].kind == nnkObjectTy:
      for identDefs in impl[2][2]:
        for property in identDefs[0 .. ^3]:
          result.add((property.objectFieldName(), identDefs[^2]))

proc raises*(procSym: NimNode): bool =
  for pragma in procSym.getImpl()[4]:
    if pragma.kind == nnkExprColonExpr and pragma[0].repr == "raises":
      return pragma[1].len > 0
