import bindy/common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string

proc exportTypeNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr != "seq":
      error(&"Unexpected bracket expression {sym[0].repr}[", sym)
    result = sym.getSeqName()
  else:
    if sym.repr == "string":
      result = "cstring"
    elif sym.repr == "Rune":
      result = "int32"
    elif sym.repr.startsWith("Some"):
      result = sym.repr.replace("Some", "")
    else:
      result = sym.repr

proc convertExportFromNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    discard
  else:
    if sym.repr == "string":
      result = ".cstring"
    elif sym.repr == "Rune":
      result = ".int32"

proc convertImportToNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr != "seq":
      error(&"Unexpected bracket expression {sym[0].repr}[", sym)
    result = ".s"
  else:
    if sym.repr == "string":
      result = ".`$`"
    elif sym.repr == "Rune":
      result = ".Rune"

proc exportEnumNim*(sym: NimNode) =
  let symImpl = sym.getImpl()[2]

  types.add &"type {sym.repr}* = enum\n"
  for i, entry in symImpl[1 .. ^1]:
    types.add &"  {entry.repr}\n"
  types.add "\n"

proc exportProcNim*(sym: NimNode, prefixes: openarray[NimNode] = []) =
  let
    procName = sym.repr
    procNameSnaked = toSnakeCase(procName)
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1]
    procReturn = procType[0][0]
    procRaises = sym.raises()

  var apiProcName = &"$lib_"
  if prefixes.len > 0:
    for prefix in prefixes:
      apiProcName.add &"{toSnakeCase(prefix.getName())}_"
  apiProcName.add &"{procNameSnaked}"

  procs.add &"proc {apiProcName}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = prefixes[0]
      procs.add &"{toSnakeCase(param[i].repr)}: {exportTypeNim(paramType)}, "
  procs.removeSuffix ", "
  procs.add ")"
  if procReturn.kind != nnkEmpty:
    procs.add &": {exportTypeNim(procReturn)}"
  procs.add " {.importc: \""
  procs.add &"{apiProcName}"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procName}*("
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = prefixes[0]
      if param[^2].kind == nnkBracketExpr or paramType.repr.startsWith("Some"):
        procs.add &"{param[i].repr}: {exportTypeNim(paramType)}, "
      else:
        procs.add &"{param[i].repr}: {paramType}, "
  procs.removeSuffix ", "
  procs.add ")"
  if procReturn.kind != nnkEmpty:
    procs.add &": {exportTypeNim(procReturn)}"
  procs.add " {.inline.} =\n"
  if procReturn.kind != nnkEmpty:
    procs.add "  result = "
  else:
    procs.add "  "
  procs.add &"{apiProcName}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      procs.add &"{param[i].repr}{convertExportFromNim(param[^2])}, "
  procs.removeSuffix ", "
  procs.add ")\n"
  if procRaises:
    procs.add "  if checkError():\n"
    procs.add "    raise newException(PixieError, $takeError())\n"
  procs.add "\n"

proc exportObjectNim*(sym: NimNode) =
  let
    objName = sym.repr
    objType = sym.getType()

  if objName in ["Vector2", "Matrix3", "Rectangle", "Color"]:
    return

  types.add &"type {objName}* = object\n"
  for property in objType[2]:
    types.add &"  {property.repr}*: {property.getTypeInst().repr}\n"
  types.add "\n"

proc genRefObject(objName: string) =
  types.add &"type {objName}* = object\n"
  types.add "  reference: pointer\n"
  types.add "\n"

  let apiProcName = &"$lib_{toSnakeCase(objName)}_unref"
  types.add &"proc {apiProcName}*(x: {objName})"
  types.add " {.importc: \""
  types.add &"{apiProcName}"
  types.add "\", cdecl.}"
  types.add "\n"
  types.add "\n"

  types.add &"proc `=destroy`(x: var {objName}) =\n"
  types.add &"  $lib_{toSnakeCase(objName)}_unref(x)\n"
  types.add "\n"

proc genSeqProcs(objName, procPrefix, entryName: string) =
  procs.add &"proc {procPrefix}_len(s: {objName}): int"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_len"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_add"
  procs.add &"(s: {objName}, v: {entryName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_add"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_get"
  procs.add &"(s: {objName}, i: int)"
  procs.add &": {entryName}"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_get"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_set(s: {objName}, "
  procs.add &"i: int, v: {entryName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_set"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_remove(s: {objName}, i: int)"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_remove"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_clear(s: {objName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_clear"
  procs.add "\", cdecl.}"
  procs.add "\n"
  procs.add "\n"

proc exportRefObjectNim*(sym: NimNode, whitelist: openarray[string]) =
  let
    objName = sym.getName()
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1][1].getType()

  genRefObject(objName)

  if sym.kind == nnkBracketExpr:
    return

  for property in objType[2]:
    if not property.isExported:
      continue
    if whitelist != ["*"] and property.repr notin whitelist:
      continue

    let
      propertyName = property.repr
      propertyNameSnaked = toSnakeCase(propertyName)
      propertyType = property.getTypeInst()

    if propertyType.kind == nnkBracketExpr:
      let procPrefix = &"$lib_{objNameSnaked}_{propertyNameSnaked}"
      genSeqProcs(objName, procPrefix, propertyType[1].repr)
    else:
      let getProcName = &"$lib_{objNameSnaked}_get_{propertyNameSnaked}"

      types.add &"proc {getProcName}("
      types.add &"{toVarCase(objName)}: {objName}): "
      types.add exportTypeNim(propertyType)
      types.add " {.importc: \""
      types.add &"{getProcName}"
      types.add "\", cdecl.}"
      types.add "\n"
      types.add "\n"

      types.add &"proc {propertyName}*("
      types.add &"{toVarCase(objName)}: {objName}): "
      types.add &"{exportTypeNim(propertyType)}"
      types.add " {.inline.} =\n"
      types.add &"  {getProcName}({toVarCase(objName)})"
      types.add convertImportToNim(propertyType)
      types.add "\n"
      types.add "\n"

      let setProcName = &"$lib_{objNameSnaked}_set_{propertyNameSnaked}"

      types.add &"proc {setProcName}("
      types.add &"{toVarCase(objName)}: {objName}, "
      types.add &"{propertyName}: {exportTypeNim(propertyType)})"
      types.add " {.importc: \""
      types.add &"{setProcName}"
      types.add "\", cdecl.}"
      types.add "\n"
      types.add "\n"

      types.add &"proc `{propertyName}=`*("
      types.add &"{toVarCase(objName)}: {objName}, "
      types.add &"{propertyName}: {propertyType.repr}) =\n"
      types.add &"  {setProcName}({toVarCase(objName)}, "
      types.add &"{propertyName}{convertExportFromNim(propertyType)})"
      types.add "\n"
      types.add "\n"

proc exportSeqNim*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)
  genSeqProcs(
    seqName,
    &"$lib_{seqNameSnaked}",
    sym[1].repr
  )

  let newSeqProcName = &"$lib_new_{seqNameSnaked}"

  procs.add &"proc {newSeqProcName}*(): {seqName}"
  procs.add " {.importc: \""
  procs.add newSeqProcName
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc new{seqName}*(): {seqName} =\n"
  procs.add &"  {newSeqProcName}()\n"
  procs.add "\n"

const header = """
import bumpy, chroma, unicode, vmath

export bumpy, chroma, unicode, vmath

{.push dynlib: "$lib.dll".}

type PixieError = object of ValueError

"""

proc writeNim*(dir, lib: string) =
  writeFile(&"{dir}/{lib}.nim", (header & types & procs).replace("$lib", lib))