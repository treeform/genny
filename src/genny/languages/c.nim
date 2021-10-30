import ../common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string

proc exportTypeC(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeC(sym[2])
      result = &"{entryType}[{entryCount}]"
    elif sym[0].repr == "seq":
      result = sym.getSeqName()
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result =
      case sym.repr:
      of "string": "char*"
      of "bool": "char"
      of "byte": "char"
      of "int8": "char"
      of "int16": "short"
      of "int32": "int"
      of "int64": "long long"
      of "int": "long long"
      of "uint8": "unsigned char"
      of "uint16": "unsigned short"
      of "uint32": "unsigned int"
      of "uint64": "unsigned long long"
      of "uint": "unsigned long long"
      of "float32": "float"
      of "float64": "double"
      of "float": "double"
      of "Rune": "int"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "", "nil": "void"
      of "None": "void"
      else:
        sym.repr

proc exportTypeC(sym: NimNode, name: string): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeC(sym[2], &"{name}[{entryCount}]")
      result = &"{entryType}"
    elif sym[0].repr == "seq":
      result = sym.getSeqName() & " " & name
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result = exportTypeC(sym) & " " & name

proc dllProc*(procName: string, args: openarray[string], restype: string) =
  var argStr = ""
  for arg in args:
    argStr.add &"{arg}, "
  argStr.removeSuffix ", "
  procs.add &"{restype} {procName}({argStr});\n"
  procs.add "\n"

proc dllProc*(procName: string, args: openarray[(NimNode, NimNode)], restype: string) =
  var argsConverted: seq[string]
  for (argName, argType) in args:
    argsConverted.add exportTypeC(argType, toSnakeCase(argName.getName()))
  dllProc(procName, argsConverted, restype)

proc dllProc*(procName: string, restype: string) =
  var a: seq[(string)]
  dllProc(procName, a, restype)

proc exportConstC*(sym: NimNode) =
  types.add &"#define {toCapSnakeCase(sym.repr)} {sym.getImpl()[2].repr}\n"
  types.add "\n"

proc exportEnumC*(sym: NimNode) =
  types.add &"typedef char {sym.repr};\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    types.add &"#define {toCapSnakeCase(entry.repr)} {i}\n"
  types.add "\n"

proc exportProcC*(
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

  var apiProcName = ""
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

  let comments =
    if sym.getImpl()[6][0].kind == nnkCommentStmt:
      sym.getImpl()[6][0].repr
    elif sym.getImpl[6].kind == nnkAsgn and
      sym.getImpl[6][1].kind == nnkStmtListExpr and
      sym.getImpl[6][1][0].kind == nnkCommentStmt:
      sym.getImpl[6][1][0].repr
    else:
      ""
  if comments != "":
    let lines = comments.replace("## ", "").split("\n")
    procs.add "/**\n"
    for line in lines:
      procs.add &" * {line}\n"
    procs.add " */\n"

  var dllParams: seq[(NimNode, NimNode)]
  for param in procParams:
    dllParams.add((param[0], param[1]))
  dllProc(&"$lib_{apiProcName}", dllParams, exportTypeC(procReturn))

proc exportObjectC*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  types.add &"typedef struct {objName} " & "{\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"  {exportTypeC(identDefs[^2], toSnakeCase(property[1].repr))};\n"
  types.add "} " & &"{objName};\n\n"

  if constructor != nil:
    exportProcC(constructor)
  else:
    procs.add &"{objName} $lib_{toSnakeCase(objName)}("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        procs.add &"{exportTypeC(identDefs[^2], toSnakeCase(property[1].repr))}, "
    procs.removeSuffix ", "
    procs.add ");\n\n"

  dllProc(&"$lib_{toSnakeCase(objName)}_eq", [&"{objName} a", &"{objName} b"], "char")

proc genRefObject(objName: string) =
  types.add &"typedef long long {objName};\n\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

  dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  let objArg = objName & " " & toSnakeCase(objName)
  dllProc(&"{procPrefix}_len", [objArg], "long long")
  dllProc(&"{procPrefix}_get", [objArg, "long long index"], exportTypeC(entryType))
  dllProc(&"{procPrefix}_set", [objArg, "long long index", exportTypeC(entryType, "value")], "void")
  dllProc(&"{procPrefix}_delete", [objArg, "long long index"], "void")
  dllProc(&"{procPrefix}_add", [objArg, exportTypeC(entryType, "value")], "void")
  dllProc(&"{procPrefix}_clear", [objArg], "void")

proc exportRefObjectC*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  genRefObject(objName)

  if constructor != nil:
      let
        constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
        constructorType = constructor.getTypeInst()
        constructorParams = constructorType[0][1 .. ^1]
        constructorRaises = constructor.raises()

      var dllParams: seq[(NimNode, NimNode)]
      for param in constructorParams:
        dllParams.add((param[0], param[1]))
      dllProc(constructorLibProc, dllParams, objName)

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"

      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      dllProc(getProcName, [objName & " " & objNameSnaked], exportTypeC(fieldType))
      dllProc(setProcName, [objName & " " & objNameSnaked, exportTypeC(fieldType, "value")], exportTypeC(nil))
    else:
      var helperName = fieldName
      helperName[0] = toUpperAscii(helperName[0])
      let helperClassName = objName & helperName

      genSeqProcs(
        objName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        &".{toSnakeCase(objName)}",
        fieldType[1]
      )

proc exportSeqC*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  let newSeqProc = &"$lib_new_{toSnakeCase(seqName)}"

  dllProc(newSeqProc, seqName)

  genSeqProcs(
    sym.getName(),
    &"$lib_{seqNameSnaked}",
    "",
    sym[1]
  )

const header = """
#ifndef INCLUDE_$LIB_H
#define INCLUDE_$LIB_H

"""

const footer = """
#endif
"""

proc writeC*(dir, lib: string) =
  writeFile(&"{dir}/{toSnakeCase(lib)}.h", (header & types & procs & footer)
    .replace("$lib", toSnakeCase(lib)).replace("$LIB", lib.toUpperAscii())
  )
