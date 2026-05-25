import genny/[common, internal], macros, strformat, strutils

when defined(gennyC): import genny/languages/c
when defined(gennyCpp): import genny/languages/cpp
when defined(gennyNim): import genny/languages/nim
when defined(gennyNode): import genny/languages/node
when defined(gennyPython): import genny/languages/python
when defined(gennyPythonNative): import genny/languages/python_native
when defined(gennyZig): import genny/languages/zig

when not defined(gennyNim) and not defined(gennyPython) and not defined(gennyPythonNative) and not defined(gennyNode) and not defined(gennyC) and not defined(gennyCpp) and not defined(gennyZig):
  {.error: "Please define one of the genny languages. Use -d:gennyNim, -d:gennyPython, -d:gennyPythonNative, -d:gennyNode, -d:gennyC, -d:gennyCpp, -d:gennyZig to define the languages you want to export.".}

template discard2(f: untyped): untyped =
  when(compiles do: discard f):
    discard f
  else:
    f

proc asStmtList(body: NimNode): seq[NimNode] =
  ## Nim optimizes StmtList, reverse that:
  if body.kind != nnkStmtList:
    result.add(body)
  else:
    for child in body:
      result.add(child)

proc emptyBlockStmt(): NimNode =
  result = quote do:
    block:
      discard
  result[1].del(0)

macro exportConstsUntyped(body: untyped) =
  result = newNimNode(nnkStmtList)
  for ident in body:
    let varSection = quote do:
      var `ident` = `ident`
    result.add varSection

macro exportConstsTyped(body: typed) =
  for varSection in body.asStmtList:
    let sym = varSection[0][0]
    exportConstInternal(sym)
    when defined(gennyNim): exportConstNim(sym)
    when defined(gennyPython): exportConstPy(sym)
    when defined(gennyPythonNative): exportConstPyNative(sym)
    when defined(gennyNode): exportConstNode(sym)
    when defined(gennyC): exportConstC(sym)
    when defined(gennyCpp): exportConstCpp(sym)
    when defined(gennyZig): exportConstZig(sym)

template exportConsts*(body: untyped) =
  ## Exports a list of constants.
  exportConstsTyped(exportConstsUntyped(body))

macro exportEnumsUntyped(body: untyped) =
  result = newNimNode(nnkStmtList)
  for i, ident in body:
    let
      name = ident(&"enum{i}")
      varSection = quote do:
        var `name`: `ident`
    result.add varSection

macro exportEnumsTyped(body: typed) =
  for varSection in body.asStmtList:
    let sym = varSection[0][1]
    exportEnumInternal(sym)
    when defined(gennyNim): exportEnumNim(sym)
    when defined(gennyPython): exportEnumPy(sym)
    when defined(gennyPythonNative): exportEnumPyNative(sym)
    when defined(gennyNode): exportEnumNode(sym)
    when defined(gennyC): exportEnumC(sym)
    when defined(gennyCpp): exportEnumCpp(sym)
    when defined(gennyZig): exportEnumZig(sym)

template exportEnums*(body: untyped) =
  ## Exports a list of enums.
  exportEnumsTyped(exportEnumsUntyped(body))

proc fieldUntyped(clause, owner: NimNode): NimNode =
  result = emptyBlockStmt()
  result[1].add quote do:
    var
      obj: `owner`
      f = obj.`clause`

proc objectFieldUntyped(clause: NimNode): NimNode =
  result = emptyBlockStmt()
  if clause.kind notin {nnkExprColonExpr, nnkCall}:
    error("Object fields need explicit types, for example `x: float32`", clause)
  let fieldName = clause[0]
  let fieldType =
    if clause.kind == nnkExprColonExpr:
      clause[1]
    elif clause.len == 2 and clause[1].kind == nnkStmtList and clause[1].len == 1:
      clause[1][0]
    else:
      error("Object fields need explicit types, for example `x: float32`", clause)
  let fieldVar = ident("gennyField_" & fieldName.repr)
  result[1].add quote do:
    var `fieldVar`: `fieldType`

