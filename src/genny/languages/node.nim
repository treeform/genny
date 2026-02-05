import
  std/[os, strformat, strutils, macros, sets],
  ../common

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  exports {.compiletime.}: string
  refObjects {.compiletime.}: HashSet[string]

proc exportTypeNode(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeNode(sym[2])
      result = &"koffi.array({entryType}, {entryCount})"
    elif sym[0].repr == "seq":
      result = "'uint64'"  # Opaque pointer
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result =
      case sym.repr:
      of "string": "'str'"
      of "bool": "'bool'"
      of "byte": "'uint8'"
      of "int8": "'int8'"
      of "int16": "'int16'"
      of "int32": "'int32'"
      of "int64": "'int64'"
      of "int": "'int64'"
      of "uint8": "'uint8'"
      of "uint16": "'uint16'"
      of "uint32": "'uint32'"
      of "uint64": "'uint64'"
      of "uint": "'uint64'"
      of "float32": "'float'"
      of "float64": "'double'"
      of "float": "'double'"
      of "proc () {.cdecl.}": "'pointer'"
      of "Rune": "'int32'"
      of "Vec2": "Vector2"
      of "Mat3": "Matrix3"
      of "": "'void'"
      else:
        "'uint64'"  # Treat ref objects as opaque pointers

proc convertExportFromNode*(sym: NimNode): string =
  discard

proc convertImportToNode*(sym: NimNode): string =
  discard

proc exportConstNode*(sym: NimNode) =
  let impl = sym.getImpl()
  exports.add &"exports.{toCapSnakeCase(sym.repr)} = {impl[2].repr};\n"

proc exportEnumNode*(sym: NimNode) =
  let symImpl = sym.getImpl()[2]
  exports.add &"exports.{sym.repr} = 'int8';\n"
  for i, entry in symImpl[1 .. ^1]:
    exports.add &"exports.{toCapSnakeCase(entry.repr)} = {i};\n"

proc declareFunc(funcName: string, procParams: seq[NimNode], returnType: string) =
  procs.add &"const {funcName} = lib.func('{funcName}', {returnType}, ["
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      procs.add &"{exportTypeNode(paramType)}, "
  procs.removeSuffix ", "
  procs.add "]);\n"

proc exportProcNode*(
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
    types.add "/**\n"
    for i, line in lines:
       types.add &" * {line}\n"
    types.add " */\n"

  var apiProcName = ""
  apiProcName.add "$lib_"
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

  # Declare the C function
  declareFunc(apiProcName, procParams, exportTypeNode(procReturn))

  # Create wrapper function
  # Only generate prototype methods for ref objects, not value objects
  let isRefObject = onClass and owner.getName() in refObjects
  if isRefObject:
    types.add &"{owner.getName()}.prototype."
    var name = ""
    if prefixes.len > 0:
      if prefixes[0].getImpl().kind != nnkNilLIt:
        if prefixes[0].getImpl()[2].kind != nnkEnumTy:
          name.add &"{prefixes[0].repr}_"
    name.add sym.repr
    types.add &"{toVarCase(toCamelCase(name))} = function("
  elif onClass:
    # Value object with method - generate as standalone function
    var name = owner.getName() & "_"
    if prefixes.len > 0:
      if prefixes[0].getImpl().kind != nnkNilLIt:
        if prefixes[0].getImpl()[2].kind != nnkEnumTy:
          name.add &"{prefixes[0].repr}_"
    name.add sym.repr
    types.add &"function {toVarCase(toCamelCase(name))}("
    exports.add &"exports.{toVarCase(toCamelCase(name))} = {toVarCase(toCamelCase(name))};\n"
  else:
    types.add &"function {sym.repr}("
    exports.add &"exports.{sym.repr} = {sym.repr};\n"

  for i, param in procParams[0 .. ^1]:
    if isRefObject and i == 0:
      discard
    else:
      types.add toSnakeCase(param[0].repr)
      types.add &", "
  types.removeSuffix ", "
  types.add ") {\n"
  types.add "  "
  if procReturn.kind != nnkEmpty:
    types.add "return "
  types.add &"{apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if isRefObject and i == 0:
      types.add "this.ref"
    else:
      types.add &"{toSnakeCase(param[0].repr)}"
    types.add &", "
  types.removeSuffix ", "
  types.add ");\n"
  types.add "}\n\n"

proc exportObjectNode*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  # Define struct type with koffi
  types.add &"const {objName} = koffi.struct('{objName}', {{\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"  {property[1].repr}: {exportTypeNode(identDefs[^2])},\n"
  types.removeSuffix ",\n"
  types.add "\n});\n\n"
  exports.add &"exports.{objName} = {objName};\n"

  # Constructor function
  exports.add &"exports.{toVarCase(objName)} = {toVarCase(objName)};\n"
  types.add &"function {toVarCase(objName)}("
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"{toSnakeCase(property[1].repr)}, "
  types.removeSuffix ", "
  types.add ") {\n"
  types.add "  return {\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"    {property[1].repr}: {toSnakeCase(property[1].repr)},\n"
  types.removeSuffix ",\n"
  types.add "\n  };\n"
  types.add "}\n\n"

proc genRefObject(objName: string) =
  # Track this as a ref object
  refObjects.incl(objName)
  # Ref objects are opaque pointers
  types.add &"class {objName} {{\n"
  types.add "  constructor(ref) {\n"
  types.add "    this.ref = ref;\n"
  types.add "  }\n"
  types.add "  isNull() {\n"
  types.add "    return this.ref === 0n || this.ref === 0;\n"
  types.add "  }\n"
  types.add "  isEqual(other) {\n"
  types.add "    return this.ref === other.ref;\n"
  types.add "  }\n"
  types.add "}\n"
  exports.add &"exports.{objName} = {objName};\n"

  # Declare unref function
  procs.add &"const $lib_{toSnakeCase(objName)}_unref = lib.func('$lib_{toSnakeCase(objName)}_unref', 'void', ['uint64']);\n"

proc genSeqProcs(objName, className, procPrefix, selfAccessor: string, entryType: NimNode) =
  # len
  procs.add &"const {procPrefix}_len = lib.func('{procPrefix}_len', 'int64', ['uint64']);\n"
  types.add &"{className}.prototype.length = function() {{\n"
  types.add &"  return {procPrefix}_len({selfAccessor});\n"
  types.add "};\n"

  # get
  procs.add &"const {procPrefix}_get = lib.func('{procPrefix}_get', {exportTypeNode(entryType)}, ['uint64', 'int64']);\n"
  types.add &"{className}.prototype.get = function(index) {{\n"
  types.add &"  return {procPrefix}_get({selfAccessor}, index);\n"
  types.add "};\n"

  # set
  procs.add &"const {procPrefix}_set = lib.func('{procPrefix}_set', 'void', ['uint64', 'int64', {exportTypeNode(entryType)}]);\n"
  types.add &"{className}.prototype.set = function(index, value) {{\n"
  types.add &"  {procPrefix}_set({selfAccessor}, index, value);\n"
  types.add "};\n"

  # delete
  procs.add &"const {procPrefix}_delete = lib.func('{procPrefix}_delete', 'void', ['uint64', 'int64']);\n"
  types.add &"{className}.prototype.delete = function(index) {{\n"
  types.add &"  {procPrefix}_delete({selfAccessor}, index);\n"
  types.add "};\n"

  # add
  procs.add &"const {procPrefix}_add = lib.func('{procPrefix}_add', 'void', ['uint64', {exportTypeNode(entryType)}]);\n"
  types.add &"{className}.prototype.add = function(value) {{\n"
  types.add &"  {procPrefix}_add({selfAccessor}, value);\n"
  types.add "};\n"

  # clear
  procs.add &"const {procPrefix}_clear = lib.func('{procPrefix}_clear', 'void', ['uint64']);\n"
  types.add &"{className}.prototype.clear = function() {{\n"
  types.add &"  {procPrefix}_clear({selfAccessor});\n"
  types.add "};\n"

proc exportRefObjectNode*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objNameSnaked = toSnakeCase(objName)

  genRefObject(objName)

  if constructor != nil:
    let
      constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
      constructorType = constructor.getTypeInst()
      constructorParams = constructorType[0][1 .. ^1]

    # Declare constructor C function
    declareFunc(constructorLibProc, constructorParams, "'uint64'")

    exports.add &"exports.new{objName} = new{objName};\n"
    types.add &"function new{objName}("
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add ") {\n"
    types.add &"  const ref = {constructorLibProc}("
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add ");\n"
    types.add &"  return new {objName}(ref);\n"
    types.add "}\n\n"

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"
      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      # Declare getter/setter C functions
      procs.add &"const {getProcName} = lib.func('{getProcName}', {exportTypeNode(fieldType)}, ['uint64']);\n"
      procs.add &"const {setProcName} = lib.func('{setProcName}', 'void', ['uint64', {exportTypeNode(fieldType)}]);\n"

      types.add &"Object.defineProperty({objName}.prototype, '{fieldName}', {{\n"
      types.add &"  get: function() {{ return {getProcName}(this.ref); }},\n"
      types.add &"  set: function(v) {{ {setProcName}(this.ref, v); }}\n"
      types.add "});\n"

    else:
      var helperName = fieldName
      helperName[0] = toUpperAscii(helperName[0])
      let helperClassName = objName & helperName

      types.add &"class {helperClassName} {{\n"
      types.add &"  constructor({toVarCase(objName)}) {{\n"
      types.add &"    this.{toVarCase(objName)} = {toVarCase(objName)};\n"
      types.add "  }\n"
      types.add "}\n"

      genSeqProcs(
        objName,
        helperClassName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        &"this.{toVarCase(objName)}.ref",
        fieldType[1]
      )

      types.add &"Object.defineProperty({objName}.prototype, '{fieldName}', {{\n"
      types.add &"  get: function() {{ return new {helperClassName}(this); }}\n"
      types.add "});\n"

  types.add "\n"

proc exportSeqNode*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  let newSeqProc = &"$lib_new_{toSnakeCase(seqName)}"

  # Declare constructor C function
  procs.add &"const {newSeqProc} = lib.func('{newSeqProc}', 'uint64', []);\n"

  exports.add &"exports.new{seqName} = new{seqName};\n"
  types.add &"function new{seqName}() {{\n"
  types.add &"  return new {seqName}({newSeqProc}());\n"
  types.add "}\n\n"

  genSeqProcs(
    seqName,
    seqName,
    &"$lib_{seqNameSnaked}",
    "this.ref",
    sym[1]
  )

const header = """
const koffi = require('koffi');
const path = require('path');

// Determine library path based on platform.
let libName;
if (process.platform === 'win32') {
  libName = '$lib.dll';
} else if (process.platform === 'darwin') {
  libName = 'lib$lib.dylib';
} else {
  libName = 'lib$lib.so';
}

const lib = koffi.load(path.join(__dirname, libName));

class $LibException extends Error {
  constructor(message) {
    super(message);
    this.name = '$LibException';
  }
}

"""

proc writeNode*(dir, lib: string) =
  createDir(dir)
  writeFile(
    &"{dir}/{toSnakeCase(lib)}.js",
    (header & procs & "\n" & types & "\n" & exports)
      .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
