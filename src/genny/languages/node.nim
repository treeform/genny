import ../common, macros, strformat, strutils

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  exports {.compiletime.}: string

proc exportTypeNode(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr == "array":
      let
        entryCount = sym[1].repr
        entryType = exportTypeNode(sym[2])
      result = &"ArrayType({entryType}, {entryCount})"
    elif sym[0].repr == "seq":
      result = sym.getSeqName()
    else:
      error(&"Unexpected bracket expression {sym[0].repr}[")
  else:
    result =
      case sym.repr:
      of "string": "'string'"
      of "bool": "'bool'"
      of "byte": "'int8'"
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
        sym.repr

proc convertExportFromNode*(sym: NimNode): string =
  discard

proc convertImportToNode*(sym: NimNode): string =
  discard

proc exportConstNode*(sym: NimNode) =
  let impl = sym.getImpl()
  exports.add &"exports.{toCapSnakeCase(sym.repr)} = {impl[2].repr}\n"

proc exportEnumNode*(sym: NimNode) =
  let symImpl = sym.getImpl()[2]

  types.add &"const {sym.repr} = 'int8'\n"
  exports.add &"exports.{sym.repr} = {sym.repr}\n"
  for i, entry in symImpl[1 .. ^1]:
    exports.add &"exports.{toCapSnakeCase(entry.repr)} = {i}\n"
  types.add "\n"

proc dllProc(proName: string, procParams: seq[NimNode], returnType: string) =
  procs.add &"  '{proName}': [{returnType}, ["
  for param in procParams:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      procs.add &"{exportTypeNode(paramType)}, "
  procs.removeSuffix ", "
  procs.add "]],\n"

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

  ## Nim bug, must set to "" first, otherwise crazy!
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

  if onClass:
    types.add &"{owner.getName()}.prototype."
    var name = ""
    if prefixes.len > 0:
      if prefixes[0].getImpl().kind != nnkNilLIt:
        if prefixes[0].getImpl()[2].kind != nnkEnumTy:
          name.add &"{prefixes[0].repr}_"
    name.add sym.repr
    types.add &"{toVarCase(toCamelCase(name))} = function("
  else:
    types.add &"function {sym.repr}("
    exports.add &"exports.{sym.repr} = {sym.repr}\n"

  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      discard #types.add "this?"
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
          types.add &" = "
          types.add &"{exportTypeNode(param[1])}("
          for d in defaults[i][1][1 .. ^1]:
            types.add &"{d.repr}, "
          types.removeSuffix ", "
          types.add ")"
      types.add &", "
  types.removeSuffix ", "
  types.add "){\n"
  types.add "  "
  if procReturn.kind != nnkEmpty:
    types.add "result = "
  types.add &"dll.{apiProcName}("
  for i, param in procParams[0 .. ^1]:
    if onClass and i == 0:
      types.add "this"
    else:
      types.add &"{toSnakeCase(param[0].repr)}{convertExportFromNode(param[1])}"
    types.add &", "
  types.removeSuffix ", "
  types.add &"){convertImportToNode(procReturn)}\n"
  if procRaises:
    types.add &"  if(checkError()) "
    types.add "throw new $LibException("
    types.add "takeError()"
    types.add ");\n"
  if procReturn.kind != nnkEmpty:
    types.add "  return result\n"
  types.add "}\n\n"

  dllProc(apiProcName, procParams, exportTypeNode(procReturn))

proc exportObjectNode*(sym: NimNode, constructor: NimNode) =
  let objName = sym.repr

  exports.add &"exports.{objName} = {objName};\n"
  types.add &"const {objName} = Struct(" & "{\n"
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"  '{property[1].repr}':"
      types.add &"{exportTypeNode(identDefs[^2])},\n"
  types.removeSuffix ",\n"
  types.add "\n})\n"

  if constructor != nil:
    let
      constructorType = constructor.getTypeInst()
      constructorParams = constructorType[0][1 .. ^1]
      constructorLibProc = &"$lib_{toSnakeCase(objName)}"

    exports.add &"exports.{toVarCase(objName)} = {toVarCase(objName)};\n"
    types.add &"{toVarCase(objName)} = function("
    for param in constructorParams:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add "){\n"
    types.add &"  return dll.{constructorLibProc}("
    for param in constructorParams:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add ");\n"
    types.add "}\n"
    dllProc(constructorLibProc, constructorParams, objName)

  else:
    exports.add &"exports.{toVarCase(objName)} = {toVarCase(objName)};\n"
    types.add &"{toVarCase(objName)} = function("
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add &"{toSnakeCase(property[1].repr)}, "
    types.removeSuffix ", "
    types.add "){\n"
    types.add &"  var v = new {objName}();\n"
    for identDefs in sym.getImpl()[2][2]:
      for property in identDefs[0 .. ^3]:
        types.add "  "
        types.add &"v.{toSnakeCase(property[1].repr)} = "
        types.add &"{toSnakeCase(property[1].repr)}\n"

    types.add "  return v;\n"
    types.add "}\n"

  types.add &"{objName}.prototype.isEqual = function(other){{\n"
  types.add &"  return "
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      types.add &"self.{property[1].repr} == other.{property[1].repr} && "
  types.removeSuffix " && "
  types.add ";\n"
  types.add "};\n"
  types.add "\n"

proc genRefObject(objName: string) =
  exports.add &"exports.{objName}Type = {objName}\n"
  types.add &"{objName} = " & "Struct({'nimRef': 'uint64'});\n"

  types.add &"{objName}.prototype.isNull = function(){{\n"
  types.add &"  return this.nimRef == 0;\n"
  types.add "};\n"

  types.add &"{objName}.prototype.isEqual = function(other){{\n"
  types.add &"  return this.nimRef == other.nimRef;\n"
  types.add "};\n"

  ## TODO: maybe https://nodejs.org/api/n-api.html#n_api_napi_finalize ?
  types.add &"{objName}.prototype.unref = function(){{\n"
  types.add &"  return dll.$lib_{toSnakeCase(objName)}_unref(this)\n"
  types.add "};\n"

  procs.add &"  '$lib_{toSnakeCase(objName)}_unref': ['void', [{objName}]],\n"

proc genSeqProcs(objName, ownObjName, procPrefix, selfSuffix: string, entryType: NimNode) =

  types.add &"{ownObjName}.prototype.length = function(){{\n"
  types.add &"  return dll.{procPrefix}_len(this{selfSuffix})\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_len': ['uint64', [{objName}]],\n"

  types.add &"{ownObjName}.prototype.get = function(index){{\n"
  types.add &"  return dll.{procPrefix}_get(this{selfSuffix}, index)\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_get': [{exportTypeNode(entryType)}, [{objName}, 'uint64']],\n"

  types.add &"{ownObjName}.prototype.set = function(index, value){{\n"
  types.add &"  dll.{procPrefix}_set(this{selfSuffix}, index, value)\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_set': ['void', [{objName}, 'uint64', {exportTypeNode(entryType)}]],\n"

  types.add &"{ownObjName}.prototype.delete = function(index){{\n"
  types.add &"  dll.{procPrefix}_delete(this{selfSuffix}, index)\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_delete': ['void', [{objName}, 'uint64']],\n"

  types.add &"{ownObjName}.prototype.add = function(value){{\n"
  types.add &"  dll.{procPrefix}_add(this{selfSuffix}, value)\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_add': ['void', [{objName}, {exportTypeNode(entryType)}]],\n"

  types.add &"{ownObjName}.prototype.clear = function(){{\n"
  types.add &"  dll.{procPrefix}_clear(this{selfSuffix})\n"
  types.add "};\n"
  procs.add &"  '{procPrefix}_clear': ['void', [{objName}]],\n"

proc exportRefObjectNode*(
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

    exports.add &"exports.{objName} = new{objName}\n"
    types.add &"function new{objName}("
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].repr)}"
      types.add ", "
    types.removeSuffix ", "
    types.add "){\n"
    types.add &"  var result = "
    types.add &"dll.{constructorLibProc}("
    for i, param in constructorParams[0 .. ^1]:
      types.add &"{toSnakeCase(param[0].repr)}{convertExportFromNode(param[1])}"
      types.add ", "
    types.removeSuffix ", "
    types.add ")\n"

    types.add "  const registry = new FinalizationRegistry(function(obj) {\n"
    types.add "    console.log(\"js unref\")\n"
    types.add "    obj.unref()\n"
    types.add "  });\n"
    types.add "  registry.register(result, null);\n"


    if constructorRaises:
      types.add &"  if(checkError()) "
      types.add "throw new $LibException("
      types.add "takeError()"
      types.add ");\n"
    types.add "  return result\n"
    types.add "}\n"

    dllProc(constructorLibProc, constructorParams, objName)

  for (fieldName, fieldType) in fields:
    let fieldNameSnaked = toSnakeCase(fieldName)

    if fieldType.kind != nnkBracketExpr:
      let getProcName = &"$lib_{objNameSnaked}_get_{fieldNameSnaked}"
      let setProcName = &"$lib_{objNameSnaked}_set_{fieldNameSnaked}"

      types.add &"Object.defineProperty({objName}.prototype, '{fieldName}', {{\n"
      types.add &"  get: function() {{return dll.{getProcName}(this)}},\n"
      types.add &"  set: function(v) {{dll.{setProcName}(this, v)}}\n"
      types.add "});\n"

      procs.add &"  '{getProcName}': [{exportTypeNode(fieldType)}, [{objName}]],\n"
      procs.add &"  '{setProcName}': ['void', [{objName}, {exportTypeNode(fieldType)}]],\n"

    else:
      discard
      var helperName = fieldName
      helperName[0] = toUpperAscii(helperName[0])
      let helperClassName = objName & helperName

      types.add &"function {helperClassName}({toVarCase(objName)}){{\n"
      types.add &"  this.{toVarCase(objName)} = {toVarCase(objName)};\n"
      types.add "}\n"

      genSeqProcs(
        objName,
        helperClassName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        &".{toSnakeCase(objName)}",
        fieldType[1]
      )

      types.add &"Object.defineProperty({objName}.prototype, '{fieldName}', {{\n"
      types.add &"  get: function() {{return new {helperClassName}(this)}},\n"
      types.add "});\n"

  types.add "\n"

