import bindy/dllapi, bindy/common, macros, strformat, tables

proc toggleBasicOnly*() =
  discard

macro exportEnums*(syms: openarray[typed]) =
  for sym in syms:
    if sym.getImpl()[2].kind != nnkEnumTy:
      quit(&"Enum export entry of unexpected kind {sym.getImpl()[2].kind}")

    exportEnumDllApi(sym)

macro exportProcs*(body: typed) =
  for statement in body:
    let exportName = statement[0].repr

    var exported: int
    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        quit(&"Proc exports statement of unexpected kind {procType.kind}")

      if procType[0].len > 1:
        # Filter out overloads that are owned by objects
        let firstParam = procType[0][1][1]
        if firstParam.kind != nnkBracketExpr:
          let firstParamImpl = firstParam.getImpl()
          if firstParamImpl.kind == nnkTypeDef and
            firstParamImpl[2].kind != nnkEnumTy:
            continue

      exportProcDllApi(procedure)
      inc exported

    if exported == 0:
      quit(&"Proc export statement {exportName} does not export anything")

macro exportObjects*(syms: openarray[typed]) =
  for sym in syms:
    let objImpl = sym.getImpl()[2]
    if objImpl.kind != nnkObjectTy:
      quit(&"Unexpected export object impl kind {objImpl.kind}")

    let objType = sym.getType()[1].getType()
    for property in objType[2]:
      if not property.isExported:
        quit(&"Unexported property on {sym.repr}")

      let propertyTypeImpl = property.getTypeImpl()
      if propertyTypeImpl.repr notin basicTypes:
        if propertyTypeImpl.kind notin {nnkEnumTy, nnkObjectTy}:
          quit(&"Object cannot export property of type {property[^2].repr}")

    exportObjectDllApi(sym)

macro exportRefObject*(
  sym: typed, whitelist: static[openarray[string]], body: typed
) =
  let refImpl = sym.getImpl()[2]
  if refImpl.kind != nnkRefTy:
    quit(&"Unexpected export ref object impl kind {refImpl.kind}")

  var
    exportProcs: seq[NimNode]
    basicOnly = false
  for statement in body:
    if statement.kind == nnkDiscardStmt:
      continue

    if statement.kind == nnkCall:
      if statement[0].repr == "toggleBasicOnly":
        basicOnly = not basicOnly
        continue

    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        quit(&"Ref object exports statement of unexpected kind {procType.kind}")

      if procType[0].len <= 1:
        continue

      if procType[0][1][1].repr != sym.repr:
        var found = false

        let procImpl = procedure.getImpl()
        if procImpl[3][1][1].kind == nnkInfix:
          for choice in procImpl[3][1][1][1 .. ^1]:
            if choice.repr == sym.repr:
              found = true

        if not found:
          continue

      if basicOnly:
        var skip = false
        for paramType in procType[0][2 .. ^1]:
          if paramType[1].repr == "bool":
            continue
          if paramType[1].getImpl().kind == nnkNilLit:
            continue
          if paramType[1].getImpl().kind == nnkTypeDef:
            if paramType[1].getImpl()[2].kind == nnkEnumTy:
              continue
          skip = true
          break
        if skip:
          continue

      exportProcs.add(procedure)

    if exportProcs.len == 0:
      quit(&"Ref object export statement {statement[0].repr} does not export anything")

  var overloads: Table[string, int]
  for exportProc in exportProcs:
    if exportProc.repr notin overloads:
      overloads[exportProc.repr] = 0
    else:
      inc overloads[exportProc.repr]

  exportRefObjectDllApi(sym, whitelist)

  for procedure in exportProcs:
    var prefixes = @[sym]
    if overloads[procedure.repr] > 0:
      let procType = procedure.getTypeInst()
      if procType[0].len > 2:
        prefixes.add(procType[0][2][1])
    exportProcDllApi(procedure, prefixes)

macro exportSeq*(sym: typed, body: typed) =
  var exportProcs: seq[NimNode]
  for statement in body:
    if statement.kind == nnkDiscardStmt:
      continue

    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        quit(&"Ref object exports statement of unexpected kind {procType.kind}")

      if procType[0].len <= 1:
        continue

      if procType[0][1][1].kind != nnkBracketExpr:
        continue

      if procType[0][1][1][1].getSeqName() == sym.getSeqName():
        exportProcs.add(procedure)

  exportSeqDllApi(sym)

  for procedure in exportProcs:
    exportProcDllApi(procedure, [sym])

macro writeFiles*(dir, lib: static[string]) =
  writeDllApi(dir, lib)