proc procUntyped(clause: NimNode): NimNode =
  result = emptyBlockStmt()

  if clause.kind == nnkIdent:
    let
      name = clause
      varSection = quote do:
        var p = `name`
    result[1].add varSection
  else:
    var
      name = clause[0]
      endStmt = quote do:
        discard2 `name`()
    for i in 1 ..< clause.len:
      var
        argType = clause[i]
        argName = ident(&"arg{i}")
      result[1].add quote do:
        var `argName`: `argType`
      endStmt[1].add argName
    result[1].add endStmt

proc procTypedSym(entry: NimNode): NimNode =
  result =
    if entry[1].kind == nnkVarSection:
      entry[1][0][2]
    else:
      if entry[1][^1].kind != nnkDiscardStmt:
        entry[1][^1][0]
      else:
        entry[1][^1][0][0]

proc objectFieldsTyped(fieldsBlock: NimNode): seq[ObjectField] =
  if fieldsBlock[1].len == 0:
    return

  for entry in fieldsBlock[1].asStmtList:
    var fieldEntry = entry
    if fieldEntry.kind == nnkBlockStmt:
      fieldEntry = fieldEntry[1]
    if fieldEntry.kind == nnkStmtList and fieldEntry.len == 1:
      fieldEntry = fieldEntry[0]
    if fieldEntry.kind != nnkVarSection:
      error("Invalid generated object field entry", fieldEntry)
    let identDefs = fieldEntry[0]
    for i in 0 .. identDefs.len - 3:
      let fieldSym = identDefs[i]
      var fieldName = fieldSym.repr.split("`")[0]
      fieldName.removePrefix("gennyField_")
      result.add((fieldName, fieldSym.getTypeInst()))

proc procTyped(
  entry: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = []
) =
  let procSym = procTypedSym(entry)
  exportProcInternal(procSym, owner, prefixes)
  when defined(gennyNim): exportProcNim(procSym, owner, prefixes)
  when defined(gennyPython): exportProcPy(procSym, owner, prefixes)
  when defined(gennyPythonNative): exportProcPyNative(procSym, owner, prefixes)
  when defined(gennyNode): exportProcNode(procSym, owner, prefixes)
  when defined(gennyC): exportProcC(procSym, owner, prefixes)
  when defined(gennyCpp): exportProcCpp(procSym, owner, prefixes)
  when defined(gennyZig): exportProcZig(procSym, owner, prefixes)

macro exportProcsUntyped(body: untyped) =
  result = newNimNode(nnkStmtList)
  for clause in body:
    result.add procUntyped(clause)

macro exportProcsTyped(body: typed) =
  for entry in body.asStmtList:
    procTyped(entry)

template exportProcs*(body: untyped) =
  ## Exports a list of procs.
  ## Procs can just be a name `doX` or fully qualified with `doX(int): int`.
  exportProcsTyped(exportProcsUntyped(body))

macro exportObjectUntyped(sym, body: untyped) =
  result = newNimNode(nnkStmtList)

  let varSection = quote do:
    var obj: `sym`
  result.add varSection

  var
    fieldsBlock = emptyBlockStmt()
    constructorBlock = emptyBlockStmt()
    procsBlock = emptyBlockStmt()

  for section in body:
    if section.kind == nnkDiscardStmt:
      continue

    case section[0].repr:
    of "fields":
      for field in section[1]:
        fieldsBlock[1].add objectFieldUntyped(field)
    of "constructor":
      constructorBlock[1].add procUntyped(section[1][0])
    of "procs":
      for clause in section[1]:
        procsBlock[1].add procUntyped(clause)
    else:
      error("Invalid section", section)

  result.add fieldsBlock
  result.add constructorBlock
  result.add procsBlock

