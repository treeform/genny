import
  std/[algorithm, os, strformat, strutils, macros, tables],
  ../common

type OperatorCase = tuple[
  rhsType: NimNode,
  returnType: NimNode,
  apiProcName: string,
  procRaises: bool
]

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  operatorMethods {.compiletime.}: Table[string, Table[string, seq[OperatorCase]]]

proc stripSink(sym: NimNode): NimNode =
  ## Removes Nim's `sink[T]` ownership wrapper before mapping a type to ctypes.
  ## Python callers pass the payload value; the generated Nim side handles the
  ## ownership semantics at the ABI boundary.
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc isSeqLike(sym: NimNode): bool =
  ## Returns true for sequence-shaped types that should reuse Genny's generated
  ## seq wrapper classes. `openArray[T]` is treated like `seq[T]` for Python
  ## bindings because the internal ABI receives a generated sequence handle.
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr in ["seq", "openArray"]

proc isStringType(sym: NimNode): bool =
  sym.stripSink.repr == "string"

proc exportTypePy(sym: NimNode): string =
  let typ = sym.stripSink
  let valueName = typ.exportedValueTypeName()
  if valueName.len > 0:
    return valueName
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = $typ.arrayCount()
        entryType = exportTypePy(typ[2])
      result = &"{entryType} * {entryCount}"
    elif typ.isSeqLike:
      result = typ.getSeqName()
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result =
      case typ.repr:
      of "string": "c_char_p"
      of "cstring": "c_char_p"
      of "pointer": "c_void_p"
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
      of "", "nil": "None"
      else:
        typ.repr

proc exportReturnTypePy(sym: NimNode): string =
  if sym.isStringType:
    "_GennyBuffer"
  else:
    exportTypePy(sym)

