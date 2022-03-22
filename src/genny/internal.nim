import common, languages/nim, macros, strformat, strutils

const exportProcPragmas = "{.raises: [], cdecl, exportc, dynlib.}"

var internal {.compiletime.}: string

proc exportConstInternal*(sym: NimNode) =
  discard

proc exportEnumInternal*(sym: NimNode) =
  discard

proc exportProcInternal*(
  sym: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = []
) =
  let
    procName = getName(sym)
    procNameSnaked = toSnakeCase(procName)
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1]
    procReturn = procType[0][0]
    procRaises = sym.raises()
    procReturnsSeq = procReturn.kind == nnkBracketExpr and procReturn[0].repr == "seq"

  var apiProcName = &"$lib_"
  if owner != nil:
    apiProcName.add &"{toSnakeCase(owner.getName())}_"
  for prefix in prefixes:
    apiProcName.add &"{toSnakeCase(prefix.getName())}_"
  apiProcName.add &"{procNameSnaked}"

  internal.add &"proc {apiProcName}*("
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = prefixes[0]
      internal.add &"{toSnakeCase(param[i].repr)}: {exportTypeNim(paramType)}, "
  internal.removeSuffix ", "
  internal.add ")"
  if procReturn.kind != nnkEmpty:
    internal.add &": {exportTypeNim(procReturn)}"
  internal.add &" {exportProcPragmas} =\n"
  if procRaises:
    internal.add "  try:\n  "
  if procRaises and procReturn.kind != nnkEmpty:
    internal.add "  result = "
  else:
    internal.add "  "
  if procReturnsSeq:
    internal.add &"{procReturn.getSeqName()}(s: "
  internal.add &"{sym.repr}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      internal.add &"{toSnakeCase(param[i].repr)}"
      internal.add &"{convertImportToNim(param[^2])}, "
  internal.removeSuffix ", "
  internal.add ")"
  if procReturnsSeq:
    internal.add ")"
  if procReturn.kind != nnkEmpty:
    internal.add convertExportFromNim(procReturn)
  if procRaises:
    internal.add "\n"
    internal.add "  except $LibError as e:\n"
    internal.add "    lastError = e"
  internal.add "\n"
  internal.add "\n"

proc exportObjectInternal*(sym: NimNode, constructor: NimNode) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)

  if constructor != nil:
    let constructorType = constructor.getTypeInst()

    internal.add &"proc $lib_{objNameSnaked}*("
    for param in constructorType[0][1 .. ^1]:
      internal.add &"{param[0].repr.split('`')[0]}: {param[1].repr}, "
    internal.removeSuffix ", "
    internal.add &"): {objName} {exportProcPragmas} =\n"
    internal.add &"  {constructor.repr}("
    for param in constructorType[0][1 .. ^1]:
      internal.add &"{param[0].repr.split('`')[0]}, "
    internal.removeSuffix ", "
    internal.add ")\n"
    internal.add "\n"
  else:
    internal.add &"proc $lib_{objNameSnaked}*("
    let objType = sym.getType()
    for fieldSym in objType[2]:
      let
        fieldName = fieldSym.repr
        fieldType = fieldSym.getTypeInst()
      internal.add &"{toSnakeCase(fieldName)}: {exportTypeNim(fieldType)}, "
    internal.removeSuffix ", "
    internal.add &"): {objName} {exportProcPragmas} =\n"
    for fieldSym in objType[2]:
      let
        fieldName = fieldSym.repr
      internal.add &"  result.{toSnakeCase(fieldName)} = {toSnakeCase(fieldName)}\n"
    internal.add "\n"

  internal.add &"proc $lib_{objNameSnaked}_eq*(a, b: {objName}): bool {exportProcPragmas}=\n"
  let objType = sym.getType()
  internal.add "  "
  for fieldSym in objType[2]:
    let
      fieldName = fieldSym.repr
    internal.add &"a.{toSnakeCase(fieldName)} == b.{toSnakeCase(fieldName)} and "
  internal.removeSuffix " and "
  internal.add "\n\n"

