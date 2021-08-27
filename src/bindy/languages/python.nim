import ../common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string

proc exportTypePy(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr != "seq":
      quit(&"Unexpected bracket expression {sym[0].repr}[")
    result = sym.getSeqName()
  else:
    result =
      case sym.repr:
      of "string": "c_char_p"
      of "bool": "c_bool"
      of "int8": "c_byte"
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
      of "": "None"
      else:
        if sym.repr.startsWith("Some"):
          sym.repr.replace("Some", "")
        else:
          sym.repr

proc convertExportFromPy*(sym: NimNode): string =
  if sym.repr == "string":
    result = ".encode(\"utf8\")"

proc convertImportToPy*(sym: NimNode): string =
  if sym.repr == "string":
    result = ".decode(\"utf8\")"

proc exportConstPy*(sym: NimNode) =
  let impl = sym.getImpl()
  types.add &"{toCapSnakeCase(sym.repr)} = {impl.repr}\n"
  types.add "\n"

proc exportEnumPy*(sym: NimNode) =
  let symImpl = sym.getImpl()[2]

  types.add &"{sym.repr} = c_byte\n"
  for i, entry in symImpl[1 .. ^1]:
    types.add &"{toCapSnakeCase(entry.repr)} = {i}\n"
  types.add "\n"

proc exportProcPy*(sym: NimNode, prefixes: openarray[NimNode] = []) =
  let
    procName = sym.repr
    procNameSnaked = toSnakeCase(procName)
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1]
    procReturn = procType[0][0]
    procRaises = sym.raises()
    onClass = prefixes.len > 0

  var apiProcName = ""
  if prefixes.len > 0:
    for prefix in prefixes:
      apiProcName.add &"{toSnakeCase(prefix.getName())}_"
  apiProcName.add &"{procNameSnaked}"

  if onClass:
    types.add "    def "
    if prefixes.len > 1:
      if prefixes[1].getImpl().kind != nnkNilLIt:
        if prefixes[1].getImpl()[2].kind != nnkEnumTy:
          types.add &"{toSnakeCase(prefixes[1].repr)}_"
    types.add &"{toSnakeCase(sym.repr)}("
  else:
    types.add &"def {apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      types.add "self"
    else:
      types.add toSnakeCase(param[0].repr)
    types.add &", "
  types.removeSuffix ", "
  types.add "):\n"
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
    types.add "        raise PixieError("
    types.add "take_error()"
    types.add ")\n"
  if procReturn.kind != nnkEmpty:
    if onClass:
      types.add "    "
    types.add "    return result\n"
  types.add "\n"

  procs.add &"dll.$lib_{apiProcName}.argtypes = ["
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      if paramType.repr.endsWith(":type"):
        paramType = prefixes[0]
      procs.add &"{exportTypePy(paramType)}, "
  procs.removeSuffix ", "
  procs.add "]\n"
  procs.add &"dll.$lib_{apiProcName}.restype = {exportTypePy(procReturn)}\n"
  procs.add "\n"

proc exportObjectPy*(sym: NimNode) =
  let
    objName = sym.repr
    objType = sym.getType()

  types.add &"class {objName}(Structure):\n"
  types.add "    _fields_ = [\n"
  for property in objType[2]:
    types.add &"        (\"{toSnakeCase(property.repr)}\""
    types.add ", "
    types.add &"{exportTypePy(property.getTypeInst())}),\n"
  types.removeSuffix ",\n"
  types.add "\n"
  types.add "    ]\n"
  types.add "\n"

  types.add "    def __init__(self, "
  for property in objType[2]:
    types.add &"{toSnakeCase(property.repr)}, "
  types.removeSuffix ", "
  types.add "):\n"
  for property in objType[2]:
    types.add "        "
    types.add &"self.{toSnakeCase(property.repr)} = {toSnakeCase(property.repr)}\n"
  types.add "\n"

  types.add "    def __eq__(self, obj):\n"
  types.add "        "
  for property in objType[2]:
    types.add &"self.{toSnakeCase(property.repr)} == obj.{toSnakeCase(property.repr)} and "
  types.removeSuffix " and "
  types.add "\n"
  types.add "\n"

