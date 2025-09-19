import genny/internal, genny/languages/c, genny/languages/cpp,
    genny/languages/nim, genny/languages/node, genny/languages/python,
    genny/languages/zig, macros, strformat

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
    #exportConstNim(sym)
    exportConstPy(sym)
    # exportConstNode(sym)
    # exportConstC(sym)
    # exportConstCpp(sym)
    # exportConstZig(sym)

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
    #exportEnumNim(sym)
    exportEnumPy(sym)
    # exportEnumNode(sym)
    # exportEnumC(sym)
    # exportEnumCpp(sym)
    # exportEnumZig(sym)

template exportEnums*(body: untyped) =
  ## Exports a list of enums.
  exportEnumsTyped(exportEnumsUntyped(body))

proc fieldUntyped(clause, owner: NimNode): NimNode =
  result = emptyBlockStmt()
  result[1].add quote do:
    var
      obj: `owner`
      f = obj.`clause`

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

proc procTyped(
  entry: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = []
) =
  let procSym = procTypedSym(entry)
  exportProcInternal(procSym, owner, prefixes)
  #exportProcNim(procSym, owner, prefixes)
  exportProcPy(procSym, owner, prefixes)
  # exportProcNode(procSym, owner, prefixes)
  # exportProcC(procSym, owner, prefixes)
  # exportProcCpp(procSym, owner, prefixes)
  # exportProcZig(procSym, owner, prefixes)

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
    constructorBlock = emptyBlockStmt()
    procsBlock = emptyBlockStmt()

  for section in body:
    if section.kind == nnkDiscardStmt:
      continue

    case section[0].repr:
    of "constructor":
      constructorBlock[1].add procUntyped(section[1][0])
    of "procs":
      for clause in section[1]:
        procsBlock[1].add procUntyped(clause)
    else:
      error("Invalid section", section)

  result.add constructorBlock
  result.add procsBlock

macro exportObjectTyped(body: typed) =
  let
    sym = body[0][0][1]
    constructorBlock = body[1]
    procsBlock = body[2]

  let constructor =
    if constructorBlock[1].len > 0:
      procTypedSym(constructorBlock[1])
    else:
      nil

  exportObjectInternal(sym, constructor)
  #exportObjectNim(sym, constructor)
  exportObjectPy(sym, constructor)
  # exportObjectNode(sym, constructor)
  # exportObjectC(sym, constructor)
  # exportObjectCpp(sym, constructor)
  # exportObjectZig(sym, constructor)

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
      exportProcNim(procSym, sym, prefixes)
      exportProcPy(procSym, sym, prefixes)
      exportProcNode(procSym, sym, prefixes)
      exportProcC(procSym, sym, prefixes)
      exportProcCpp(procSym, sym, prefixes)
      exportProcZig(procSym, sym, prefixes)

  exportCloseObjectZig()
  exportCloseObjectCpp()

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
  #exportSeqNim(sym)
  exportSeqPy(sym)
  # exportSeqNode(sym)
  # exportSeqC(sym)
  # exportSeqCpp(sym)
  # exportSeqZig(sym)

  for entry in body.asStmtList()[1 .. ^1]:
    procTyped(entry, sym)

  exportCloseObjectCpp()
  exportCloseObjectZig()

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
  #exportRefObjectNim(sym, fields, constructor)
  exportRefObjectPy(sym, fields, constructor)
  # exportRefObjectNode(sym, fields, constructor)
  # exportRefObjectC(sym, fields, constructor)
  # exportRefObjectCpp(sym, fields, constructor)
  # exportRefObjectZig(sym, fields, constructor)

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
      #exportProcNim(procSym, sym, prefixes)
      exportProcPy(procSym, sym, prefixes)
      # exportProcNode(procSym, sym, prefixes)
      # exportProcC(procSym, sym, prefixes)
      # exportProcCpp(procSym, sym, prefixes)
      # exportProcZig(procSym, sym, prefixes)

  # exportCloseObjectCpp()
  # exportCloseObjectZig()

template exportRefObject*(sym, body: untyped) =
  ## Exports a ref object, with these sections:
  ## * fields
  ## * constructor
  ## * procs
  exportRefObjectTyped(exportRefObjectUntyped(sym, body))

macro writeFiles*(dir, lib: static[string]) =
  ## This needs to be and the end of the file and it needs to be followed by:
  ## `include generated/internal`
  writeInternal(dir, lib)
  #writeNim(dir, lib)
  writePy(dir, lib)
  # writeNode(dir, lib)
  # writeC(dir, lib)
  # writeCpp(dir, lib)
  # writeZig(dir, lib)
