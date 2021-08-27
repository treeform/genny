import bindy/internal, bindy/common, bindy/languages/nim, bindy/languages/python,
    macros, strformat, tables

proc toggleBasicOnly*() =
  discard

macro exportConsts*(body: typed) =
  for statement in body:
    for sym in statement:
      exportConstInternal(sym)
      exportConstNim(sym)
      exportConstPy(sym)

macro exportEnums*(body: typed) =
  for statement in body:
    for sym in statement:
      if sym.getImpl()[2].kind != nnkEnumTy:
        error(
          &"Enum export entry of unexpected kind {sym.getImpl()[2].kind}",
          sym
        )

      exportEnumInternal(sym)
      exportEnumNim(sym)
      exportEnumPy(sym)

macro exportProcs*(body: typed) =
  for statement in body:
    let exportName = statement[0].repr

    var exported: int
    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        error(
          &"Proc exports statement of unexpected kind {procType.kind}",
          statement
        )

      if procType[0].len > 1:
        # Filter out overloads that are owned by objects
        let firstParam = procType[0][1][1]
        if firstParam.kind == nnkBracketExpr:
          continue
        let firstParamImpl = firstParam.getImpl()
        if firstParamImpl.kind == nnkTypeDef and
          firstParamImpl[2].kind != nnkEnumTy:
          continue

      exportProcInternal(procedure)
      exportProcNim(procedure)
      exportProcPy(procedure)

      inc exported

    if exported == 0:
      error(
        &"Proc export statement {exportName} does not export anything",
        statement
      )

macro exportObjects*(body: typed) =
  for statement in body:
    for sym in statement:
      let objImpl = sym.getImpl()[2]
      if objImpl.kind != nnkObjectTy:
        error(&"Unexpected export object impl kind {objImpl.kind}", statement)

      let objType = sym.getType()
      for property in objType[2]:
        if not property.isExported:
          error(&"Unexported property on {sym.repr}", objType)

        let propertyTypeImpl = property.getTypeImpl()
        if propertyTypeImpl.repr notin basicTypes:
          if propertyTypeImpl.kind notin {nnkEnumTy, nnkObjectTy}:
            error(
              &"Object cannot export property of type {property[^2].repr}",
              propertyTypeImpl
            )

      exportObjectInternal(sym)
      exportObjectNim(sym)
      exportObjectPy(sym)

macro exportRefObject*(
  sym: typed, whitelist: static[openarray[string]], body: typed
) =
  let refImpl = sym.getImpl()[2]
  if refImpl.kind != nnkRefTy:
    error(
      &"Unexpected export ref object impl kind {refImpl.kind}",
      sym
    )

  var
    exportProcs: seq[NimNode]
    basicOnly = false

  if body[0].kind != nnkDiscardStmt:
    error(
      "First statement in export ref object must be a constructor call or discard",
      body[0]
    )

  let constructor =
    if body[0][0].len > 0:
      body[0][0][0]
    else:
      nil

  for statement in body[1 .. ^1]:
    if statement.kind == nnkDiscardStmt:
      continue

    if statement.kind == nnkCall:
      if statement[0].repr == "toggleBasicOnly":
        basicOnly = not basicOnly
        continue

    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        error(
          &"Ref object exports statement of unexpected kind {procType.kind}",
          procType
        )

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
      error(
        &"Ref object export statement {statement[0].repr} does not export anything",
        statement
      )

  var entries: CountTable[string]
  for exportProc in exportProcs:
    entries.inc(exportProc.repr)

  exportRefObjectInternal(sym, whitelist, constructor)
  exportRefObjectNim(sym, whitelist, constructor)
  exportRefObjectPy(sym, whitelist, constructor)

  for procedure in exportProcs:
    var prefixes = @[sym]
    if entries[procedure.repr] > 1:
      # If there are more than one procs with this name, add a second prefix
      let procType = procedure.getTypeInst()
      if procType[0].len > 2:
        prefixes.add(procType[0][2][1])
    exportProcInternal(procedure, prefixes)
    exportProcNim(procedure, prefixes)
    exportProcPy(procedure, prefixes)

macro exportSeq*(sym: typed, body: typed) =
  var exportProcs: seq[NimNode]
  for statement in body:
    if statement.kind == nnkDiscardStmt:
      continue

    for procedure in statement:
      let procType = procedure.getTypeInst()
      if procType.kind != nnkProcTy:
        error(
          &"Ref object exports statement of unexpected kind {procType.kind}",
          procType
        )

      if procType[0].len <= 1:
        continue

      if procType[0][1][1].kind != nnkBracketExpr:
        continue

      if procType[0][1][1][1].getSeqName() == sym.getSeqName():
        exportProcs.add(procedure)

  exportSeqInternal(sym)
  exportSeqNim(sym)
  exportSeqPy(sym)

  for procedure in exportProcs:
    exportProcInternal(procedure, [sym])
    exportProcNim(procedure, [sym])
    exportProcPy(procedure, [sym])

macro writeFiles*(dir, lib: static[string]) =
  writeInternal(dir, lib)
  writeNim(dir, lib)
  writePy(dir, lib)