proc genRefObject(objName: string) =
  types.add &"class {objName}(Structure):\n"
  types.add "    _fields_ = [(\"ref\", c_ulonglong)]\n"
  types.add "\n"

  types.add "    def __bool__(self):\n"
  types.add "        self.ref != None\n"
  types.add "\n"

  types.add "    def __eq__(self, obj):\n"
  types.add "        self.ref == obj.ref\n"
  types.add "\n"

  types.add "    def __del__(self):\n"
  types.add &"        dll.$lib_{toSnakeCase(objName)}_unref(self)\n"
  types.add "\n"

  procs.add &"dll.$lib_{toSnakeCase(objName)}_unref.argtypes = [{objName}]\n"
  procs.add &"dll.$lib_{toSnakeCase(objName)}_unref.restype = None\n"
  procs.add "\n"

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  var baseIndent = "    "
  if selfSuffix != "": # This is a bound seq
    baseIndent = "        "

  types.add &"{baseIndent}def __len__(self):\n"
  types.add &"{baseIndent}    return dll.{procPrefix}_len(self{selfSuffix})\n"
  types.add "\n"

  types.add &"{baseIndent}def __getitem__(self, index):\n"
  types.add &"{baseIndent}    return dll.{procPrefix}_get(self{selfSuffix}, index)\n"
  types.add "\n"

  types.add &"{baseIndent}def __setitem__(self, index, value):\n"
  types.add &"{baseIndent}    dll.{procPrefix}_set(self{selfSuffix}, index, value)\n"
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

  procs.add &"dll.{procPrefix}_len.argtypes = [{objName}]\n"
  procs.add &"dll.{procPrefix}_len.restype = c_longlong\n"
  procs.add "\n"

  procs.add &"dll.{procPrefix}_get.argtypes = [{objName}, c_longlong]\n"
  procs.add &"dll.{procPrefix}_get.restype = {exportTypePy(entryType)}\n"
  procs.add "\n"

  procs.add &"dll.{procPrefix}_set.argtypes = [{objName}, c_longlong, {exportTypePy(entryType)}]\n"
  procs.add &"dll.{procPrefix}_set.restype = None\n"
  procs.add "\n"

  procs.add &"dll.{procPrefix}_delete.argtypes = [{objName}, c_longlong]\n"
  procs.add &"dll.{procPrefix}_delete.restype = None\n"
  procs.add "\n"

  procs.add &"dll.{procPrefix}_add.argtypes = [{objName}, {exportTypePy(entryType)}]\n"
  procs.add &"dll.{procPrefix}_add.restype = None\n"
  procs.add "\n"

  procs.add &"dll.{procPrefix}_clear.argtypes = [{objName}]\n"
  procs.add &"dll.{procPrefix}_clear.restype = None\n"
  procs.add "\n"

proc exportRefObjectPy*(
  sym: NimNode, whitelist: openarray[string], constructor: NimNode
) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)
    objType = sym.getType()[1][1].getType()

  genRefObject(objName)

  if constructor != nil:
      let
        constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
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
      types.add &"dll.{constructorLibProc}("
      for i, param in constructorParams[0 .. ^1]:
        types.add &"{toSnakeCase(param[0].repr)}{convertExportFromPy(param[1])}"
        types.add ", "
      types.removeSuffix ", "
      types.add ")\n"
      if constructorRaises:
        types.add &"        if check_error():\n"
        types.add "            raise PixieError("
        types.add "take_error()"
        types.add ")\n"
      types.add "        self.ref = result\n"
      types.add "\n"

      procs.add &"dll.{constructorLibProc}.argtypes = []\n"
      procs.add &"dll.{constructorLibProc}.restype = c_ulonglong\n"
      procs.add "\n"

  for property in objType[2]:
    if not property.isExported:
      continue
    if whitelist != ["*"] and property.repr notin whitelist:
      continue

    let
      propertyName = property.repr
      propertyNameSnaked = toSnakeCase(propertyName)
      propertyType = property.getTypeInst()

    if propertyType.kind != nnkBracketExpr:
      let getProcName = &"dll.$lib_{objNameSnaked}_get_{propertyNameSnaked}"

      types.add "    @property\n"
      types.add &"    def {propertyNameSnaked}(self):\n"
      types.add "        "
      types.add &"return {getProcName}(self){convertImportToPy(propertyType)}\n"

      let setProcName = &"dll.$lib_{objNameSnaked}_set_{propertyNameSnaked}"

      types.add "\n"
      types.add &"    @{propertyNameSnaked}.setter\n"
      types.add &"    def {propertyNameSnaked}(self, {propertyNameSnaked}):\n"
      types.add "        "
      types.add &"{setProcName}(self, "
      types.add &"{propertyNameSnaked}{convertExportFromPy(propertyType)}"
      types.add ")\n"
      types.add "\n"

      procs.add &"{getProcName}.argtypes = [{objName}]\n"
      procs.add &"{getProcName}.restype = {exportTypePy(propertyType)}\n"
      procs.add "\n"

      procs.add &"{setProcName}.argtypes = [{objName}, {exportTypePy(propertyType)}]\n"
      procs.add &"{setProcName}.restype = None\n"
      procs.add "\n"
    else:
      var helperName = property.repr
      helperName[0] = toUpperAscii(helperName[0])
      let helperClassName = objName & helperName

      types.add &"    class {helperClassName}:\n"
      types.add "\n"
      types.add &"        def __init__(self, {toSnakeCase(objName)}):\n"
      types.add &"            self.{toSnakeCase(objName)} = {toSnakeCase(objName)}\n"
      types.add "\n"

      genSeqProcs(
        objName,
        &"$lib_{objNameSnaked}_{propertyNameSnaked}",
        &".{toSnakeCase(objName)}",
        propertyType[1]
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

  let newSeqProc = &"$lib_new_{toSnakeCase(seqName)}"

  types.add "    def __init__(self):\n"
  types.add &"        self.ref = dll.{newSeqProc}()\n"
  types.add "\n"

  procs.add &"dll.{newSeqProc}.argtypes = []\n"
  procs.add &"dll.{newSeqProc}.restype = c_ulonglong\n"
  procs.add "\n"

  genSeqProcs(
    sym.getName(),
    &"$lib_{seqNameSnaked}",
    "",
    sym[1]
  )

const header = """
from ctypes import *
import os, sys
from pathlib import Path

src_path = Path(__file__).resolve()
src_dir = str(src_path.parent)

if sys.platform == "win32":
  libPath = "pixie.dll"
elif sys.platform == "darwin":
  libPath = "libpixie.dylib"
else:
  libPath = "libpixie.so"
dll = cdll.LoadLibrary(src_dir + "/" + libPath)

class PixieError(Exception):
    pass

"""

proc writePy*(dir, lib: string) =
  writeFile(&"{dir}/{lib}.py", (header & types & procs).replace("$lib", lib))