macro exportObjectTyped(body: typed) =
  let
    sym = body[0][0][0].getTypeInst()
    typeExpr = body[0][0][1]
    fieldsBlock = body[1]
    constructorBlock = body[2]
    procsBlock = body[3]
    fields = objectFieldsTyped(fieldsBlock)
    nimModule =
      if typeExpr.kind == nnkDotExpr:
        typeExpr[0].repr
      else:
        ""

  let constructor =
    if constructorBlock[1].len > 0:
      procTypedSym(constructorBlock[1])
    else:
      nil

  registerValueObjectType(sym)
  if constructor != nil:
    let constructorType = constructor.getTypeInst()
    if constructorType[0][0].kind != nnkEmpty:
      registerValueObjectTypeAlias(sym.repr, constructorType[0][0])
  exportObjectInternal(sym, fields, constructor, nimModule.len > 0)
  when defined(gennyNim):
    exportObjectNim(sym, fields, constructor, nimModule)
  when defined(gennyPython): exportObjectPy(sym, fields, constructor)
  when defined(gennyPythonNative): exportObjectPyNative(sym, fields, constructor)
  when defined(gennyNode): exportObjectNode(sym, fields, constructor)
  when defined(gennyC): exportObjectC(sym, fields, constructor)
  when defined(gennyCpp): exportObjectCpp(sym, fields, constructor)
  when defined(gennyZig): exportObjectZig(sym, fields, constructor)

  if procsBlock[1].len > 0:
    var procsSeen: seq[string]
    for entry in procsBlock[1].asStmtList:
      var
        procSym = procTypedSym(entry)
        prefixes: seq[NimNode]
      let procType = procSym.getTypeInst()
      if procType[0].len > 1:
        registerValueObjectTypeAlias(sym.repr, procType[0][1][^2])
      if procSym.repr notin procsSeen:
        procsSeen.add procSym.repr
      else:
        if procType[0].len > 2:
          prefixes.add(procType[0][2][1])
      exportProcInternal(procSym, sym, prefixes)
      when defined(gennyNim): exportProcNim(procSym, sym, prefixes)
      when defined(gennyPython): exportProcPy(procSym, sym, prefixes)
      when defined(gennyPythonNative): exportProcPyNative(procSym, sym, prefixes)
      when defined(gennyNode): exportProcNode(procSym, sym, prefixes)
      when defined(gennyC): exportProcC(procSym, sym, prefixes)
      when defined(gennyCpp): exportProcCpp(procSym, sym, prefixes)
      when defined(gennyZig): exportProcZig(procSym, sym, prefixes)

  when defined(gennyPython): exportCloseObjectPy(sym)
  when defined(gennyZig): exportCloseObjectZig()
  when defined(gennyCpp): exportCloseObjectCpp()

template exportObject*(sym, body: untyped) =
  ## Exports an object, with these sections:
  ## * fields
  ## * constructor
  ## * procs
  exportObjectTyped(exportObjectUntyped(sym, body))

macro exportSeqUntyped(sym, body: untyped) =
  result = newNimNode(nnkStmtList)

  let varSection = quote do:
    var s: `sym`
  result.add varSection

  for section in body:
    if section.kind == nnkDiscardStmt:
      continue

    case section[0].repr:
    of "procs":
      for clause in section[1]:
        result.add procUntyped(clause)
    else:
      error("Invalid section", section)

macro exportSeqTyped(body: typed) =
  let sym = body.asStmtList()[0][0][1]

  exportSeqInternal(sym)
  when defined(gennyNim): exportSeqNim(sym)
  when defined(gennyPython): exportSeqPy(sym)
  when defined(gennyPythonNative): exportSeqPyNative(sym)
  when defined(gennyNode): exportSeqNode(sym)
  when defined(gennyC): exportSeqC(sym)
  when defined(gennyCpp): exportSeqCpp(sym)
  when defined(gennyZig): exportSeqZig(sym)

  for entry in body.asStmtList()[1 .. ^1]:
    procTyped(entry, sym)

  when defined(gennyCpp): exportCloseObjectCpp()
  when defined(gennyZig): exportCloseObjectZig()

template exportSeq*(sym, body: untyped) =
  ## Exports a regular sequence.
  ## * procs section
  exportSeqTyped(exportSeqUntyped(sym, body))

