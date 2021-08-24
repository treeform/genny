import common, languages/nim, macros, strformat, strutils

const exportProcPragmas = "{.raises: [], cdecl, exportc, dynlib.}"

var dllapi {.compiletime.}: string

proc exportEnumDllApi*(sym: NimNode) =
  discard

proc exportProcDllApi*(sym: NimNode, prefixes: openarray[NimNode] = []) =
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

  dllapi.add &"proc {apiProcName}*("
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = prefixes[0]
      dllapi.add &"{toSnakeCase(param[i].repr)}: {exportTypeNim(paramType)}, "
  dllapi.removeSuffix ", "
  dllapi.add ")"
  if procReturn.kind != nnkEmpty:
    dllapi.add &": {exportTypeNim(procReturn)}"
  dllapi.add &" {exportProcPragmas} =\n"
  if procRaises:
    dllapi.add "  try:\n  "
  if procRaises and procReturn.kind != nnkEmpty:
    dllapi.add "  result = "
  else:
    dllapi.add "  "
  dllapi.add &"{procName}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      dllapi.add &"{toSnakeCase(param[i].repr)}"
      dllapi.add &"{convertImportToNim(param[^2])}, "
  dllapi.removeSuffix ", "
  dllapi.add ")"
  if procReturn.kind != nnkEmpty:
    dllapi.add convertExportFromNim(procReturn)
  if procRaises:
    dllapi.add "\n"
    dllapi.add "  except PixieError as e:\n"
    dllapi.add "    lastError = e"
  dllapi.add "\n"
  dllapi.add "\n"

proc exportObjectDllApi*(sym: NimNode) =
  discard

proc exportRefObjectDllApi*(sym: NimNode, whitelist: openarray[string]) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1][1].getType()

  dllapi.add &"proc $lib_{objNameSnaked}_unref*(x: {objName}) {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  GC_unref(x)\n"
  dllapi.add "\n"

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
      let prefix = &"$lib_{objNameSnaked}_{propertyNameSnaked}"

      dllapi.add &"proc {prefix}_len*({objNameSnaked}: {objName}): int"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}.len\n"
      dllapi.add "\n"

      dllapi.add &"proc {prefix}_add*({objNameSnaked}: {objName}, v: {propertyType[1].repr})"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}.add(v)\n"
      dllapi.add "\n"

      dllapi.add &"proc {prefix}_get*({objNameSnaked}: {objName}, i: int): {propertyType[1].repr}"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}[i]\n"
      dllapi.add "\n"

      dllapi.add &"proc {prefix}_set*({objNameSnaked}: {objName}, i: int, v: {propertyType[1].repr})"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}[i] = v\n"
      dllapi.add "\n"

      dllapi.add &"proc {prefix}_remove*({objNameSnaked}: {objName}, i: int)"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}.delete(i)\n"
      dllapi.add "\n"

      dllapi.add &"proc {prefix}_clear*({objNameSnaked}: {objName})"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}.setLen(0)\n"
      dllapi.add "\n"
    else:
      dllapi.add "proc "
      dllapi.add &"$lib_{objNameSnaked}_get_{propertyNameSnaked}*"
      dllapi.add &"({objNameSnaked}: {objName}): {exportTypeNim(propertyType)}"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName}"
      dllapi.add convertExportFromNim(propertyType)
      dllapi.add "\n"
      dllapi.add "\n"

      dllapi.add "proc "
      dllapi.add &"$lib_{objNameSnaked}_set_{propertyNameSnaked}*"
      dllapi.add &"({objNameSnaked}: {objName}, "
      dllapi.add &"{propertyName}: {exportTypeNim(propertyType)})"
      dllapi.add &" {exportProcPragmas} =\n"
      dllapi.add &"  {objNameSnaked}.{propertyName} = {propertyName}"
      dllapi.add convertImportToNim(propertyType)
      dllapi.add "\n"
      dllapi.add "\n"

proc generateSeqs(sym: NimNode) =
  let
    seqName = sym.getSeqName()
    seqNameSnaked = toSnakeCase(seqName)

  dllapi.add &"type {seqName}* = ref object\n"
  dllapi.add &"  s: {sym.repr}\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_new_{seqNameSnaked}*(): {seqName}"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add &"  {seqName}()\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_len*(s: {seqName}): int"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s.len\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_add*(s: {seqName}, v: {sym[1].repr})"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s.add(v)\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_get*(s: {seqName}, i: int): {sym[1].repr}"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s[i]\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_set*(s: {seqName}, i: int, v: {sym[1].repr})"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s[i] = v\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_remove*(s: {seqName}, i: int)"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s.delete(i)\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_clear*(s: {seqName})"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  s.s.setLen(0)\n"
  dllapi.add "\n"

  dllapi.add &"proc $lib_{seqNameSnaked}_unref*(s: {seqName})"
  dllapi.add &" {exportProcPragmas}"
  dllapi.add " =\n"
  dllapi.add "  GC_unref(s)\n"
  dllapi.add "\n"

proc exportSeqDllApi*(sym: NimNode) =
  generateSeqs(sym)

proc writeDllApi*(dir, lib: string) =
  writeFile(&"{dir}/dllapi.nim", dllapi.replace("$lib", lib))
