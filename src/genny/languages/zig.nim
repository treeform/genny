import ../common, macros, strformat, strutils

var
  code {.compiletime.}: string

proc exportTypeZig(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeZig(sym[2])
      result = &"[{entryCount}]{entryType}"
    elif sym[0].repr == "seq":
      result = &"*{sym.getSeqName()}"
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
      if sym.typeKind == ntyRef and sym.repr != "nil":
        result = &"*{sym.repr}"
      else:
        result =
          case sym.repr:
          of "string": "[:0]const u8"
          of "bool": "bool"
          of "int8": "i8"
          of "byte": "u8"
          of "int16": "i16"
          of "int32": "i32"
          of "int64": "i63"
          of "int": "isize"
          of "uint8": "u8"
          of "uint16": "u16"
          of "uint32": "u32"
          of "uint64": "u64"
          of "uint": "usize"
          of "float32": "f32"
          of "float64": "f64"
          of "float": "f64"
          of "Rune": "u21"
          of "Vec2": "Vector2"
          of "Mat3": "Matrix3"
          of "", "nil": "void"
          else:
            sym.repr

proc convertExportFromZig*(inner: string, sym: string): string =
  if sym == "[:0]const u8":
    inner & ".ptr"
  else:
    inner

proc convertImportToZig*(inner: string, sym: string): string =
  if sym == "[:0]const u8":
    "std.mem.span(" & inner & ")"
  else:
    inner

proc toArgSeq(args: seq[NimNode]): seq[(string, string)] =
  for i, arg in args[0 .. ^1]:
    result.add (arg[0].repr, arg[1].exportTypeZig())

proc dllProc*(procName: string, args: openarray[string], resType: string) =
  discard

proc exportConstZig*(sym: NimNode) =
  code.add &"pub const {toSnakeCase(sym.repr)} = {sym.getImpl()[2].repr};\n\n"

proc exportEnumZig*(sym: NimNode) =
  code.add &"pub const {sym.repr} = enum(u8) " & "{\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    code.add &"    {toCapSnakeCase(entry.repr).toLowerAscii()} = {i},\n"
  code.add "};\n\n"

proc exportProc(
  procName: string,
  apiProcName: string,
  procParams: seq[(string, string)],
  procReturn = "",
  procRaises = false,
  owner = "",
  indent = false,
  comments = ""
) =
  let onClass = owner notin ["void", ""]
  let indent =
    if onClass:
      true
    else:
      indent

  if indent:
    code.add "    "

  code.add &"extern fn {apiProcName}("
  for i, param in procParams:
    if onClass and i == 0:
      code.add "self"
    else:
      code.add toSnakeCase(param[0])
    code.add ": "
    code.add param[1].replace("[:0]", "[*:0]")
    code.add &", "
  code.removeSuffix ", "
  code.add ") callconv(.C) "
  if procReturn != "":
    code.add procReturn.replace("[:0]", "[*:0]");
  else:
    code.add "void"
  code.add ";\n"

  if comments != "":
    for line in comments.split("\n"):
      var line = line
      line.removePrefix("##")
      if indent:
        code.add "    "
      code.add "/// " & line.strip() & "\n"

  if indent:
    code.add "    "

  code.add &"pub inline fn {procName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      code.add "self"
    else:
      code.add toSnakeCase(param[0])
    code.add ": "
    code.add param[1]
    code.add &", "
  code.removeSuffix ", "
  code.add ") "
  if procReturn != "":
    code.add procReturn;
  else:
    code.add "void"
  code.add " "
  code.add "{\n"

  if indent:
    code.add "    "
  code.add "    return "

  var call = ""
  call.add apiProcName
  call.add "("
  for i, param in procParams:
    if onClass and i == 0:
      call.add "self"
    else:
      call.add convertExportFromZig(
        toSnakeCase(param[0]),
        param[1]
      )
    call.add ", "
  call.removeSuffix ", "
  call.add &")"
  code.add convertImportToZig(call, procReturn)
  code.add ";\n"
  if indent:
    code.add "    "
  code.add "}\n\n"

proc exportProcZig*(
  sym: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = [],
  indent = false,
  rename = "",
) =
  var
    procName = sym.repr
  let
    procNameSnaked = toSnakeCase(procName)
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1].toArgSeq()
    procReturn = procType[0][0].exportTypeZig()
    procRaises = sym.raises()
    comments =
      if sym.getImpl()[6][0].kind == nnkCommentStmt:
        sym.getImpl()[6][0].repr
      elif sym.getImpl[6].kind == nnkAsgn and
        sym.getImpl[6][1].kind == nnkStmtListExpr and
        sym.getImpl[6][1][0].kind == nnkCommentStmt:
        sym.getImpl[6][1][0].repr
      else:
        ""

  var apiProcName = ""
  apiProcName.add "$lib_"
  if owner != nil:
    apiProcName.add &"{toSnakeCase(owner.getName())}_"
  for prefix in prefixes:
    apiProcName.add &"{toSnakeCase(prefix.getName())}_"
    procName.add prefix.getName()
  apiProcName.add &"{procNameSnaked}"

  if rename != "":
    procName = rename

  exportProc(
    procName,
    apiProcName,
    procParams = procParams,
    procReturn = procReturn,
    procRaises = procRaises,
    owner.exportTypeZig(),
    indent,
    comments
  )

