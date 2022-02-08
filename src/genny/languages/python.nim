import ../common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string

const operators = ["add", "sub", "mul", "div"]

proc exportTypePy(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypePy(sym[2])
      result = &"{entryType} * {entryCount}"
    elif sym[0].repr == "seq":
      result = sym.getSeqName()
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result =
      case sym.repr:
      of "string": "c_char_p"
      of "bool": "c_bool"
      of "int8": "c_byte"
      of "byte": "c_byte"
      of "int16": "c_short"
      of "int32": "c_int"
      of "int64": "c_longlong"
      of "int": "c_longlong"
      of "uint8": "c_ubyte"
      of "uint16": "c_ushort"
      of "uint32": "c_uint"
      of "uint64": "c_ulonglong"
      of "uint": "c_ulonglong"
      of "float32": "c_float"
      of "float64": "c_double"
      of "float": "c_double"
      of "Rune": "c_int"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "", "nil": "None"
      else:
        sym.repr

proc convertExportFromPy*(sym: NimNode): string =
  if sym.repr == "string":
    result = ".encode(\"utf8\")"

proc convertImportToPy*(sym: NimNode): string =
  if sym.repr == "string":
    result = ".decode(\"utf8\")"

proc toArgTypes(args: openarray[NimNode]): seq[string] =
  for arg in args:
    result.add exportTypePy(arg)

proc dllProc*(procName: string, args: openarray[string], restype: string) =
  var argtypes = join(args, ", ")
  argtypes.removeSuffix ", "
  procs.add &"{procName}.argtypes = [{argtypes}]\n"
  procs.add &"{procName}.restype = {restype}\n"
  procs.add "\n"

proc exportConstPy*(sym: NimNode) =
  types.add &"{toCapSnakeCase(sym.repr)} = {sym.getImpl()[2].repr}\n"
  types.add "\n"

proc exportEnumPy*(sym: NimNode) =
  types.add &"{sym.repr} = c_byte\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    types.add &"{toCapSnakeCase(entry.repr)} = {i}\n"
  types.add "\n"

proc exportProcPy*(
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
    procRaises = sym.raises()
    onClass = owner != nil

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

  if onClass:
    types.add "    def "
    if sym.repr in operators and
      procReturn.kind != nnkEmpty and
      prefixes.len == 0:
      types.add &"__{sym.repr}__("
    else:
      if prefixes.len > 0:
        if prefixes[0].getImpl().kind != nnkNilLIt:
          if prefixes[0].getImpl()[2].kind != nnkEnumTy:
            types.add &"{toSnakeCase(prefixes[0].repr)}_"
      types.add &"{toSnakeCase(sym.repr)}("
  else:
    types.add &"def {apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      types.add "self"
    else:
      types.add toSnakeCase(param[0].repr)
      case defaults[i][1].kind:
      of nnkIntLit, nnkFloatLit:
        types.add &" = {defaults[i][1].repr}"
      of nnkIdent:
        if defaults[i][1].repr == "true":
          types.add " = True"
        elif defaults[i][1].repr == "false":
          types.add " = False"
        else:
          types.add &" = {toCapSnakeCase(defaults[i][1].repr)}"
      else:
        if defaults[i][1].kind != nnkEmpty:
          types.add &" = None"
    types.add &", "
  types.removeSuffix ", "
  types.add "):\n"
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
    if onClass: types.add "    "
    types.add "    \"\"\"\n"
    for line in lines:
      if onClass: types.add "    "
      types.add &"    {line}\n"
    if onClass: types.add "    "
    types.add "    \"\"\"\n"
  for i, param in procParams:
    if i == 0:
      continue
    if defaults[i][1].kind notin {nnkEmpty, nnkIntLit, nnkFloatLit, nnkIdent}:
      if onClass:
          types.add "    "
      types.add &"    if {toSnakeCase(param[0].repr)} is None:\n"
      if onClass:
          types.add "    "
      types.add &"        {toSnakeCase(param[0].repr)} = "
      types.add &"{exportTypePy(param[1])}("
      if defaults[i][1].kind == nnkCall:
        for d in defaults[i][1][1 .. ^1]:
          types.add &"{d.repr}, "
      types.removeSuffix ", "
      types.add ")\n"

  if onClass:
    types.add "    "
  types.add "    "
  if procReturn.kind != nnkEmpty:
    types.add "result = "
  types.add &"dll.$lib_{apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      types.add "self"
    else:
      types.add &"{toSnakeCase(param[0].repr)}{convertExportFromPy(param[1])}"
    types.add &", "
  types.removeSuffix ", "
  types.add &"){convertImportToPy(procReturn)}\n"
  if procRaises:
    if onClass:
      types.add "    "
    types.add &"    if check_error():\n"
    if onClass:
      types.add "    "
    types.add "        raise $LibError("
    types.add "take_error()"
    types.add ")\n"
  if procReturn.kind != nnkEmpty:
    if onClass:
      types.add "    "
    types.add "    return result\n"
  types.add "\n"

  var dllParams: seq[NimNode]
  for param in procParams:
    dllParams.add(param[1])
  dllProc(&"dll.$lib_{apiProcName}", toArgTypes(dllParams), exportTypePy(procReturn))

proc exportObjectPy*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  types.add &"class {objName}(Structure):\n"
  types.add "    _fields_ = [\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"        (\"{toSnakeCase(property[1].repr)}\""
      types.add ", "
      types.add &"{exportTypePy(identDefs[^2])}),\n"
  types.removeSuffix ",\n"
  types.add "\n"
  types.add "    ]\n"
  types.add "\n"

  if constructor != nil:
    let
      constructorType = constructor.getTypeInst()
      constructorParams = constructorType[0][1 .. ^1]
    types.add "    def __init__(self, "
    for param in constructorParams:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add "):\n"
    types.add &"        tmp = dll.$lib_{toSnakeCase(objName)}("
    for param in constructorParams:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add ")\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add &"        self.{toSnakeCase(property[1].repr)} = "
        types.add &"tmp.{toSnakeCase(property[1].repr)}\n"
    types.add "\n"
    var dllParams: seq[NimNode]
    for param in constructorParams:
      dllParams.add(param[1])
    dllProc(&"dll.$lib_{toSnakeCase(objName)}", toArgTypes(dllParams), objName)
  else:
    types.add "    def __init__(self, "
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add &"{toSnakeCase(property[1].repr)}, "
    types.removeSuffix ", "
    types.add "):\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add "        "
        types.add &"self.{toSnakeCase(property[1].repr)} = "
        types.add &"{toSnakeCase(property[1].repr)}\n"
    types.add "\n"

  types.add "    def __eq__(self, obj):\n"
  types.add "        return "
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      if identDefs[^2].len > 0 and identDefs[^2][0].repr == "array":
        for i in 0 ..< identDefs[^2][1].intVal:
          types.add &"self.{toSnakeCase(property[1].repr)}[{i}] == obj.{toSnakeCase(property[1].repr)}[{i}] and "
      else:
        types.add &"self.{toSnakeCase(property[1].repr)} == obj.{toSnakeCase(property[1].repr)} and "
  types.removeSuffix " and "
  types.add "\n"
  types.add "\n"

proc genRefObject(objName: string) =
  types.add &"class {objName}(Structure):\n"
  types.add "    _fields_ = [(\"ref\", c_ulonglong)]\n"
  types.add "\n"

  types.add "    def __bool__(self):\n"
  types.add "        return self.ref != None\n"
  types.add "\n"

  types.add "    def __eq__(self, obj):\n"
  types.add "        return self.ref == obj.ref\n"
  types.add "\n"

  let unrefLibProc = &"dll.$lib_{toSnakeCase(objName)}_unref"

  types.add "    def __del__(self):\n"
  types.add &"        {unrefLibProc}(self)\n"
  types.add "\n"

  dllProc(unrefLibProc, [objName], "None")

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  var baseIndent = "    "
  if selfSuffix != "": # This is a bound seq
    baseIndent = "        "

  types.add &"{baseIndent}def __len__(self):\n"
  types.add &"{baseIndent}    return dll.{procPrefix}_len(self{selfSuffix})\n"
  types.add "\n"

  types.add &"{baseIndent}def __getitem__(self, index):\n"
  types.add &"{baseIndent}    return dll.{procPrefix}_get(self{selfSuffix}, index){convertImportToPy(entryType)}\n"
  types.add "\n"

  types.add &"{baseIndent}def __setitem__(self, index, value):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_set(self{selfSuffix}, index, value{convertExportFromPy(entryType)})\n"
  types.add "\n"

  types.add &"{baseIndent}def __delitem__(self, index):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_delete(self{selfSuffix}, index)\n"
  types.add "\n"

  types.add &"{baseIndent}def append(self, value):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_add(self{selfSuffix}, value)\n"
  types.add "\n"

  types.add &"{baseIndent}def clear(self):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_clear(self{selfSuffix})\n"
  types.add "\n"

  types.add &"{baseIndent}def __iter__(self):\n"
  types.add &"{baseIndent}    return SeqIterator(self)\n"
  types.add "\n"

  dllProc(&"dll.{procPrefix}_len", [objName], "c_longlong")
  dllProc(&"dll.{procPrefix}_get", [objName, "c_longlong"], exportTypePy(entryType))
  dllProc(&"dll.{procPrefix}_set", [objName, "c_longlong", exportTypePy(entryType)], "None")
  dllProc(&"dll.{procPrefix}_delete", [objName, "c_longlong"], "None")
  dllProc(&"dll.{procPrefix}_add", [objName, exportTypePy(entryType)], "None")
  dllProc(&"dll.{procPrefix}_clear", [objName], "None")

proc exportRefObjectPy*(
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
      constructorLibProc = &"dll.$lib_{toSnakeCase(constructor.repr)}"
      constructorType = constructor.getTypeInst()
      constructorParams = constructorType[0][1 .. ^1]
      constructorRaises = constructor.raises()

    types.add "    def __init__(self, "
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add "):\n"
    types.add &"        result = "
    types.add &"{constructorLibProc}("
    for param in constructorParams:
      types.add &"{toSnakeCase(param[0].repr)}{convertExportFromPy(param[1])}"
      types.add ", "
    types.removeSuffix ", "
    types.add ")\n"
    if constructorRaises:
      types.add &"        if check_error():\n"
      types.add "            raise $LibError("
      types.add "take_error()"
      types.add ")\n"
    types.add "        self.ref = result\n"
    types.add "\n"

    var dllParams: seq[NimNode]
    for param in constructorParams:
      dllParams.add(param[1])
    dllProc(constructorLibProc, toArgTypes(dllParams), "c_ulonglong")

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"dll.$lib_{objNameSnaked}_get_{fieldNameSnaked}"

      types.add "    @property\n"
      types.add &"    def {fieldNameSnaked}(self):\n"
      types.add "        "
      types.add &"return {getProcName}(self){convertImportToPy(fieldType)}\n"

      let setProcName = &"dll.$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      types.add "\n"
      types.add &"    @{fieldNameSnaked}.setter\n"
      types.add &"    def {fieldNameSnaked}(self, {fieldNameSnaked}):\n"
      types.add "        "
      types.add &"{setProcName}(self, "
      types.add &"{fieldNameSnaked}{convertExportFromPy(fieldType)}"
      types.add ")\n"
      types.add "\n"

      dllProc(getProcName, toArgTypes([sym]), exportTypePy(fieldType))
      dllProc(setProcName, toArgTypes([sym, fieldType]), exportTypePy(nil))
    else:
      var helperName = fieldName
      helperName[0] = toUpperAscii(helperName[0])
      let helperClassName = objName & helperName

      types.add &"    class {helperClassName}:\n"
      types.add "\n"
      types.add &"        def __init__(self, {toSnakeCase(objName)}):\n"
      types.add &"            self.{toSnakeCase(objName)} = {toSnakeCase(objName)}\n"
      types.add "\n"

      genSeqProcs(
        objName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        &".{toSnakeCase(objName)}",
        fieldType[1]
      )

      types.add "    @property\n"
      types.add &"    def {toSnakeCase(helperName)}(self):\n"
      types.add &"        return self.{helperClassName}(self)\n"
      types.add "\n"

proc exportSeqPy*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  let newSeqProc = &"dll.$lib_new_{toSnakeCase(seqName)}"

  types.add "    def __init__(self):\n"
  types.add &"        self.ref = {newSeqProc}()\n"
  types.add "\n"

  dllProc(newSeqProc, [], "c_ulonglong")

  genSeqProcs(
    sym.getName(),
    &"$lib_{seqNameSnaked}",
    "",
    sym[1]
  )

const header = """
from ctypes import *
import os, sys

dir = os.path.dirname(sys.modules["$lib"].__file__)
if sys.platform == "win32":
  libName = "$lib.dll"
elif sys.platform == "darwin":
  libName = "lib$lib.dylib"
else:
  libName = "lib$lib.so"
dll = cdll.LoadLibrary(os.path.join(dir, libName))

class $LibError(Exception):
    pass

class SeqIterator(object):
    def __init__(self, seq):
        self.idx = 0
        self.seq = seq
    def __iter__(self):
        return self
    def __next__(self):
        if self.idx < len(self.seq):
            self.idx += 1
            return self.seq[self.idx - 1]
        else:
            self.idx = 0
            raise StopIteration

"""

proc writePy*(dir, lib: string) =
  writeFile(&"{dir}/{toSnakeCase(lib)}.py", (header & types & procs)
    .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