macro exportRefObjectUntyped(sym, body: untyped) =
  result = newNimNode(nnkStmtList)

  let varSection = quote do:
    var refObj: `sym`
  result.add varSection

  var
    fieldsBlock = emptyBlockStmt()
    constructorBlock = emptyBlockStmt()
    procsBlock = emptyBlockStmt()

  for section in body:
    if section.kind == nnkDiscardStmt:
      continue

    case section[0].repr:
    of "fields":
      for field in section[1]:
        fieldsBlock[1].add fieldUntyped(field, sym)
    of "constructor":
      constructorBlock[1].add procUntyped(section[1][0])
    of "procs":
      for clause in section[1]:
        procsBlock[1].add procUntyped(clause)
    else:
      error("Invalid section", section)

  result.add fieldsBlock
  result.add constructorBlock
  result.add procsBlock

macro exportRefObjectTyped(body: typed) =
  let
    sym = body[0][0][1]
    fieldsBlock = body[1]
    constructorBlock = body[2]
    procsBlock = body[3]

  var fields: seq[(string, NimNode)]
  if fieldsBlock[1].len > 0:
    for entry in fieldsBlock[1].asStmtList:
      case entry[1][1][2].kind:
      of nnkCall:
        fields.add((
          entry[1][1][2][0].repr,
          entry[1][1][2].getTypeInst()
        ))
      else:
        fields.add((
          entry[1][1][2][1].repr,
          entry[1][1][2][1].getTypeInst()
        ))

  let constructor =
    if constructorBlock[1].len > 0:
      procTypedSym(constructorBlock[1])
    else:
      nil

  exportRefObjectInternal(sym, fields, constructor)
  when defined(gennyNim): exportRefObjectNim(sym, fields, constructor)
  when defined(gennyPython): exportRefObjectPy(sym, fields, constructor)
  when defined(gennyPythonNative): exportRefObjectPyNative(sym, fields, constructor)
  when defined(gennyNode): exportRefObjectNode(sym, fields, constructor)
  when defined(gennyC): exportRefObjectC(sym, fields, constructor)
  when defined(gennyCpp): exportRefObjectCpp(sym, fields, constructor)
  when defined(gennyZig): exportRefObjectZig(sym, fields, constructor)

  if procsBlock[1].len > 0:
    var procsSeen: seq[string]
    for entry in procsBlock[1].asStmtList:
      var
        procSym = procTypedSym(entry)
        prefixes: seq[NimNode]
      if procSym.repr notin procsSeen:
        procsSeen.add procSym.repr
      else:
        let procType = procSym.getTypeInst()
        if procType[0].len > 2:
          prefixes.add(procType[0][2][1])
      exportProcInternal(procSym, sym, prefixes)
      when defined(gennyNim): exportProcNim(procSym, sym, prefixes)
      when defined(gennyPython): exportProcPy(procSym, sym, prefixes)
      when defined(gennyPythonNative): exportProcPyNative(procSym, sym, prefixes)
      when defined(gennyNode): exportProcNode(procSym, sym, prefixes)
      when defined(gennyC): exportProcC(procSym, sym, prefixes)
      when defined(gennyCpp): exportProcCpp(procSym, sym, prefixes)
      when defined(gennyZig): exportProcZig(procSym, sym, prefixes)

  when defined(gennyCpp): exportCloseObjectCpp()
  when defined(gennyZig): exportCloseObjectZig()

template exportRefObject*(sym, body: untyped) =
  ## Exports a ref object, with these sections:
  ## * fields
  ## * constructor
  ## * procs
  exportRefObjectTyped(exportRefObjectUntyped(sym, body))

macro writeFiles*(dir, lib: static[string]) =
  ## This needs to be and the end of the file and it needs to be followed by:
  ## `include generated/internal`
  result = newStmtList()
  writeInternal(dir, lib)
  when defined(gennyNim): writeNim(dir, lib)
  when defined(gennyPython): writePy(dir, lib)
  when defined(gennyPythonNative): result.add writePyNative(dir, lib)
  when defined(gennyNode): writeNode(dir, lib)
  when defined(gennyC): writeC(dir, lib)
  when defined(gennyCpp): writeCpp(dir, lib)
  when defined(gennyZig): writeZig(dir, lib)
