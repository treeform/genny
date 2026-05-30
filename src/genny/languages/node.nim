import
  std/[os, strformat, strutils, macros, sets],
  ../common

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  exports {.compiletime.}: string
  objects {.compiletime.}: HashSet[string]
  refObjects {.compiletime.}: HashSet[string]

proc stripSink(sym: NimNode): NimNode =
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc isSeqLike(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr in ["seq", "openArray"]

proc isStringType(sym: NimNode): bool =
  sym.stripSink.repr == "string"

proc typeBody(sym: NimNode): NimNode =
  let typ = sym.stripSink
  if typ.kind == nnkSym:
    let impl = typ.getImpl()
    if impl.kind == nnkTypeDef:
      return impl[2]
  typ

proc isObjectLike(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.repr in objects or typ.typeBody.kind == nnkObjectTy

proc isRefObjectLike(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.repr in refObjects or typ.typeBody.kind == nnkRefTy

proc isEnumLike(sym: NimNode): bool =
  sym.typeBody.kind == nnkEnumTy

proc exportTypeNode(sym: NimNode): string =
  let typ = sym.stripSink
  let valueName = typ.exportedValueTypeName()
  if valueName.len > 0:
    return valueName
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = $typ.arrayCount()
        entryType = exportTypeNode(typ[2])
      result = &"koffi.array({entryType}, {entryCount})"
    elif typ.isSeqLike:
      result = "'uint64'"  # Opaque pointer
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result =
      case typ.repr:
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
      of "": "'void'"
      else:
        if typ.isEnumLike:
          "'int8'"
        elif typ.isObjectLike:
          typ.repr
        else:
          "'uint64'"  # Treat ref objects as opaque pointers

proc exportReturnTypeNode(sym: NimNode): string =
  if sym.isStringType:
    "'uint64'"
  else:
    exportTypeNode(sym)

proc jsArgValue(argType: NimNode, argName: string): string =
  let typ = argType.stripSink
  if typ.repr == "Rune":
    &"runeToInt({argName})"
  elif typ.isSeqLike or typ.isRefObjectLike:
    &"{argName}.ref"
  else:
    argName

proc jsReturnValue(returnType: NimNode, call: string): string =
  let typ = returnType.stripSink
  if typ.kind == nnkEmpty:
    call
  elif typ.repr == "string":
    &"gennyBufferToString({call})"
  elif typ.repr == "Rune":
    &"intToRune({call})"
  elif typ.isSeqLike:
    &"new {typ.getName()}({call})"
  elif typ.isRefObjectLike:
    &"new {typ.getName()}({call})"
  else:
    call

proc addNodeCall(
  returnType: NimNode,
  call: string,
  raises: bool
) =
  if not raises:
    types.add "  "
    if returnType.kind != nnkEmpty:
      types.add "return "
    types.add jsReturnValue(returnType, call)
    types.add ";\n"
    return

  if returnType.kind == nnkEmpty:
    types.add &"  {call};\n"
    types.add "  throwIfError();\n"
  else:
    types.add &"  const result = {call};\n"
    if returnType.isStringType:
      types.add "  throwIfError(result);\n"
    else:
      types.add "  throwIfError();\n"
    types.add &"  return {jsReturnValue(returnType, \"result\")};\n"

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
    procNameSnaked = toSnakeCase(procName.operatorProcName())
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
  declareFunc(apiProcName, procParams, exportReturnTypeNode(procReturn))

  # Create wrapper function
  # Only generate prototype methods for ref objects, not value objects
  let isRefObject = onClass and owner.getName() in refObjects
  if isRefObject:
    types.add &"{owner.getName()}.prototype."
    var name = ""
    if prefixes.len > 0:
      if prefixes[0].usePrefixName():
        name.add &"{prefixes[0].getName()}_"
    name.add sym.repr.operatorProcName()
    types.add &"{toVarCase(toCamelCase(name))} = function("
  elif onClass:
    # Value object with method - generate as standalone function
    var name = owner.getName() & "_"
    if prefixes.len > 0:
      name.add &"{prefixes[0].getName()}_"
    name.add sym.repr.operatorProcName()
    types.add &"function {toVarCase(toCamelCase(name))}("
    exports.add &"exports.{toVarCase(toCamelCase(name))} = {toVarCase(toCamelCase(name))};\n"
  else:
    types.add &"function {sym.repr.operatorProcName()}("
    exports.add &"exports.{sym.repr.operatorProcName()} = {sym.repr.operatorProcName()};\n"

  for i, param in procParams[0 .. ^1]:
    if isRefObject and i == 0:
      discard
    else:
      types.add toSnakeCase(param[0].getParamName())
      types.add &", "
  types.removeSuffix ", "
  types.add ") {\n"
  var call = &"{apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if isRefObject and i == 0:
      call.add "this.ref"
    else:
      let argName = toSnakeCase(param[0].getParamName())
      call.add jsArgValue(param[^2], argName)
    call.add &", "
  call.removeSuffix ", "
  call.add ")"
  addNodeCall(procReturn, call, procRaises)
  types.add "}\n\n"

proc exportObjectNode*(
  sym: NimNode,
  fields: seq[ObjectField],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objFields = sym.objectFields(fields)
  objects.incl(objName)

  # Define struct type with koffi
  types.add &"const {objName} = koffi.struct('{objName}', {{\n"
  for field in objFields:
    types.add &"  {field.name}: {exportTypeNode(field.typ)},\n"
  types.removeSuffix ",\n"
  types.add "\n});\n\n"
  exports.add &"exports.{objName} = {objName};\n"

  # Constructor function
  exports.add &"exports.{toVarCase(objName)} = {toVarCase(objName)};\n"
  types.add &"function {toVarCase(objName)}("
  for field in objFields:
    types.add &"{toSnakeCase(field.name)}, "
  types.removeSuffix ", "
  types.add ") {\n"
  types.add "  return {\n"
  for field in objFields:
    types.add &"    {field.name}: {toSnakeCase(field.name)},\n"
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
  procs.add &"const {procPrefix}_get = lib.func('{procPrefix}_get', {exportReturnTypeNode(entryType)}, ['uint64', 'int64']);\n"
  let getCall = &"{procPrefix}_get({selfAccessor}, index)"
  types.add &"{className}.prototype.get = function(index) {{\n"
  types.add &"  return {jsReturnValue(entryType, getCall)};\n"
  types.add "};\n"

  # set
  procs.add &"const {procPrefix}_set = lib.func('{procPrefix}_set', 'void', ['uint64', 'int64', {exportTypeNode(entryType)}]);\n"
  let setValue = jsArgValue(entryType, "value")
  types.add &"{className}.prototype.set = function(index, value) {{\n"
  types.add &"  {procPrefix}_set({selfAccessor}, index, {setValue});\n"
  types.add "};\n"

  # delete
  procs.add &"const {procPrefix}_delete = lib.func('{procPrefix}_delete', 'void', ['uint64', 'int64']);\n"
  types.add &"{className}.prototype.delete = function(index) {{\n"
  types.add &"  {procPrefix}_delete({selfAccessor}, index);\n"
  types.add "};\n"

  # add
  procs.add &"const {procPrefix}_add = lib.func('{procPrefix}_add', 'void', ['uint64', {exportTypeNode(entryType)}]);\n"
  types.add &"{className}.prototype.add = function(value) {{\n"
  types.add &"  {procPrefix}_add({selfAccessor}, {setValue});\n"
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
      constructorRaises = constructor.raises()

    # Declare constructor C function
    declareFunc(constructorLibProc, constructorParams, "'uint64'")

    exports.add &"exports.new{objName} = new{objName};\n"
    types.add &"function new{objName}("
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].getParamName())}"
      types.add ", "
    types.removeSuffix ", "
    types.add ") {\n"
    types.add &"  const ref = {constructorLibProc}("
    for i, param in constructorParams[0 .. ^1]:
      let argName = toSnakeCase(param[0].getParamName())
      types.add jsArgValue(param[^2], argName)
      types.add ", "
    types.removeSuffix ", "
    types.add ");\n"
    if constructorRaises:
      types.add "  throwIfError();\n"
    types.add &"  return new {objName}(ref);\n"
    types.add "}\n\n"

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"
      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      # Declare getter/setter C functions
      procs.add &"const {getProcName} = lib.func('{getProcName}', {exportReturnTypeNode(fieldType)}, ['uint64']);\n"
      procs.add &"const {setProcName} = lib.func('{setProcName}', 'void', ['uint64', {exportTypeNode(fieldType)}]);\n"

      types.add &"Object.defineProperty({objName}.prototype, '{fieldName}', {{\n"
      let getCall = &"{getProcName}(this.ref)"
      let setValue = jsArgValue(fieldType, "v")
      types.add &"  get: function() {{ return {jsReturnValue(fieldType, getCall)}; }},\n"
      types.add &"  set: function(v) {{ {setProcName}(this.ref, {setValue}); }}\n"
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
const assert = require('assert');

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

const $lib_genny_buffer_data = lib.func('$lib_genny_buffer_data', 'void *', ['uint64']);
const $lib_genny_buffer_len = lib.func('$lib_genny_buffer_len', 'int64', ['uint64']);
const $lib_genny_buffer_unref = lib.func('$lib_genny_buffer_unref', 'void', ['uint64']);

function gennyBufferToString(buffer) {
  if (buffer === null || buffer === 0 || buffer === 0n) {
    return '';
  }
  try {
    const length = Number($lib_genny_buffer_len(buffer));
    const data = $lib_genny_buffer_data(buffer);
    if (data === null || data === 0 || data === 0n || length <= 0) {
      return '';
    }
    const bytes = koffi.decode(data, 'uint8_t', length);
    return Buffer.from(bytes).toString('utf8');
  } finally {
    $lib_genny_buffer_unref(buffer);
  }
}

class $LibException extends Error {
  constructor(message) {
    super(message);
    this.name = '$LibException';
  }
}

exports.$LibException = $LibException;

function throwIfError(buffer = null) {
  if (checkError()) {
    if (buffer !== null && buffer !== 0 && buffer !== 0n) {
      $lib_genny_buffer_unref(buffer);
    }
    throw new $LibException(takeError());
  }
}

function runeToInt(value) {
  assert.strictEqual(typeof value, 'string', 'expected rune string');
  const chars = Array.from(value);
  assert.strictEqual(chars.length, 1, 'expected exactly one Unicode scalar value');
  const code = chars[0].codePointAt(0);
  assert(!(code >= 0xd800 && code <= 0xdfff), 'expected Unicode scalar value');
  return code;
}

function intToRune(value) {
  return String.fromCodePoint(value);
}

"""

proc writeNode*(dir, lib: string) =
  createDir(dir)
  writeFile(
    &"{dir}/{toSnakeCase(lib)}.js",
    (header & types & "\n" & procs & "\n" & exports)
      .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