proc exportCloseObjectZig*() =
  code.removeSuffix "\n"
  code.add "};\n\n"

proc exportObjectZig*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  code.add &"pub const {objName} = extern struct " & "{\n"

  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      code.add &"    {toSnakeCase(property[1].repr)}"
      code.add ": "
      code.add exportTypeZig(identDefs[^2])
      code.add ",\n"
  code.add "\n"

  if constructor != nil:
    exportProcZig(constructor, indent = true, rename = "init")
  else:
    code.add "    pub fn init("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        code.add toSnakeCase(property[1].repr)
        code.add ": "
        code.add exportTypeZig(identDefs[^2])
        code.add ", "
    code.removeSuffix ", "
    code.add ") "
    code.add objName
    code.add " {\n"
    code.add &"        return {objName}" & "{\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        code.add &"            .{toSnakeCase(property[1].repr)}"
        code.add " = "
        code.add &"{toSnakeCase(property[1].repr)}"
        code.add ",\n"
    code.add "        };\n"
    code.add "    }\n\n"

  exportProc(
    "eql",
    &"$lib_{toSnakeCase(objName)}_eq",
    @[("self", objName), ("other", objName)],
    "bool",
    indent = true
  )

proc genRefObject(objName: string) =
  code.add &"pub const {objName} = opaque " & "{\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"
  code.add &"    extern fn {unrefLibProc}(self: *{objName}) callconv(.C) void;\n"
  code.add &"    pub inline fn deinit(self: *{objName}) void " & "{\n"
  code.add &"        return {unrefLibProc}(self);\n"
  code.add "    }\n\n"

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  exportProc(
    &"len{selfSuffix}",
    &"{procPrefix}_len",
    @[("self", objName)],
    "isize",
    indent = true
  )
  exportProc(
    &"get{selfSuffix}",
    &"{procPrefix}_get",
    @[("self", objName), ("index", "isize")],
    entryType.exportTypeZig(),
    indent = true
  )
  exportProc(
    &"set{selfSuffix}",
    &"{procPrefix}_set",
    @[("self", objName), ("index", "isize"), ("value", entryType.exportTypeZig())],
    indent = true
  )
  exportProc(
    &"append{selfSuffix}",
    &"{procPrefix}_add",
    @[("self", objName), ("value", entryType.exportTypeZig())],
    indent = true
  )
  exportProc(
    &"remove{selfSuffix}",
    &"{procPrefix}_delete",
    @[("self", objName), ("index", "isize")],
    indent = true
  )
  exportProc(
    &"clear{selfSuffix}",
    &"{procPrefix}_clear",
    @[("self", objName)],
    indent = true
  )

proc exportRefObjectZig*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  discard
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1].getType()

  genRefObject(objName)

  if constructor != nil:
    exportProcZig(constructor, indent = true, rename = "init")

  for (fieldName, fieldType) in fields:
    let
      fieldNameSnaked = toSnakeCase(fieldName)
      fieldNameCapped = capitalizeAscii(fieldName)

    if fieldType.kind != nnkBracketExpr:
      exportProc(
        "get" & fieldNameCapped,
        &"$lib_{objNameSnaked}_get_{fieldNameSnaked}",
        @[("self", &"*{objName}")],
        fieldType.exportTypeZig(),
        indent = true
      )
      exportProc(
        "set" & fieldNameCapped,
        &"$lib_{objNameSnaked}_set_{fieldNameSnaked}",
        @[("self", &"*{objName}"), ("value", fieldType.exportTypeZig())],
        indent = true
      )
    else:
      genSeqProcs(
        &"*{objName}",
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        fieldNameCapped,
        fieldType[1]
      )

proc exportSeqZig*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  exportProc(
    "init",
    &"$lib_new_{seqNameSnaked}",
    @[],
    &"*{seqName}",
    indent = true
  )

  genSeqProcs(
    &"*{seqName}",
    &"$lib_{seqNameSnaked}",
    "",
    sym[1]
  )

const header = """
const std = @import("std");

"""

proc writeZig*(dir, lib: string) =
  writeFile(&"{dir}/{toSnakeCase(lib)}.zig",
    (header & code)
    .replace("$Lib", lib)
    .replace("$lib", toSnakeCase(lib))
    .replace(" test,", " test_value,")
    .replace(" test:", " test_value:")
    .replace(" transform,", " transform_value,")
    .replace(" transform:", " transform_value:")
    .replace(" transform)", " transform_value)")
    .replace(" blur,", " blur_value,")
    .replace(" blur:", " blur_value:")
  )
