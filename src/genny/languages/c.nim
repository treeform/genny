import
  std/[os, strformat, strutils, macros],
  ../common

var
  types {.compiletime.}: string
  procs {.compiletime.}: string

proc stripSink(sym: NimNode): NimNode =
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc isSeqLike(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr in ["seq", "openArray"]

proc exportTypeC(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = typ[1].repr
        entryType = exportTypeC(typ[2])
      result = &"{entryType}[{entryCount}]"
    elif typ.isSeqLike:
      result = typ.getSeqName()
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result =
      case typ.repr:
      of "string", "cstring": "const char*"
      of "bool": "char"
      of "byte": "uint8_t"
      of "int8": "int8_t"
      of "int16": "int16_t"
      of "int32": "int32_t"
      of "int64": "int64_t"
      of "int": "intptr_t"
      of "uint8": "uint8_t"
      of "uint16": "uint16_t"
      of "uint32": "uint32_t"
      of "uint64": "uint64_t"
      of "uint": "uintptr_t"
      of "float32": "float"
      of "float64": "double"
      of "float": "double"
      of "Rune": "int32_t"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "", "nil": "void"
      of "None": "void"
      else:
        typ.repr

proc exportReturnTypeC(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.repr == "string":
    "GennyBuffer"
  else:
    exportTypeC(typ)

proc exportTypeC(sym: NimNode, name: string): string =
  let typ = sym.stripSink
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = typ[1].repr
        entryType = exportTypeC(typ[2], &"{name}[{entryCount}]")
      result = &"{entryType}"
    elif typ.isSeqLike:
      result = typ.getSeqName() & " " & name
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result = exportTypeC(typ) & " " & name

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
  dllProc(&"$lib_{apiProcName}", dllParams, exportReturnTypeC(procReturn))

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
  types.add &"typedef struct {objName}Handle* {objName};\n\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

  dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  let objArg = objName & " " & toSnakeCase(objName)
  dllProc(&"{procPrefix}_len", [objArg], "intptr_t")
  dllProc(&"{procPrefix}_get", [objArg, "intptr_t index"], exportReturnTypeC(entryType))
  dllProc(&"{procPrefix}_set", [objArg, "intptr_t index", exportTypeC(entryType, "value")], "void")
  dllProc(&"{procPrefix}_delete", [objArg, "intptr_t index"], "void")
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

      dllProc(getProcName, [objName & " " & objNameSnaked], exportReturnTypeC(fieldType))
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

#include <stdint.h>

typedef struct GennyBufferHandle* GennyBuffer;

"""

const bufferProcs = """
const char* $lib_genny_buffer_data(GennyBuffer buffer);
intptr_t $lib_genny_buffer_len(GennyBuffer buffer);
void $lib_genny_buffer_unref(GennyBuffer buffer);
"""

const externCStart = """
#ifdef __cplusplus
extern "C" {
#endif

"""

const externCEnd = """
#ifdef __cplusplus
}
#endif

"""

const footer = """
#endif
"""

proc writeC*(dir, lib: string) =
  createDir(dir)
  writeFile(&"{dir}/{toSnakeCase(lib)}.h", (header & types & externCStart & bufferProcs & procs & externCEnd & footer)
    .replace("$lib", toSnakeCase(lib)).replace("$LIB", lib.toUpperAscii())
  )
