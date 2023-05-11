import ../common, macros, strformat, strutils

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

proc exportConstNim*(sym: NimNode) =
  let impl = sym.getImpl()
  types.add &"const {sym.repr}* = {impl[2].repr}\n"
  types.add "\n"

proc exportEnumNim*(sym: NimNode) =
  let symImpl = sym.getImpl()[2]
  types.add &"type {sym.repr}* = enum\n"
  for i, entry in symImpl[1 .. ^1]:
    types.add &"  {entry.repr}\n"
  types.add "\n"

proc exportProcNim*(
  sym: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = []
) =
  let
    procName = sym.repr
    procNameSnaked = toSnakeCase(procName)
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1]
    procReturn = procType[0][0]
    procRaises = sym.raises()

  var apiProcName = &"$lib_"
  if owner != nil:
    apiProcName.add &"{toSnakeCase(owner.getName())}_"
  for prefix in prefixes:
    apiProcName.add &"{toSnakeCase(prefix.getName())}_"
  apiProcName.add &"{procNameSnaked}"

  var defaults: seq[(string, NimNode)]
  for identDefs in sym.getImpl()[3][1 .. ^1]:
    let default = identDefs[^1]
    for entry in identDefs[0 .. ^3]:
      defaults.add((entry.repr, default))

  procs.add &"proc {apiProcName}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = owner
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
  for i, param in procParams:
    var paramType = param[1]
    if paramType.repr.endsWith(":type"):
      paramType = owner
    if param[^2].kind == nnkBracketExpr or paramType.repr.startsWith("Some"):
      procs.add &"{param[0].repr}: {exportTypeNim(paramType)}, "
    else:
      procs.add &"{param[0].repr}: {paramType}"
      if defaults[i][1].kind != nnkEmpty:
        procs.add &" = {defaults[i][1].repr}"
      procs.add ", "
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
    procs.add "    raise newException($LibError, $takeError())\n"
  procs.add "\n"

proc exportObjectNim*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  if objName in ["Vector2", "Matrix3", "Rect", "Color"]:
    return

  types.add &"type {objName}* = object\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"  {property.repr}: {identDefs[^2].repr}\n"
  types.add "\n"

  if constructor != nil:
    exportProcNim(constructor)
  else:
    types.add &"proc {toVarCase(objName)}*("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add &"{toSnakeCase(property[1].repr)}: {identDefs[^2].repr}, "
    types.removeSuffix ", "
    types.add &"): {objName} =\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add &"  result.{toSnakeCase(property[1].repr)} = "
        types.add &"{toSnakeCase(property[1].repr)}\n"
    types.add "\n"

proc genRefObject(objName: string) =
  types.add &"type {objName}Obj = object\n"
  types.add "  reference: pointer\n"
  types.add "\n"

  types.add &"type {objName}* = ref {objName}Obj\n"
  types.add "\n"

  let apiProcName = &"$lib_{toSnakeCase(objName)}_unref"
  types.add &"proc {apiProcName}(x: {objName}Obj)"
  types.add " {.importc: \""
  types.add &"{apiProcName}"
  types.add "\", cdecl.}"
  types.add "\n"
  types.add "\n"

  types.add &"proc `=destroy`(x: var {objName}Obj) =\n"
  types.add &"  $lib_{toSnakeCase(objName)}_unref(x)\n"
  types.add "\n"