proc convertExportFromPy*(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.repr == "string":
    result = ".encode(\"utf8\")"

proc convertImportToPy*(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.repr == "string":
    result = ".decode(\"utf8\")"

proc exportExprPy(expr: string, sym: NimNode): string =
  let typ = sym.stripSink
  case typ.repr
  of "string":
    expr & ".encode(\"utf8\")"
  of "Rune":
    &"_rune_to_int({expr})"
  else:
    expr

proc importExprPy(expr: string, sym: NimNode): string =
  let typ = sym.stripSink
  case typ.repr
  of "string":
    &"_genny_buffer_to_string({expr})"
  of "Rune":
    &"_int_to_rune({expr})"
  else:
    expr

proc pyTypeCheck(expr: string, sym: NimNode): string =
  let typ = sym.stripSink
  case typ.repr:
  of "bool":
    &"isinstance({expr}, bool)"
  of "int8", "byte", "int16", "int32", "int64", "int", "uint8", "uint16", "uint32", "uint64", "uint":
    &"isinstance({expr}, int)"
  of "float32", "float64", "float":
    &"isinstance({expr}, (int, float))"
  of "string", "cstring", "Rune":
    &"isinstance({expr}, str)"
  else:
    &"isinstance({expr}, {exportTypePy(typ)})"

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
    procNameSnaked = toSnakeCase(procName.operatorProcName())
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

  if onClass and procName.isOperatorName and procReturn.kind != nnkEmpty:
    if procParams.len < 2:
      error("Python operator overloads need a right-hand operand", sym)

    let methodName = procName.pythonOperatorName()
    var ownerOps = operatorMethods.getOrDefault(owner.getName())
    var cases = ownerOps.getOrDefault(methodName)
    cases.add((
      rhsType: procParams[1][^2],
      returnType: procReturn,
      apiProcName: &"dll.$lib_{apiProcName}",
      procRaises: procRaises
    ))
    ownerOps[methodName] = cases
    operatorMethods[owner.getName()] = ownerOps

    var dllParams: seq[NimNode]
    for param in procParams:
      dllParams.add(param[1])
    dllProc(&"dll.$lib_{apiProcName}", toArgTypes(dllParams), exportReturnTypePy(procReturn))
    return

  if onClass:
    types.add "    def "
    if prefixes.len > 0:
      if prefixes[0].usePrefixName():
        types.add &"{toSnakeCase(prefixes[0].getName())}_"
    types.add &"{toSnakeCase(sym.repr.operatorProcName())}("
  else:
    types.add &"def {apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      types.add "self"
    else:
      types.add toSnakeCase(param[0].getParamName())
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
      types.add &"    if {toSnakeCase(param[0].getParamName())} is None:\n"
      if onClass:
          types.add "    "
      types.add &"        {toSnakeCase(param[0].getParamName())} = "
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
  var call = &"dll.$lib_{apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      call.add "self"
    else:
      call.add exportExprPy(toSnakeCase(param[0].getParamName()), param[1])
    call.add &", "
  call.removeSuffix ", "
  call.add ")"
  types.add importExprPy(call, procReturn)
  types.add "\n"
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
  dllProc(&"dll.$lib_{apiProcName}", toArgTypes(dllParams), exportReturnTypePy(procReturn))

proc exportObjectPy*(
  sym: NimNode,
  fields: seq[ObjectField],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objFields = sym.objectFields(fields)

  types.add &"class {objName}(Structure):\n"
  types.add "    _fields_ = [\n"
  for field in objFields:
    types.add &"        (\"{toSnakeCase(field.name)}\""
    types.add ", "
    types.add &"{exportTypePy(field.typ)}),\n"
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
      types.add &"{toSnakeCase(param[0].getParamName())}"
      types.add ", "
    types.removeSuffix ", "
    types.add "):\n"
    types.add &"        tmp = dll.$lib_{toSnakeCase(objName)}("
    for param in constructorParams:
      types.add exportExprPy(toSnakeCase(param[0].getParamName()), param[1])
      types.add ", "
    types.removeSuffix ", "
    types.add ")\n"
    for field in objFields:
      types.add &"        self.{toSnakeCase(field.name)} = "
      types.add &"tmp.{toSnakeCase(field.name)}\n"
    types.add "\n"
    var dllParams: seq[NimNode]
    for param in constructorParams:
      dllParams.add(param[1])
    dllProc(&"dll.$lib_{toSnakeCase(objName)}", toArgTypes(dllParams), objName)
  else:
    types.add "    def __init__(self, "
    for field in objFields:
      types.add &"{toSnakeCase(field.name)}, "
    types.removeSuffix ", "
    types.add "):\n"
    for field in objFields:
      types.add "        "
      types.add &"self.{toSnakeCase(field.name)} = "
      types.add &"{toSnakeCase(field.name)}\n"
    types.add "\n"

  types.add "    def __eq__(self, obj):\n"
  types.add "        return "
  for field in objFields:
    if field.typ.len > 0 and field.typ[0].repr == "array":
      for i in 0 ..< field.typ.arrayCount():
        types.add &"self.{toSnakeCase(field.name)}[{i}] == obj.{toSnakeCase(field.name)}[{i}] and "
    else:
      types.add &"self.{toSnakeCase(field.name)} == obj.{toSnakeCase(field.name)} and "
  types.removeSuffix " and "
  types.add "\n"
  types.add "\n"

proc exportCloseObjectPy*(sym: NimNode) =
  let objName = sym.getName()
  if objName notin operatorMethods:
    return

  var methodNames: seq[string]
  for methodName in operatorMethods[objName].keys:
    methodNames.add(methodName)
  methodNames.sort()

  for methodName in methodNames:
    let cases = operatorMethods[objName][methodName]
    types.add &"    def {methodName}(self, other):\n"
    for opCase in cases:
      types.add &"        if {pyTypeCheck(\"other\", opCase.rhsType)}:\n"
      types.add &"            result = {opCase.apiProcName}(self, {exportExprPy(\"other\", opCase.rhsType)})\n"
      if opCase.procRaises:
        types.add &"            if check_error():\n"
        types.add "                raise $LibError(take_error())\n"
      types.add &"            return {importExprPy(\"result\", opCase.returnType)}\n"
    types.add "        return NotImplemented\n"
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
  let getCall = &"dll.{procPrefix}_get(self{selfSuffix}, index)"
  types.add &"{baseIndent}    return {importExprPy(getCall, entryType)}\n"
  types.add "\n"

  types.add &"{baseIndent}def __setitem__(self, index, value):\n"
  let setValue = exportExprPy("value", entryType)
  types.add &"{baseIndent}    dll.{procPrefix}_set(self{selfSuffix}, index, {setValue})\n"
  types.add "\n"

  types.add &"{baseIndent}def __delitem__(self, index):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_delete(self{selfSuffix}, index)\n"
  types.add "\n"

  types.add &"{baseIndent}def append(self, value):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_add(self{selfSuffix}, {setValue})\n"
  types.add "\n"

  types.add &"{baseIndent}def clear(self):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_clear(self{selfSuffix})\n"
  types.add "\n"

  types.add &"{baseIndent}def __iter__(self):\n"
  types.add &"{baseIndent}    return SeqIterator(self)\n"
  types.add "\n"

  dllProc(&"dll.{procPrefix}_len", [objName], "c_longlong")
  dllProc(&"dll.{procPrefix}_get", [objName, "c_longlong"], exportReturnTypePy(entryType))
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
      types.add &"{toSnakeCase(param[0].getParamName())}"
      types.add ", "
    types.removeSuffix ", "
    types.add "):\n"
    types.add &"        result = "
    types.add &"{constructorLibProc}("
    for param in constructorParams:
      types.add exportExprPy(toSnakeCase(param[0].getParamName()), param[1])
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
      let getCall = &"{getProcName}(self)"
      types.add &"return {importExprPy(getCall, fieldType)}\n"

      let setProcName = &"dll.$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      types.add "\n"
      types.add &"    @{fieldNameSnaked}.setter\n"
      types.add &"    def {fieldNameSnaked}(self, {fieldNameSnaked}):\n"
      types.add "        "
      types.add &"{setProcName}(self, "
      types.add exportExprPy(fieldNameSnaked, fieldType)
      types.add ")\n"
      types.add "\n"

      dllProc(getProcName, toArgTypes([sym]), exportReturnTypePy(fieldType))
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

_GennyBuffer = c_void_p

dll.$lib_genny_buffer_data.argtypes = [_GennyBuffer]
dll.$lib_genny_buffer_data.restype = c_void_p
dll.$lib_genny_buffer_len.argtypes = [_GennyBuffer]
dll.$lib_genny_buffer_len.restype = c_longlong
dll.$lib_genny_buffer_unref.argtypes = [_GennyBuffer]
dll.$lib_genny_buffer_unref.restype = None

def _genny_buffer_to_string(buffer):
    if not buffer:
        return ""
    try:
        length = dll.$lib_genny_buffer_len(buffer)
        data = dll.$lib_genny_buffer_data(buffer)
        if not data or length <= 0:
            return ""
        return string_at(data, length).decode("utf8")
    finally:
        dll.$lib_genny_buffer_unref(buffer)

class $LibError(Exception):
    pass

def _rune_to_int(value):
    assert isinstance(value, str), "expected rune string"
    assert len(value) == 1, "expected exactly one Unicode scalar value"
    code = ord(value)
    assert code < 0xD800 or code > 0xDFFF, "expected Unicode scalar value"
    return code

def _int_to_rune(value):
    return chr(value)

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
  createDir(dir)
  writeFile(&"{dir}/{toSnakeCase(lib)}.py", (header & types & procs)
    .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
