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
  internal.add &"{procName}("
  for param in procParams:
    for i in 0 .. param.len - 3:
      internal.add &"{toSnakeCase(param[i].repr)}"
      internal.add &"{convertImportToNim(param[^2])}, "
  internal.removeSuffix ", "
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

proc exportRefObjectInternal*(
  sym: NimNode, allowedFields: openarray[string], constructor: NimNode
) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  internal.add &"proc $lib_{objNameSnaked}_unref*(x: {objName}) {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  GC_unref(x)\n"
  internal.add "\n"

  if constructor != nil:
    exportProcInternal(constructor)

  for property in objType[2]:
    if property.repr notin allowedFields:
      continue

    let
      propertyName = property.repr
      propertyNameSnaked = toSnakeCase(propertyName)
      propertyType = property.getTypeInst()

    if propertyType.kind != nnkBracketExpr:
      internal.add "proc "
      internal.add &"$lib_{objNameSnaked}_get_{propertyNameSnaked}*"
      internal.add &"({objNameSnaked}: {objName}): {exportTypeNim(propertyType)}"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}"
      internal.add convertExportFromNim(propertyType)
      internal.add "\n"
      internal.add "\n"

      internal.add "proc "
      internal.add &"$lib_{objNameSnaked}_set_{propertyNameSnaked}*"
      internal.add &"({objNameSnaked}: {objName}, "
      internal.add &"{propertyName}: {exportTypeNim(propertyType)})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName} = {propertyName}"
      internal.add convertImportToNim(propertyType)
      internal.add "\n"
      internal.add "\n"
    else: # Treat this property as a bound seq
      let prefix = &"$lib_{objNameSnaked}_{propertyNameSnaked}"

      internal.add &"proc {prefix}_len*({objNameSnaked}: {objName}): int"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}.len\n"
      internal.add "\n"

      internal.add &"proc {prefix}_add*({objNameSnaked}: {objName}, v: {propertyType[1].repr})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}.add(v)\n"
      internal.add "\n"

      internal.add &"proc {prefix}_get*({objNameSnaked}: {objName}, i: int): {propertyType[1].repr}"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}[i]\n"
      internal.add "\n"

      internal.add &"proc {prefix}_set*({objNameSnaked}: {objName}, i: int, v: {propertyType[1].repr})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}[i] = v\n"
      internal.add "\n"

      internal.add &"proc {prefix}_delete*({objNameSnaked}: {objName}, i: int)"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}.delete(i)\n"
      internal.add "\n"

      internal.add &"proc {prefix}_clear*({objNameSnaked}: {objName})"
      internal.add &" {exportProcPragmas} =\n"
      internal.add &"  {objNameSnaked}.{propertyName}.setLen(0)\n"
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

  internal.add &"proc $lib_{seqNameSnaked}_add*(s: {seqName}, v: {sym[1].repr})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s.add(v)\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_get*(s: {seqName}, i: int): {sym[1].repr}"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s[i]\n"
  internal.add "\n"

  internal.add &"proc $lib_{seqNameSnaked}_set*(s: {seqName}, i: int, v: {sym[1].repr})"
  internal.add &" {exportProcPragmas}"
  internal.add " =\n"
  internal.add "  s.s[i] = v\n"
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

proc writeInternal*(dir, lib: string) =
  writeFile(
    &"{dir}/internal.nim",
    internal.replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