proc exportRefObjectInternal*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let
    objName = getName(sym)
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  internal.add &"proc $lib_{objNameSnaked}_unref*(x: {repr(sym)}) {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  GC_unref(x)\n"
  internal.add "\n"

  if constructor != nil:
    exportProcInternal(constructor)

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      internal.add "proc "
      internal.add &"$lib_{objNameSnaked}_get_{fieldNameSnaked}*"
      internal.add &"({objNameSnaked}: {objName}): {exportTypeNim(fieldType)}"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}"
      internal.add convertExportFromNim(fieldType)
      internal.add "\n"
      internal.add "\n"

      internal.add "proc "
      internal.add &"$lib_{objNameSnaked}_set_{fieldNameSnaked}*"
      internal.add &"({objNameSnaked}: {objName}, "
      internal.add &"{fieldName}: {exportTypeNim(fieldType)})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName} = {fieldName}"
      internal.add convertImportToNim(fieldType)
      internal.add "\n"
      internal.add "\n"
    else:
      let prefix = &"$lib_{objNameSnaked}_{fieldNameSnaked}"

      internal.add &"proc {prefix}_len*({objNameSnaked}: {objName}): int"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}.len\n"
      internal.add "\n"

      internal.add &"proc {prefix}_add*({objNameSnaked}: {objName}, v: {fieldType[1].repr})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}.add(v)\n"
      internal.add "\n"

      internal.add &"proc {prefix}_get*({objNameSnaked}: {objName}, i: int): {fieldType[1].repr}"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}[i]\n"
      internal.add "\n"

      internal.add &"proc {prefix}_set*({objNameSnaked}: {objName}, i: int, v: {fieldType[1].repr})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}[i] = v\n"
      internal.add "\n"

      internal.add &"proc {prefix}_delete*({objNameSnaked}: {objName}, i: int)"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}.delete(i)\n"
      internal.add "\n"

      internal.add &"proc {prefix}_clear*({objNameSnaked}: {objName})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{fieldName}.setLen(0)\n"
      internal.add "\n"

proc generateSeqs(sym: NimNode) =
  let
    seqName = sym.getSeqName()
    seqNameSnaked = toSnakeCase(seqName)

  internal.add &"type {seqName}* = ref object\n"
  internal.add &"  s: {sym.repr}\n"
  internal.add "\n"

  internal.add &"proc $lib_new_{seqNameSnaked}*(): {seqName}"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add &"  {seqName}()\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_len*(s: {seqName}): int"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s.len\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_add*(s: {seqName}, v: {exportTypeNim(sym[1])})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add &"  s.s.add(v{convertImportToNim(sym[1])})\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_get*(s: {seqName}, i: int): {exportTypeNim(sym[1])}"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add &"  s.s[i]{convertExportFromNim(sym[1])}\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_set*(s: {seqName}, i: int, v: {exportTypeNim(sym[1])})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add &"  s.s[i] = v{convertImportToNim(sym[1])}\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_delete*(s: {seqName}, i: int)"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s.delete(i)\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_clear*(s: {seqName})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s.setLen(0)\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_unref*(s: {seqName})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  GC_unref(s)\n"
  internal.add "\n"

proc exportSeqInternal*(sym: NimNode) =
  generateSeqs(sym)

const header = """
when not defined(gcArc) and not defined(gcOrc):
  {.error: "Please use --gc:arc or --gc:orc when using Genny.".}

when (NimMajor, NimMinor, NimPatch) == (1, 6, 2):
  {.error: "Nim 1.6.2 not supported with Genny due to FFI issues.".}
"""

proc writeInternal*(dir, lib: string) =
  writeFile(
    &"{dir}/internal.nim",
    header & internal.replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