proc genSeqProcs(objName, niceName, procPrefix, objSuffix, entryName: string) =
  procs.add &"proc {procPrefix}_len(s: {objName}): int"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_len"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc len*(s: {niceName}): int =\n"
  procs.add &"  {procPrefix}_len(s{objSuffix})\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_add"
  procs.add &"(s: {objName}, v: {entryName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_add"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc add*(s: {niceName}, v: {entryName}) =\n"
  procs.add &"  {procPrefix}_add(s{objSuffix}, v)\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_get"
  procs.add &"(s: {objName}, i: int)"
  procs.add &": {entryName}"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_get"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc `[]`*(s: {niceName}, i: int): {entryName} =\n"
  procs.add &"  {procPrefix}_get(s{objSuffix}, i)\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_set(s: {objName}, "
  procs.add &"i: int, v: {entryName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_set"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc `[]=`*(s: {niceName}, i: int, v: {entryName}) =\n"
  procs.add &"  {procPrefix}_set(s{objSuffix}, i, v)\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_delete(s: {objName}, i: int)"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_delete"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc delete*(s: {niceName}, i: int) =\n"
  procs.add &"  {procPrefix}_delete(s{objSuffix}, i)\n"
  procs.add "\n"

  procs.add &"proc {procPrefix}_clear(s: {objName})"
  procs.add " {.importc: \""
  procs.add &"{procPrefix}_clear"
  procs.add "\", cdecl.}\n"
  procs.add "\n"

  procs.add &"proc clear*(s: {niceName}) =\n"
  procs.add &"  {procPrefix}_clear(s{objSuffix})\n"
  procs.add "\n"

proc exportRefObjectNim*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let
    objName = sym.getName()
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  genRefObject(objName)

  if constructor != nil:
    exportProcNim(constructor)

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"

      procs.add &"proc {getProcName}("
      procs.add &"{toVarCase(objName)}: {objName}): "
      procs.add exportTypeNim(fieldType)
      procs.add " {.importc: \""
      procs.add &"{getProcName}"
      procs.add "\", cdecl.}"
      procs.add "\n"
      procs.add "\n"

      procs.add &"proc {fieldName}*("
      procs.add &"{toVarCase(objName)}: {objName}): "
      procs.add &"{exportTypeNim(fieldType)}"
      procs.add " {.inline.} =\n"
      procs.add &"  {getProcName}({toVarCase(objName)})"
      procs.add convertImportToNim(fieldType)
      procs.add "\n"
      procs.add "\n"

      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      procs.add &"proc {setProcName}("
      procs.add &"{toVarCase(objName)}: {objName}, "
      procs.add &"{fieldName}: {exportTypeNim(fieldType)})"
      procs.add " {.importc: \""
      procs.add &"{setProcName}"
      procs.add "\", cdecl.}"
      procs.add "\n"
      procs.add "\n"

      procs.add &"proc `{fieldName}=`*("
      procs.add &"{toVarCase(objName)}: {objName}, "
      procs.add &"{fieldName}: {fieldType.repr}) =\n"
      procs.add &"  {setProcName}({toVarCase(objName)}, "
      procs.add &"{fieldName}{convertExportFromNim(fieldType)})"
      procs.add "\n"
      procs.add "\n"
    else:
      var helperName = fieldName
      helperName[0] = toUpperAscii(helperName[0])
      helperName = objName & helperName

      procs.add &"type {helperName} = object\n"
      procs.add &"    {toVarCase(objName)}: {objName}\n"
      procs.add "\n"

      procs.add &"proc {fieldName}*("
      procs.add &"{toVarCase(objName)}: {objName}"
      procs.add &"): {helperName} =\n"
      procs.add &"  {helperName}({toVarCase(objName)}: {toVarCase(objName)})\n"
      procs.add "\n"

      genSeqProcs(
        objName,
        helperName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        &".{toVarCase(objName)}",
        fieldType[1].repr
      )

proc exportSeqNim*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)
  genSeqProcs(
    seqName,
    seqName,
    &"$lib_{seqNameSnaked}",
    "",
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

when defined(windows):
  const libName = "$lib.dll"
elif defined(macosx):
  const libName = "lib$lib.dylib"
else:
  const libName = "lib$lib.so"

{.push dynlib: libName.}

type $LibError = object of ValueError

"""

proc writeNim*(dir, lib: string) =
  writeFile( &"{dir}/{toSnakeCase(lib)}.nim", (header & types & procs)
    .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
