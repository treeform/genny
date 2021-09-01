import bindy/internal, bindy/common, bindy/languages/nim, bindy/languages/python, bindy/languages/javascript,
    macros, strformat, tables

template discard2(f: untyped): untyped =
  when(compiles do: discard f):
    discard f
  else:
    f

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
  for varSection in body:
    let sym = varSection[0][0]
    exportConstInternal(sym)
    exportConstNim(sym)
    exportConstPy(sym)
    exportConstJs(sym)

template exportConsts*(body: untyped) =
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
  for varSection in body:
    let sym = varSection[0][1]
    exportEnumInternal(sym)
    exportEnumNim(sym)
    exportEnumPy(sym)
    exportEnumJs(sym)

template exportEnums*(body: untyped) =
  exportEnumsTyped(exportEnumsUntyped(body))

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

proc procTyped(entry: NimNode, prefixes: openarray[NimNode] = [], ownerSym = "") =
  let procSym = procTypedSym(entry)
  exportProcInternal(procSym, prefixes)
  exportProcNim(procSym, prefixes)
  exportProcPy(procSym, prefixes)
  exportProcJs(procSym, prefixes, ownerSym)

macro exportProcsUntyped(body: untyped) =
  result = newNimNode(nnkStmtList)
  for clause in body:
    result.add procUntyped(clause)

macro exportProcsTyped(body: typed) =
  for entry in body:
    procTyped(entry)

template exportProcs*(body: untyped) =
  exportProcsTyped(exportProcsUntyped(body))

macro exportObjectUntyped(sym, body: untyped) =
  result = newNimNode(nnkStmtList)

  let varSection = quote do:
    var obj: `sym`
  result.add varSection

  for section in body:
    if section.kind == nnkDiscardStmt:
      continue

    case section[0].repr:
    of "constructor":
      result.add procUntyped(section[1][0])
    else:
      error("Invalid section", section)

  result.add quote do:
    discard

macro exportObjectTyped(body: typed) =
  let
    sym = body[0][0][1]
    constructor =
      if body[1].kind != nnkDiscardStmt:
        procTypedSym(body[1])
      else:
        nil

  exportObjectInternal(sym, constructor)
  exportObjectNim(sym, constructor)
  exportObjectPy(sym, constructor)
  exportObjectJs(sym, constructor)

template exportObject*(sym, body: untyped) =
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

  result.add quote do:
    discard

macro exportSeqTyped(body: typed) =
  let sym = body[0][0][1]

  exportSeqInternal(sym)
  exportSeqNim(sym)
  exportSeqPy(sym)
  exportSeqJs(sym)

  for entry in body[1 .. ^2]:
    procTyped(entry, [sym], sym.getName())

template exportSeq*(sym, body: untyped) =
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
      var
        seqIdent = ident("allowedFields")
        allowedFields = quote do:
          var `seqIdent`: seq[string] = @[]
      for field in section[1]:
        allowedFields[0][2][1].add newStrLitNode(field.repr)
      fieldsBlock[1].add allowedFields
    of "constructor":
      constructorBlock[1].add procUntyped(section[1][0])
    of "procs":
      for clause in section[1]:
        procsBlock[1].add procUntyped(clause)
      procsBlock[1].add quote do:
        discard
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

  var allowedFields: seq[string]
  if fieldsBlock[1].len > 0:
    for entry in fieldsBlock[1][0][2][1]:
      allowedFields.add entry.strVal

  let constructor =
    if constructorBlock[1].len > 0:
      procTypedSym(constructorBlock[1])
    else:
      nil

  exportRefObjectInternal(sym, allowedFields, constructor)
  exportRefObjectNim(sym, allowedFields, constructor)
  exportRefObjectPy(sym, allowedFields, constructor)
  exportRefObjectJs(sym, allowedFields, constructor)

  if procsBlock[1].len > 0:
    var procsSeen: seq[string]
    for entry in procsBlock[1][0 .. ^2]:
      var
        procSym = procTypedSym(entry)
        prefixes = @[sym]
      if procSym.repr notin procsSeen:
        procsSeen.add procSym.repr
      else:
        let procType = procSym.getTypeInst()
        if procType[0].len > 2:
          prefixes.add(procType[0][2][1])
      exportProcInternal(procSym, prefixes)
      exportProcNim(procSym, prefixes)
      exportProcPy(procSym, prefixes)
      exportProcJs(procSym, prefixes, sym.repr)

template exportRefObject*(sym, body: untyped) =
  exportRefObjecTtyped(exportRefObjectUntyped(sym, body))

macro writeFiles*(dir, lib: static[string]) =
  writeInternal(dir, lib)
  writeNim(dir, lib)
  writePy(dir, lib)
  writeJs(dir, lib)
