import ../common, macros, strformat, strutils

var
  code {.compiletime.}: string

const operators = ["add", "sub", "mul", "div"]

proc unCapitalize(s: string): string =
  s[0].toLowerAscii() & s[1 .. ^1]

proc exportTypeZig(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeZig(sym[2])
      result = &"[{entryCount}]{entryType}"
    elif sym[0].repr == "seq":
      result = sym.getSeqName()
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
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
      of "Rune": "i32"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "", "nil": "void"
      else:
        sym.repr

proc convertExportFromZig*(inner: string, sym: string): string =
  if sym == "string":
    inner & ".ptr"
  else:
    inner

proc convertImportToZig*(inner: string, sym: string): string =
  if sym == "string":
    "std.mem.span(" & inner & ")"
  else:
    inner

proc toArgTypes(args: openarray[NimNode]): seq[string] =
  for arg in args:
    result.add exportTypeZig(arg)

proc dllProc*(procName: string, args: openarray[string], resType: string) =
  var argTypes = join(args, ", ")
  argTypes.removeSuffix ", "
  code.add &"{procName}.argtypes = [{argTypes}]\n"
  code.add &"{procName}.restype = {resType}\n"
  code.add "\n"

proc exportConstZig*(sym: NimNode) =
  code.add &"pub const {toSnakeCase(sym.repr)} = {sym.getImpl()[2].repr};\n\n"

proc exportEnumZig*(sym: NimNode) =
  code.add &"pub const {sym.repr} = enum(u8) " & "{\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    code.add &"  {toCapSnakeCase(entry.repr).toLowerAscii()} = {i},\n"
  code.removeSuffix "\n"
  code.add "\n};\n\n"

proc toArgSeq(args: seq[NimNode]): seq[(string, string)] =
  for i, arg in args[0 .. ^1]:
    result.add (arg[0].repr, arg[1].exportTypeZig)

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

  code.add &"extern \"$lib\" fn {apiProcName}("
  for i, param in procParams:
    if onClass and i == 0:
      code.add "self"
      code.add ": "
      code.add owner
    else:
      code.add toSnakeCase(param[0])
      code.add ": "
      code.add param[1].replace("[:0]const", "[*:0]const")
    code.add &", "
  code.removeSuffix ", "
  code.add ") callconv(.C)"
  if procReturn != "":
    code.add procReturn;
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
      code.add ": "
      code.add owner
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
  code.add &"    "
  if procReturn != "":
    code.add "return "

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
    procReturn = procType[0][0].exportTypeZig
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
    code.add &"    pub inline fn init("
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
    code.add &"        var self: {objName} = undefined;\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        code.add &"        self."
        code.add toSnakeCase(property[1].repr)
        code.add " = "
        code.add toSnakeCase(property[1].repr)
        code.add ";\n"
    code.add "        return self;\n"
    code.add "    }\n\n"


proc exportCloseObjectZig*() =
  code.add "};\n\n"

proc genRefObject(objName: string) =
  code.add &"pub const {objName} = extern struct " & "{\n\n"

  code.add "    reference: u64,\n"

  # code.add "    def __bool__(self):\n"
  # code.add "        return self.ref != None\n"
  # code.add "\n"

  # code.add "    def __eq__(self, obj):\n"
  # code.add "        return self.ref == obj.ref\n"
  # code.add "\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"
  code.add &"    extern fn {unrefLibProc}(self: {objName}) callconv(.C) void;\n"
  code.add &"    pub inline fn deinit(self: {objName}) void " & "{\n"
  code.add &"        {unrefLibProc}(self);\n"
  code.add "    }\n\n"

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  discard
  # var baseIndent = "    "
  # if selfSuffix != "": # This is a bound seq
  #   baseIndent = "        "

  # code.add &"{baseIndent}def __len__(self):\n"
  # code.add &"{baseIndent}    return dll.{procPrefix}_len(self{selfSuffix})\n"
  # code.add "\n"

  # code.add &"{baseIndent}def __getitem__(self, index):\n"
  # code.add &"{baseIndent}    return dll.{procPrefix}_get(self{selfSuffix}, index){convertImportToZig(entryType)}\n"
  # code.add "\n"

  # code.add &"{baseIndent}def __setitem__(self, index, value):\n"
  # code.add &"{baseIndent}    dll.{procPrefix}_set(self{selfSuffix}, index, value{convertExportFromZig(entryType)})\n"
  # code.add "\n"

  # code.add &"{baseIndent}def __delitem__(self, index):\n"
  # code.add &"{baseIndent}    dll.{procPrefix}_delete(self{selfSuffix}, index)\n"
  # code.add "\n"

  # code.add &"{baseIndent}def append(self, value):\n"
  # code.add &"{baseIndent}    dll.{procPrefix}_add(self{selfSuffix}, value)\n"
  # code.add "\n"

  # code.add &"{baseIndent}def clear(self):\n"
  # code.add &"{baseIndent}    dll.{procPrefix}_clear(self{selfSuffix})\n"
  # code.add "\n"

  # code.add &"{baseIndent}def __iter__(self):\n"
  # code.add &"{baseIndent}    return SeqIterator(self)\n"
  # code.add "\n"

  # dllProc(&"dll.{procPrefix}_len", [objName], "c_longlong")
  # dllProc(&"dll.{procPrefix}_get", [objName, "c_longlong"], exportTypeZig(entryType))
  # dllProc(&"dll.{procPrefix}_set", [objName, "c_longlong", exportTypeZig(entryType)], "None")
  # dllProc(&"dll.{procPrefix}_delete", [objName, "c_longlong"], "None")
  # dllProc(&"dll.{procPrefix}_add", [objName, exportTypeZig(entryType)], "None")
  # dllProc(&"dll.{procPrefix}_clear", [objName], "None")

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
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      exportProc(
        "get" & fieldName.capitalizeAscii(),
        &"$lib_{objNameSnaked}_get_{fieldNameSnaked}",
        @[("self", objName)],
        fieldType.exportTypeZig(),
        indent = true
      )

      exportProc(
        "set" & fieldName.capitalizeAscii(),
        &"$lib_{objNameSnaked}_set_{fieldNameSnaked}",
        @[("self", objName), ("value", fieldType.exportTypeZig())],
        indent = true
      )

      # code.add "    @property\n"
      # code.add &"    def {fieldNameSnaked}(self):\n"
      # code.add "        "
      # code.add &"return {getProcName}(self){convertImportToZig(fieldType)}\n"

      # let setProcName = &"dll.$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      # code.add "\n"
      # code.add &"    @{fieldNameSnaked}.setter\n"
      # code.add &"    def {fieldNameSnaked}(self, {fieldNameSnaked}):\n"
      # code.add "        "
      # code.add &"{setProcName}(self, "
      # code.add &"{fieldNameSnaked}{convertExportFromZig(fieldType)}"
      # code.add ")\n"
      # code.add "\n"

      # dllProc(getProcName, toArgTypes([sym]), exportTypeZig(fieldType))
      # dllProc(setProcName, toArgTypes([sym, fieldType]), exportTypeZig(nil))

    else:
      discard
      # var helperName = fieldName
      # helperName[0] = toUpperAscii(helperName[0])
      # let helperClassName = objName & helperName

      # code.add &"    class {helperClassName}:\n"
      # code.add "\n"
      # code.add &"        def __init__(self, {toSnakeCase(objName)}):\n"
      # code.add &"            self.{toSnakeCase(objName)} = {toSnakeCase(objName)}\n"
      # code.add "\n"

      # genSeqProcs(
      #   objName,
      #   &"$lib_{objNameSnaked}_{fieldNameSnaked}",
      #   &".{toSnakeCase(objName)}",
      #   fieldType[1]
      # )

      # code.add "    @property\n"
      # code.add &"    def {toSnakeCase(helperName)}(self):\n"
      # code.add &"        return self.{helperClassName}(self)\n"
      # code.add "\n"

proc exportSeqZig*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  # let newSeqProc = &"dll.$lib_new_{toSnakeCase(seqName)}"

  # code.add "    def __init__(self):\n"
  # code.add &"        self.ref = {newSeqProc}()\n"
  # code.add "\n"

  # dllProc(newSeqProc, [], "c_ulonglong")

  # genSeqProcs(
  #   sym.getName(),
  #   &"$lib_{seqNameSnaked}",
  #   "",
  #   sym[1]
  # )

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
