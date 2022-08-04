import ../common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  classes {.compiletime.}: string
  members {.compiletime.}: string

proc unCapitalize(s: string): string =
  s[0].toLowerAscii() & s[1 .. ^1]

proc exportTypeCpp(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeCpp(sym[2])
      result = &"{entryType}[{entryCount}]"
    elif sym[0].repr == "seq":
      result = sym.getSeqName()
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result =
      case sym.repr:
      of "string": "const char*"
      of "bool": "bool"
      of "byte": "char"
      of "int8": "int8_t"
      of "int16": "int16_t"
      of "int32": "int32_t"
      of "int64": "int64_t"
      of "int": "int64_t"
      of "uint8": "uint8_t"
      of "uint16": "uint16_t"
      of "uint32": "uint32_t"
      of "uint64": "uint64_t"
      of "uint": "uint64_t"
      of "float32": "float"
      of "float64": "double"
      of "float": "double"
      of "Rune": "int32_t"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "", "nil": "void"
      of "None": "void"
      else:
        if sym.getType().kind == nnkBracketExpr:
          sym.repr
        else:
          sym.repr

proc exportTypeCpp(sym: NimNode, name: string): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeCpp(sym[2], &"{name}[{entryCount}]")
      result = &"{entryType}"
    elif sym[0].repr == "seq":
      result = sym.getSeqName() & " " & name
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result = exportTypeCpp(sym) & " " & name

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
    argsConverted.add exportTypeCpp(argType, toSnakeCase(argName.getName()))
  dllProc(procName, argsConverted, restype)

proc dllProc*(procName: string, restype: string) =
  var a: seq[(string)]
  dllProc(procName, a, restype)

proc exportConstCpp*(sym: NimNode) =
  types.add &"#define {toCapSnakeCase(sym.repr)} {sym.getImpl()[2].repr}\n"
  types.add "\n"

proc exportEnumCpp*(sym: NimNode) =
  types.add &"typedef char {sym.repr};\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    types.add &"#define {toCapSnakeCase(entry.repr)} {i}\n"
  types.add "\n"

proc exportProcCpp*(
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

  var dllParams: seq[(NimNode, NimNode)]
  for param in procParams:
    dllParams.add((param[0], param[1]))
  dllProc(&"$lib_{apiProcName}", dllParams, exportTypeCpp(procReturn))

  if owner == nil:
    if procReturn.kind != nnkEmpty:
      members.add exportTypeCpp(procReturn)
      members.add " "
    members.add procName
    members.add "("
    for param in procParams:
      members.add exportTypeCpp(param[1], param[0].getName())
      members.add ", "
    members.removeSuffix ", "
    members.add ") {\n"
    members.add "  "
    if procReturn.kind != nnkEmpty:
      members.add "return "
    members.add &"$lib_{apiProcName}("
    for param in procParams:
      members.add param[0].getName()
      members.add ", "
    members.removeSuffix ", "
    members.add ");\n"
    members.add "};\n\n"

  else:
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
      classes.add "  /**\n"
      for line in lines:
        classes.add &"   * {line}\n"
      classes.add "   */\n"

    classes.add &"  {exportTypeCpp(procReturn)} {procName}("
    for param in procParams[1..^1]:
      classes.add exportTypeCpp(param[1], param[0].getName())
      classes.add ", "
    classes.removeSuffix ", "
    classes.add ");\n\n"

    members.add &"{exportTypeCpp(procReturn)} {owner.getName()}::{procName}("
    for param in procParams[1..^1]:
      members.add exportTypeCpp(param[1], param[0].getName())
      members.add ", "
    members.removeSuffix ", "
    members.add ") "
    members.add "{\n"
    if procReturn.kind == nnkEmpty:
      members.add &"  "
    else:
      members.add &"  return "
    members.add  &"$lib_{apiProcName}("
    members.add "*this, "
    for param in procParams[1..^1]:
      members.add param[0].getName()
      members.add ", "
    members.removeSuffix ", "
    members.add ");\n"
    members.add "};\n\n"

proc exportObjectCpp*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  types.add &"struct {objName};\n\n"

  classes.add &"struct {objName} " & "{\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      classes.add &"  {exportTypeCpp(identDefs[^2], toSnakeCase(property[1].repr))};\n"

  if constructor != nil:
    exportProcCpp(constructor)
  else:
    procs.add &"{objName} $lib_{toSnakeCase(objName)}("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        procs.add &"{exportTypeCpp(identDefs[^2], toSnakeCase(property[1].repr))}, "
    procs.removeSuffix ", "
    procs.add ");\n\n"

    members.add &"{objName} {objName.unCapitalize()}("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        members.add &"{exportTypeCpp(identDefs[^2], property[1].repr)}"
        members.add ", "
    members.removeSuffix ", "
    members.add ") "
    members.add "{\n"
    members.add &"  return "
    members.add  &"$lib_{toSnakeCase(objName)}("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        members.add property[1].repr
        members.add ", "
    members.removeSuffix ", "
    members.add ");\n"
    members.add "};\n\n"

  dllProc(&"$lib_{toSnakeCase(objName)}_eq", [&"{objName} a", &"{objName} b"], "char")

proc genRefObject(objName: string) =

  types.add &"struct {objName};\n\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

  dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  let objArg = objName & " " & toSnakeCase(objName)
  dllProc(&"{procPrefix}_len", [objArg], "int64_t")
  dllProc(&"{procPrefix}_get", [objArg, "int64_t index"], exportTypeCpp(entryType))
  dllProc(&"{procPrefix}_set", [objArg, "int64_t index", exportTypeCpp(entryType, "value")], "void")
  dllProc(&"{procPrefix}_delete", [objArg, "int64_t index"], "void")
  dllProc(&"{procPrefix}_add", [objArg, exportTypeCpp(entryType, "value")], "void")
  dllProc(&"{procPrefix}_clear", [objArg], "void")

proc exportRefObjectCpp*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  genRefObject(objName)

  classes.add &"struct {objName} " & "{\n\n"
  classes.add &"  private:\n\n"
  classes.add &"  uint64_t reference;\n\n"
  classes.add &"  public:\n\n"

  if constructor != nil:
      let
        constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
        constructorType = constructor.getTypeInst()
        constructorParams = constructorType[0][1 .. ^1]
        constructorRaises = constructor.raises()

      classes.add &"  {objName}("
      for param in constructorParams:
        classes.add exportTypeCpp(param[1], param[0].getName())
        classes.add ", "
      classes.removeSuffix ", "
      classes.add ");\n\n"

      members.add &"{objName}::{objName}("
      for param in constructorParams:
        members.add exportTypeCpp(param[1], param[0].getName())
        members.add ", "
      members.removeSuffix ", "
      members.add ")"
      members.add " {\n"
      members.add &"  this->reference = "
      members.add  &"{constructorLibProc}("
      for param in constructorParams:
        members.add param[0].getName()
        members.add ", "
      members.removeSuffix ", "
      members.add ").reference;\n"
      members.add "}\n\n"

      var dllParams: seq[(NimNode, NimNode)]
      for param in constructorParams:
        dllParams.add((param[0], param[1]))
      dllProc(constructorLibProc, dllParams, objName)

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"
      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      let getMemberName = &"get{fieldName.capitalizeAscii}"
      let setMemberName = &"set{fieldName.capitalizeAscii}"

      dllProc(getProcName, [objName & " " & objNameSnaked], exportTypeCpp(fieldType))
      dllProc(setProcName, [objName & " " & objNameSnaked, exportTypeCpp(fieldType, "value")], exportTypeCpp(nil))

      classes.add &"  {exportTypeCpp(fieldType)} {getMemberName}();\n"

      members.add &"{exportTypeCpp(fieldType)} {objName}::{getMemberName}()" & "{\n"
      members.add &"  return {getProcName}(*this);\n"
      members.add "}\n\n"

      classes.add &"  void {setMemberName}({exportTypeCpp(fieldType)} value);\n\n"

      members.add &"void {objName}::{setMemberName}({exportTypeCpp(fieldType)} value)" & "{\n"
      members.add &"  {setProcName}(*this, value);\n"
      members.add "}\n\n"

      # TODO: property
      # classes.add &"  __declspec(property(get={getMemberName},put={setMemberName})) {exportTypeCpp(fieldType)} {fieldName};\n\n"

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

  # TODO: ref/unref
  # classes.add &"  ~{objName}();\n\n"

  # members.add &"{objName}::~{objName}()" & "{\n"
  # members.add &"  // $lib_{toSnakeCase(objName)}_unref(*this);\n"
  # members.add "}\n\n"

  classes.add &"  void free();\n\n"

  members.add &"void {objName}::free()" & "{\n"
  members.add &"  $lib_{toSnakeCase(objName)}_unref(*this);\n"
  members.add "}\n\n"

proc exportCloseObjectCpp*() =

  classes.add "};\n\n"

proc exportSeqCpp*(sym: NimNode) =
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

  classes.add &"struct {seqName} " & "{\n\n"
  classes.add &"  private:\n\n"
  classes.add &"  uint64_t reference;\n\n"
  classes.add &"  public:\n\n"

  classes.add &"  void free();\n\n"

  members.add &"void {seqName}::free()" & "{\n"
  members.add &"  $lib_{toSnakeCase(seqName)}_unref(*this);\n"
  members.add "}\n\n"


const header = """
#ifndef INCLUDE_$LIB_H
#define INCLUDE_$LIB_H

#include <stdint.h>

"""

const footer = """
#endif
"""

proc writeCpp*(dir, lib: string) =
  writeFile(&"{dir}/{toSnakeCase(lib)}.hpp", (
      header &
      types &
      classes &
      "extern \"C\" {\n\n" &
      procs &
      "}\n\n" &
      members &
      footer
    ).replace("$lib", toSnakeCase(lib)).replace("$LIB", lib.toUpperAscii())
  )