proc exportSeqNode*(sym: NimNode) =
  let
    seqName = sym.getName()
    seqNameSnaked = toSnakeCase(seqName)

  genRefObject(seqName)

  let newSeqProc = &"$lib_new_{toSnakeCase(seqName)}"

  types.add &"function {toVarCase(seqName)}(){{\n"
  types.add &"  return dll.{newSeqProc}();\n"
  types.add "}\n"

  procs.add &"  '{newSeqProc}': [{seqName}, []],\n"

  genSeqProcs(
    sym.getName(),
    sym.getName(),
    &"$lib_{seqNameSnaked}",
    "",
    sym[1]
  )

const header = """
var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");
var ArrayType = require('ref-array-napi');

var dll = {};

function $LibException(message) {
  this.message = message;
  this.name = '$LibException';
}

"""
const loader = """

var dllPath = ""
if(process.platform == "win32") {
  dllPath = __dirname + '/$lib.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/lib$lib.dylib'
} else {
  dllPath = __dirname + '/lib$lib.so'
}

dll = ffi.Library(dllPath, {
"""
const footer = """
});

"""

proc writeNode*(dir, lib: string) =
  writeFile(
    &"{dir}/{toSnakeCase(lib)}.js",
    (header & types & loader & procs & footer & exports)
      .replace("$Lib", lib).replace("$lib", toSnakeCase(lib))
  )
