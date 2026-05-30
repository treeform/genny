import
  std/[os, strformat, strutils, macros],
  ../common

var
  types {.compiletime.}: string
  procs {.compiletime.}: string
  classes {.compiletime.}: string
  members {.compiletime.}: string
  hasRaisingProcs {.compiletime.}: bool

proc unCapitalize(s: string): string =
  s[0].toLowerAscii() & s[1 .. ^1]

proc stripSink(sym: NimNode): NimNode =
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc isSeqLike(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr in ["seq", "openArray"]

proc isRuneType(sym: NimNode): bool =
  sym.stripSink.repr == "Rune"

proc isStringType(sym: NimNode): bool =
  sym.stripSink.repr == "string"

proc exportTypeCpp(sym: NimNode, abi = false): string =
  let typ = sym.stripSink
  let valueName = typ.exportedValueTypeName()
  if valueName.len > 0:
    return valueName
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = $typ.arrayCount()
        entryType = exportTypeCpp(typ[2], abi)
      result = &"{entryType}[{entryCount}]"
    elif typ.isSeqLike:
      result = typ.getSeqName()
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result =
      case typ.repr:
      of "string", "cstring": "const char*"
      of "bool": "bool"
      of "byte": "std::uint8_t"
      of "int8": "std::int8_t"
      of "int16": "std::int16_t"
      of "int32": "std::int32_t"
      of "int64": "std::int64_t"
      of "int": "std::intptr_t"
      of "uint8": "std::uint8_t"
      of "uint16": "std::uint16_t"
      of "uint32": "std::uint32_t"
      of "uint64": "std::uint64_t"
      of "uint": "std::uintptr_t"
      of "float32": "float"
      of "float64": "double"
      of "float": "double"
      of "Rune":
        if abi: "std::int32_t" else: "char32_t"
      of "", "nil": "void"
      of "None": "void"
      else:
        if typ.getType().kind == nnkBracketExpr:
          typ.repr
        else:
          typ.repr

proc exportTypeCppAbi(sym: NimNode): string =
  exportTypeCpp(sym, abi = true)

proc exportReturnTypeCpp(sym: NimNode): string =
  if sym.isStringType:
    "std::string"
  else:
    exportTypeCpp(sym)

proc exportReturnTypeCppAbi(sym: NimNode): string =
  if sym.isStringType:
    "GennyBuffer"
  else:
    exportTypeCppAbi(sym)

proc exportTypeCpp(sym: NimNode, name: string, abi = false): string =
  let typ = sym.stripSink
  let valueName = typ.exportedValueTypeName()
  if valueName.len > 0:
    return valueName & " " & name
  if typ.kind == nnkBracketExpr:
    if typ[0].repr == "array":
      let
        entryCount = $typ.arrayCount()
        entryType = exportTypeCpp(typ[2], &"{name}[{entryCount}]", abi)
      result = &"{entryType}"
    elif typ.isSeqLike:
      result = typ.getSeqName() & " " & name
    else:
      error(&"Unexpected bracket expression {typ[0].repr}[")
  else:
    result = exportTypeCpp(typ, abi) & " " & name

proc exportTypeCppAbi(sym: NimNode, name: string): string =
  exportTypeCpp(sym, name, abi = true)

proc cppArgValue(argType: NimNode, argName: string): string =
  if argType.isRuneType:
    &"static_cast<std::int32_t>({argName})"
  else:
    argName

proc cppReturnValue(returnType: NimNode, call: string): string =
  if returnType.isStringType:
    &"gennyBufferToString({call})"
  elif returnType.isRuneType:
    &"static_cast<char32_t>({call})"
  else:
    call

proc addCppCall(
  returnType: NimNode,
  call: string,
  raises: bool
) =
  if not raises:
    members.add "  "
    if returnType.kind != nnkEmpty:
      members.add "return "
    members.add cppReturnValue(returnType, call)
    members.add ";\n"
    return

  hasRaisingProcs = true
  if returnType.kind == nnkEmpty:
    members.add &"  {call};\n"
    members.add "  throwIfError();\n"
  else:
    members.add &"  auto result = {call};\n"
    if returnType.isStringType:
      members.add "  throwIfError(result);\n"
    else:
      members.add "  throwIfError();\n"
    members.add &"  return {cppReturnValue(returnType, \"result\")};\n"

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
    argsConverted.add exportTypeCppAbi(argType, toSnakeCase(argName.getParamName()))
  dllProc(procName, argsConverted, restype)

proc dllProc*(procName: string, restype: string) =
  var a: seq[(string)]
  dllProc(procName, a, restype)

proc exportConstCpp*(sym: NimNode) =
  types.add &"static constexpr auto {toCapSnakeCase(sym.repr)} = {sym.getImpl()[2].repr};\n"
  types.add "\n"

proc exportEnumCpp*(sym: NimNode) =
  types.add &"using {sym.repr} = std::uint8_t;\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    types.add &"static constexpr {sym.repr} {toCapSnakeCase(entry.repr)} = {i};\n"
  types.add "\n"

proc exportProcCpp*(
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
  dllProc(&"$lib_{apiProcName}", dllParams, exportReturnTypeCppAbi(procReturn))

  if owner == nil:
    if procReturn.kind != nnkEmpty:
      members.add exportReturnTypeCpp(procReturn)
      members.add " "
    members.add procName
    members.add "("
    for param in procParams:
      members.add exportTypeCpp(param[1], param[0].getParamName())
      members.add ", "
    members.removeSuffix ", "
    members.add ") {\n"
    var call = &"$lib_{apiProcName}("
    for param in procParams:
      call.add cppArgValue(param[1], param[0].getParamName())
      call.add ", "
    call.removeSuffix ", "
    call.add ")"
    addCppCall(procReturn, call, procRaises)
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

    let methodName =
      if procName.isOperatorName:
        procName.cppOperatorName()
      else:
        procName

    classes.add &"  {exportReturnTypeCpp(procReturn)} {methodName}("
    for param in procParams[1..^1]:
      classes.add exportTypeCpp(param[1], param[0].getParamName())
      classes.add ", "
    classes.removeSuffix ", "
    classes.add ");\n\n"

    members.add &"{exportReturnTypeCpp(procReturn)} {owner.getName()}::{methodName}("
    for param in procParams[1..^1]:
      members.add exportTypeCpp(param[1], param[0].getParamName())
      members.add ", "
    members.removeSuffix ", "
    members.add ") "
    members.add "{\n"
    var call = &"$lib_{apiProcName}(*this, "
    for param in procParams[1..^1]:
      call.add cppArgValue(param[1], param[0].getParamName())
      call.add ", "
    call.removeSuffix ", "
    call.add ")"
    addCppCall(procReturn, call, procRaises)
    members.add "};\n\n"

proc exportObjectCpp*(
  sym: NimNode,
  fields: seq[ObjectField],
  constructor: NimNode
) =
  let
    objName = sym.repr
    objFields = sym.objectFields(fields)

  types.add &"struct {objName};\n\n"

  classes.add &"struct {objName} " & "{\n"
  for field in objFields:
    classes.add &"  {exportTypeCpp(field.typ, toSnakeCase(field.name))};\n"

  if constructor != nil:
    exportProcCpp(constructor)
  else:
    procs.add &"{objName} $lib_{toSnakeCase(objName)}("
    for field in objFields:
      procs.add &"{exportTypeCppAbi(field.typ, toSnakeCase(field.name))}, "
    procs.removeSuffix ", "
    procs.add ");\n\n"

    members.add &"{objName} {objName.unCapitalize()}("
    for field in objFields:
      members.add &"{exportTypeCpp(field.typ, field.name)}"
      members.add ", "
    members.removeSuffix ", "
    members.add ") "
    members.add "{\n"
    members.add &"  return "
    members.add  &"$lib_{toSnakeCase(objName)}("
    for field in objFields:
      members.add cppArgValue(field.typ, field.name)
      members.add ", "
    members.removeSuffix ", "
    members.add ");\n"
    members.add "};\n\n"

  dllProc(&"$lib_{toSnakeCase(objName)}_eq", [&"{objName} a", &"{objName} b"], "bool")

proc genRefObject(objName: string) =

  types.add &"struct {objName};\n\n"

  let unrefLibProc = &"$lib_{toSnakeCase(objName)}_unref"

  dllProc(unrefLibProc, [objName & " " & toSnakeCase(objName)], "void")

proc genSeqProcs(objName, procPrefix, selfSuffix: string, entryType: NimNode) =
  let objArg = objName & " " & toSnakeCase(objName)
  dllProc(&"{procPrefix}_len", [objArg], "std::intptr_t")
  dllProc(&"{procPrefix}_get", [objArg, "std::intptr_t index"], exportReturnTypeCppAbi(entryType))
  dllProc(&"{procPrefix}_set", [objArg, "std::intptr_t index", exportTypeCppAbi(entryType, "value")], "void")
  dllProc(&"{procPrefix}_delete", [objArg, "std::intptr_t index"], "void")
  dllProc(&"{procPrefix}_add", [objArg, exportTypeCppAbi(entryType, "value")], "void")
  dllProc(&"{procPrefix}_clear", [objArg], "void")

proc genSeqClassMethods(seqName, procPrefix: string, entryType: NimNode) =
  let
    entryTypeCpp = exportTypeCpp(entryType)
    entryReturnTypeCpp = exportReturnTypeCpp(entryType)
    entryValue = cppArgValue(entryType, "value")
    getCall = &"{procPrefix}_get(*this, index)"

  classes.add &"  std::intptr_t size();\n"
  classes.add &"  {entryReturnTypeCpp} get(std::intptr_t index);\n"
  classes.add &"  {entryReturnTypeCpp} operator[](std::intptr_t index);\n"
  classes.add &"  void set(std::intptr_t index, {entryTypeCpp} value);\n"
  classes.add &"  void removeAt(std::intptr_t index);\n"
  classes.add &"  void add({entryTypeCpp} value);\n"
  classes.add &"  void clear();\n\n"

  members.add &"std::intptr_t {seqName}::size()" & "{\n"
  members.add &"  return {procPrefix}_len(*this);\n"
  members.add "}\n\n"

  members.add &"{entryReturnTypeCpp} {seqName}::get(std::intptr_t index)" & "{\n"
  members.add &"  return {cppReturnValue(entryType, getCall)};\n"
  members.add "}\n\n"

  members.add &"{entryReturnTypeCpp} {seqName}::operator[](std::intptr_t index)" & "{\n"
  members.add &"  return get(index);\n"
  members.add "}\n\n"

  members.add &"void {seqName}::set(std::intptr_t index, {entryTypeCpp} value)" & "{\n"
  members.add &"  {procPrefix}_set(*this, index, {entryValue});\n"
  members.add "}\n\n"

  members.add &"void {seqName}::removeAt(std::intptr_t index)" & "{\n"
  members.add &"  {procPrefix}_delete(*this, index);\n"
  members.add "}\n\n"

  members.add &"void {seqName}::add({entryTypeCpp} value)" & "{\n"
  members.add &"  {procPrefix}_add(*this, {entryValue});\n"
  members.add "}\n\n"

  members.add &"void {seqName}::clear()" & "{\n"
  members.add &"  {procPrefix}_clear(*this);\n"
  members.add "}\n\n"

proc genSeqFieldMethods(objName, procPrefix, fieldName: string, entryType: NimNode) =
  var fieldCap = fieldName
  fieldCap[0] = toUpperAscii(fieldCap[0])

  let
    entryTypeCpp = exportTypeCpp(entryType)
    entryReturnTypeCpp = exportReturnTypeCpp(entryType)
    entryValue = cppArgValue(entryType, "value")
    getCall = &"{procPrefix}_get(*this, index)"

  classes.add &"  std::intptr_t {fieldName}Size();\n"
  classes.add &"  {entryReturnTypeCpp} get{fieldCap}(std::intptr_t index);\n"
  classes.add &"  void set{fieldCap}(std::intptr_t index, {entryTypeCpp} value);\n"
  classes.add &"  void remove{fieldCap}(std::intptr_t index);\n"
  classes.add &"  void add{fieldCap}({entryTypeCpp} value);\n"
  classes.add &"  void clear{fieldCap}();\n\n"

  members.add &"std::intptr_t {objName}::{fieldName}Size()" & "{\n"
  members.add &"  return {procPrefix}_len(*this);\n"
  members.add "}\n\n"

  members.add &"{entryReturnTypeCpp} {objName}::get{fieldCap}(std::intptr_t index)" & "{\n"
  members.add &"  return {cppReturnValue(entryType, getCall)};\n"
  members.add "}\n\n"

  members.add &"void {objName}::set{fieldCap}(std::intptr_t index, {entryTypeCpp} value)" & "{\n"
  members.add &"  {procPrefix}_set(*this, index, {entryValue});\n"
  members.add "}\n\n"

  members.add &"void {objName}::remove{fieldCap}(std::intptr_t index)" & "{\n"
  members.add &"  {procPrefix}_delete(*this, index);\n"
  members.add "}\n\n"

  members.add &"void {objName}::add{fieldCap}({entryTypeCpp} value)" & "{\n"
  members.add &"  {procPrefix}_add(*this, {entryValue});\n"
  members.add "}\n\n"

  members.add &"void {objName}::clear{fieldCap}()" & "{\n"
  members.add &"  {procPrefix}_clear(*this);\n"
  members.add "}\n\n"

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
  classes.add &"  std::uintptr_t reference;\n\n"
  classes.add &"  public:\n\n"

  if constructor != nil:
      let
        constructorLibProc = &"$lib_{toSnakeCase(constructor.repr)}"
        constructorType = constructor.getTypeInst()
        constructorParams = constructorType[0][1 .. ^1]
        constructorRaises = constructor.raises()

      classes.add &"  {objName}("
      for param in constructorParams:
        classes.add exportTypeCpp(param[1], param[0].getParamName())
        classes.add ", "
      classes.removeSuffix ", "
      classes.add ");\n\n"

      members.add &"{objName}::{objName}("
      for param in constructorParams:
        members.add exportTypeCpp(param[1], param[0].getParamName())
        members.add ", "
      members.removeSuffix ", "
      members.add ")"
      members.add " {\n"
      members.add &"  auto result = "
      members.add  &"{constructorLibProc}("
      for param in constructorParams:
        members.add cppArgValue(param[1], param[0].getParamName())
        members.add ", "
      members.removeSuffix ", "
      members.add ");\n"
      if constructorRaises:
        hasRaisingProcs = true
        members.add "  throwIfError();\n"
      members.add "  this->reference = result.reference;\n"
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

      dllProc(getProcName, [objName & " " & objNameSnaked], exportReturnTypeCppAbi(fieldType))
      dllProc(setProcName, [objName & " " & objNameSnaked, exportTypeCppAbi(fieldType, "value")], exportTypeCppAbi(nil))

      classes.add &"  {exportReturnTypeCpp(fieldType)} {getMemberName}();\n"

      members.add &"{exportReturnTypeCpp(fieldType)} {objName}::{getMemberName}()" & "{\n"
      let getCall = &"{getProcName}(*this)"
      members.add &"  return {cppReturnValue(fieldType, getCall)};\n"
      members.add "}\n\n"

      classes.add &"  void {setMemberName}({exportTypeCpp(fieldType)} value);\n\n"

      members.add &"void {objName}::{setMemberName}({exportTypeCpp(fieldType)} value)" & "{\n"
      let setValue = cppArgValue(fieldType, "value")
      members.add &"  {setProcName}(*this, {setValue});\n"
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
      genSeqFieldMethods(
        objName,
        &"$lib_{objNameSnaked}_{fieldNameSnaked}",
        fieldName,
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
  classes.add &"  std::uintptr_t reference;\n\n"
  classes.add &"  public:\n\n"

  classes.add &"  {seqName}();\n\n"

  classes.add &"  void free();\n\n"

  members.add &"{seqName}::{seqName}()" & "{\n"
  members.add &"  this->reference = {newSeqProc}().reference;\n"
  members.add "}\n\n"

  genSeqClassMethods(
    seqName,
    &"$lib_{seqNameSnaked}",
    sym[1]
  )

  members.add &"void {seqName}::free()" & "{\n"
  members.add &"  $lib_{toSnakeCase(seqName)}_unref(*this);\n"
  members.add "}\n\n"


const header = """
#ifndef INCLUDE_$LIB_H
#define INCLUDE_$LIB_H

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string>

"""

const bufferClass = """
struct GennyBuffer {

  private:

  std::uintptr_t reference;

  public:

  const char* data();
  std::intptr_t len();
  void free();

};

"""

const bufferProcs = """
const char* $lib_genny_buffer_data(GennyBuffer buffer);
std::intptr_t $lib_genny_buffer_len(GennyBuffer buffer);
void $lib_genny_buffer_unref(GennyBuffer buffer);

"""

const bufferMembers = """
static inline std::string gennyBufferToString(GennyBuffer buffer) {
  const char* data = $lib_genny_buffer_data(buffer);
  std::intptr_t len = $lib_genny_buffer_len(buffer);
  std::string result;
  if (data != nullptr && len > 0) {
    result.assign(data, static_cast<std::size_t>(len));
  }
  $lib_genny_buffer_unref(buffer);
  return result;
}

const char* GennyBuffer::data() {
  return $lib_genny_buffer_data(*this);
}

std::intptr_t GennyBuffer::len() {
  return $lib_genny_buffer_len(*this);
}

void GennyBuffer::free() {
  $lib_genny_buffer_unref(*this);
}

"""

const errorMembers = """
struct $LibException : public std::runtime_error {
  explicit $LibException(const std::string& message) : std::runtime_error(message) {}
};

static inline void throwIfError() {
  if ($lib_check_error()) {
    throw $LibException(gennyBufferToString($lib_take_error()));
  }
}

static inline void throwIfError(GennyBuffer buffer) {
  if ($lib_check_error()) {
    $lib_genny_buffer_unref(buffer);
    throw $LibException(gennyBufferToString($lib_take_error()));
  }
}

"""

const footer = """
#endif
"""

proc writeCpp*(dir, lib: string) =
  let errorBlock =
    if hasRaisingProcs:
      errorMembers
    else:
      ""
  createDir(dir)
  writeFile(&"{dir}/{toSnakeCase(lib)}.hpp", (
      header &
      types &
      bufferClass &
      classes &
      "extern \"C\" {\n\n" &
      bufferProcs &
      procs &
      "}\n\n" &
      bufferMembers &
      errorBlock &
      members &
      footer
    ).replace("$Lib", lib).replace("$lib", toSnakeCase(lib)).replace("$LIB", lib.toUpperAscii())
  )
