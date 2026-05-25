import
  std/[compilesettings, macros, os, sets, strformat, strutils, tables],
  ../common

type
  FieldInfo = tuple[name: string, typ: NimNode]

var
  cTypes {.compiletime.}: string
  cProtos {.compiletime.}: string
  cTypeBlocks {.compiletime.}: string
  cWrappers {.compiletime.}: string
  cModuleMethods {.compiletime.}: string
  cModuleInit {.compiletime.}: string
  cForwardDecls {.compiletime.}: string
  valueObjectNames {.compiletime.}: HashSet[string]
  refObjectNames {.compiletime.}: HashSet[string]
  seqObjectNames {.compiletime.}: HashSet[string]
  valueObjectFields {.compiletime.}: Table[string, seq[FieldInfo]]
  valueObjectConstructors {.compiletime.}: Table[string, string]
  seqEntryTypes {.compiletime.}: Table[string, NimNode]
  seqNewProcs {.compiletime.}: Table[string, string]
  typeMethods {.compiletime.}: Table[string, string]
  enumTypeNames {.compiletime.}: HashSet[string]
  needsErrorBridge {.compiletime.}: bool

proc cString(s: string): string =
  result = "\""
  for ch in s:
    case ch
    of '\\': result.add "\\\\"
    of '"': result.add "\\\""
    of '\n': result.add "\\n"
    of '\r': discard
    else: result.add ch
  result.add "\""

proc cIdent(s: string): string =
  for ch in s:
    if ch in {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
      result.add ch
    else:
      result.add '_'

proc stripSink(sym: NimNode): NimNode =
  ## Removes Nim's `sink[T]` ownership wrapper before emitting C/CPython type
  ## declarations. The native extension deals in payload types; Nim keeps the
  ## move/ownership semantics on the generated wrapper side.
  if sym.kind == nnkBracketExpr and sym[0].repr == "sink":
    sym[1]
  else:
    sym

proc nativeName(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.kind == nnkBracketExpr:
    typ.getSeqName()
  else:
    case typ.repr
    of "Vec2": "Vector2"
    of "Mat3": "Matrix3"
    else: typ.repr

proc typeObjName(name: string): string =
  "GennyPy_" & cIdent(name) & "_Type"

proc pyStructName(name: string): string =
  "GennyPy_" & cIdent(name)

proc isVoid(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkEmpty or typ.repr in ["", "nil", "None"]

proc isSeqType(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr in ["seq", "openArray"]

proc isArrayType(sym: NimNode): bool =
  let typ = sym.stripSink
  typ.kind == nnkBracketExpr and typ[0].repr == "array"

proc isRefLikeObjectType(sym: NimNode): bool
proc cBaseType(sym: NimNode): string
proc cType(sym: NimNode): string

proc cArraySuffix(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.isArrayType:
    result.add &"[{typ[1].repr}]"
    result.add cArraySuffix(typ[2])

proc cBaseType(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.isArrayType:
    return cBaseType(typ[2])
  if typ.isSeqType:
    return "void *"

  let name = typ.nativeName()
  if name in enumTypeNames:
    return "int"
  if typ.isRefLikeObjectType:
    return "void *"

  case name
  of "string", "cstring": "char *"
  of "bool": "char"
  of "byte", "uint8": "unsigned char"
  of "int8": "signed char"
  of "int16": "short"
  of "uint16": "unsigned short"
  of "int32", "Rune": "int"
  of "uint32": "unsigned int"
  of "int64", "int": "long long"
  of "uint64", "uint": "unsigned long long"
  of "float32": "float"
  of "float64", "float": "double"
  of "", "nil", "None": "void"
  else: name

proc cReturnType(sym: NimNode): string =
  let typ = sym.stripSink
  if typ.nativeName() == "string":
    "void *"
  else:
    cType(typ)

proc cType(sym: NimNode): string =
  if sym.isArrayType:
    error("array types need a declarator name", sym)
  cBaseType(sym)

proc cDecl(sym: NimNode, name: string): string =
  let typ = sym.stripSink
  if typ.isArrayType:
    cBaseType(typ) & " " & name & cArraySuffix(typ)
  else:
    cType(typ) & " " & name

proc pyTypeName(sym: NimNode): string =
  sym.nativeName()

proc isValueObjectType(sym: NimNode): bool =
  sym.pyTypeName() in valueObjectNames

proc isRefObjectType(sym: NimNode): bool =
  sym.pyTypeName() in refObjectNames

proc isNativeSeqObjectType(sym: NimNode): bool =
  sym.pyTypeName() in seqObjectNames

proc isForwardRefObjectType(sym: NimNode): bool =
  let name = sym.pyTypeName()
  name.len > 0 and name[0] in {'A'..'Z'} and
    name notin ["Rune"] and
    name notin valueObjectNames and name notin enumTypeNames

proc isRefLikeObjectType(sym: NimNode): bool =
  sym.isRefObjectType or sym.isNativeSeqObjectType or sym.isForwardRefObjectType

proc apiProcName(sym: NimNode, owner: NimNode = nil, prefixes: openarray[NimNode] = []): string =
  result = "$lib_"
  if owner != nil:
    result.add &"{toSnakeCase(owner.getName())}_"
  for prefix in prefixes:
    result.add &"{toSnakeCase(prefix.getName())}_"
  result.add toSnakeCase(sym.repr)

proc pyProcName(sym: NimNode, owner: NimNode = nil, prefixes: openarray[NimNode] = []): string =
  if owner != nil:
    for prefix in prefixes:
      if prefix.getImpl().kind != nnkNilLit:
        if prefix.getImpl()[2].kind != nnkEnumTy:
          result.add &"{toSnakeCase(prefix.repr)}_"
  result.add toSnakeCase(sym.repr)

proc getDefaults(sym: NimNode): seq[NimNode] =
  let procType = sym.getTypeInst()
  let procParams = procType[0][1 .. ^1]
  for param in procParams:
    for _ in 0 .. param.len - 3:
      result.add newEmptyNode()

  var defaults: seq[(string, NimNode)]
  for identDefs in sym.getImpl()[3][1 .. ^1]:
    let default = identDefs[^1]
    for entry in identDefs[0 .. ^3]:
      defaults.add((entry.repr, default))

  for i in 0 ..< min(result.len, defaults.len):
    result[i] = defaults[i][1]

proc defaultIsSimple(default: NimNode): bool =
  if default.kind == nnkEmpty:
    return false
  case default.kind
  of nnkIntLit, nnkUIntLit, nnkFloatLit, nnkFloat32Lit, nnkFloat64Lit:
    true
  of nnkIdent:
    true
  else:
    false

proc cDefaultLiteral(default: NimNode): string =
  case default.kind
  of nnkIdent:
    case default.repr
    of "true": "1"
    of "false": "0"
    else: toCapSnakeCase(default.repr)
  else:
    default.repr

proc pyFromC(expr: string, typ: NimNode): string =
  let baseTyp = typ.stripSink
  let name = baseTyp.pyTypeName()
  if baseTyp.isVoid:
    return "Py_RETURN_NONE"
  if baseTyp.isValueObjectType:
    return &"GennyPy_{cIdent(name)}_FromValue({expr})"
  if baseTyp.isRefLikeObjectType:
    return &"GennyPy_{cIdent(name)}_FromRef((void *)({expr}))"
  if baseTyp.isSeqType:
    let seqName = baseTyp.getSeqName()
    return &"GennyPy_{cIdent(seqName)}_FromRef((void *)({expr}))"

  case baseTyp.nativeName()
  of "string":
    &"genny_buffer_to_py((void *)({expr}))"
  of "cstring":
    &"PyUnicode_FromString(({expr}) ? ({expr}) : \"\")"
  of "bool":
    &"PyBool_FromLong((long)({expr}))"
  of "byte", "uint8", "uint16", "uint32", "uint64", "uint":
    &"PyLong_FromUnsignedLongLong((unsigned long long)({expr}))"
  of "Rune":
    &"PyUnicode_FromOrdinal((int)({expr}))"
  of "int8", "int16", "int32", "int64", "int":
    &"PyLong_FromLongLong((long long)({expr}))"
  of "float32", "float64", "float":
    &"PyFloat_FromDouble((double)({expr}))"
  else:
    &"PyLong_FromLongLong((long long)({expr}))"

proc convertPyToC(pyExpr, outExpr: string, typ: NimNode, label: string): string =
  let baseTyp = typ.stripSink
  let name = baseTyp.pyTypeName()
  if baseTyp.isValueObjectType:
    return &"  if (!GennyPy_{cIdent(name)}_AsValue({pyExpr}, &{outExpr}, {cString(label)})) return NULL;\n"
  if baseTyp.isRefLikeObjectType:
    return &"  if (!GennyPy_{cIdent(name)}_AsRef({pyExpr}, &{outExpr}, {cString(label)})) return NULL;\n"
  if baseTyp.isSeqType:
    let seqName = baseTyp.getSeqName()
    return &"  if (!GennyPy_{cIdent(seqName)}_AsRef({pyExpr}, &{outExpr}, {cString(label)})) return NULL;\n"

  case baseTyp.nativeName()
  of "string", "cstring":
    &"  {outExpr} = (char *)PyUnicode_AsUTF8({pyExpr});\n" &
    &"  if ({outExpr} == NULL) return NULL;\n"
  of "bool":
    &"  {{ int genny_bool = PyObject_IsTrue({pyExpr}); if (genny_bool < 0) return NULL; {outExpr} = (char)genny_bool; }}\n"
  of "byte", "uint8":
    &"  {{ unsigned long genny_value = PyLong_AsUnsignedLong({pyExpr}); if (PyErr_Occurred()) return NULL; if (genny_value > 255UL) {{ PyErr_Format(PyExc_OverflowError, \"%s out of range\", {cString(label)}); return NULL; }} {outExpr} = (unsigned char)genny_value; }}\n"
  of "uint16", "uint32", "uint64", "uint":
    &"  {{ unsigned long long genny_value = PyLong_AsUnsignedLongLong({pyExpr}); if (PyErr_Occurred()) return NULL; {outExpr} = ({cType(baseTyp)})genny_value; }}\n"
  of "Rune":
    &"  if (!PyUnicode_Check({pyExpr})) {{ PyErr_Format(PyExc_AssertionError, \"%s must be a single-character string\", {cString(label)}); return NULL; }}\n" &
    &"  {{ Py_ssize_t genny_len = PyUnicode_GetLength({pyExpr}); if (genny_len < 0) return NULL; if (genny_len != 1) {{ PyErr_Format(PyExc_AssertionError, \"%s must be exactly one Unicode scalar value\", {cString(label)}); return NULL; }} }}\n" &
    &"  {{ Py_UCS4 genny_rune = PyUnicode_ReadChar({pyExpr}, 0); if (genny_rune == (Py_UCS4)-1 && PyErr_Occurred()) return NULL; if (genny_rune >= 0xD800 && genny_rune <= 0xDFFF) {{ PyErr_Format(PyExc_AssertionError, \"%s must be a Unicode scalar value\", {cString(label)}); return NULL; }} {outExpr} = ({cType(baseTyp)})genny_rune; }}\n"
  of "int8", "int16", "int32", "int64", "int":
    &"  {{ long long genny_value = PyLong_AsLongLong({pyExpr}); if (PyErr_Occurred()) return NULL; {outExpr} = ({cType(baseTyp)})genny_value; }}\n"
  of "float32", "float64", "float":
    &"  {{ double genny_value = PyFloat_AsDouble({pyExpr}); if (PyErr_Occurred()) return NULL; {outExpr} = ({cType(baseTyp)})genny_value; }}\n"
  else:
    &"  {{ long long genny_value = PyLong_AsLongLong({pyExpr}); if (PyErr_Occurred()) return NULL; {outExpr} = ({cType(baseTyp)})genny_value; }}\n"

proc convertPyToCInt(pyExpr, outExpr: string, typ: NimNode, label: string): string =
  convertPyToC(pyExpr, outExpr, typ, label).replace("return NULL", "return -1")

proc addProto(procName: string, params: seq[(string, NimNode)], ret: NimNode) =
  cProtos.add "extern " & cReturnType(ret) & " " & procName & "("
  for (name, typ) in params:
    cProtos.add cDecl(typ, name) & ", "
  cProtos.removeSuffix(", ")
  cProtos.add ");\n"

proc addModuleMethod(pyName, wrapperName: string) =
  cModuleMethods.add &"  {{{cString(pyName)}, (PyCFunction){wrapperName}, METH_VARARGS | METH_KEYWORDS, NULL}},\n"

proc addErrorCheck(procRaises: bool): string =
  if procRaises:
    needsErrorBridge = true
    result.add "  if ($lib_native_check_error != NULL && $lib_native_check_error()) {\n"
    result.add "    genny_set_error_from_buffer($lib_native_take_error());\n"
    result.add "    return NULL;\n"
    result.add "  }\n"

proc addErrorCheckInt(procRaises: bool): string =
  if procRaises:
    needsErrorBridge = true
    result.add "  if ($lib_native_check_error != NULL && $lib_native_check_error()) {\n"
    result.add "    genny_set_error_from_buffer($lib_native_take_error());\n"
    result.add "    return -1;\n"
    result.add "  }\n"

proc declareFields(objName: string, fields: seq[FieldInfo]) =
  cTypes.add &"typedef struct {objName} {{\n"
  for field in fields:
    cTypes.add "  " & cDecl(field.typ, toSnakeCase(field.name)) & ";\n"
  cTypes.add &"}} {objName};\n\n"

proc arrayToPy(fieldExpr: string, fieldType: NimNode): string =
  if not fieldType.isArrayType:
    return pyFromC(fieldExpr, fieldType)
  let count = fieldType[1].intVal
  let elemType = fieldType[2]
  let listName = "genny_list"
  result.add &"  PyObject *{listName} = PyList_New({count});\n"
  result.add &"  if ({listName} == NULL) return NULL;\n"
  result.add &"  for (Py_ssize_t i = 0; i < {count}; ++i) {{\n"
  result.add &"    PyObject *item = {pyFromC(fieldExpr & \"[i]\", elemType)};\n"
  result.add "    if (item == NULL) { Py_DECREF(genny_list); return NULL; }\n"
  result.add "    PyList_SET_ITEM(genny_list, i, item);\n"
  result.add "  }\n"
  result.add &"  return {listName};\n"

proc arraySetFromPy(fieldExpr: string, fieldType: NimNode): string =
  let count = fieldType[1].intVal
  let elemType = fieldType[2]
  result.add "  if (!PySequence_Check(value) || PySequence_Size(value) != " & $count & ") {\n"
  result.add &"    PyErr_SetString(PyExc_TypeError, \"expected a sequence of length {count}\");\n"
  result.add "    return -1;\n"
  result.add "  }\n"
  result.add &"  for (Py_ssize_t i = 0; i < {count}; ++i) {{\n"
  result.add "    PyObject *item = PySequence_GetItem(value, i);\n"
  result.add "    if (item == NULL) return -1;\n"
  result.add &"    {cType(elemType)} converted;\n"
  result.add convertPyToCInt("item", "converted", elemType, "array item").replace("return -1", "{ Py_DECREF(item); return -1; }")
  result.add &"    {fieldExpr}[i] = converted;\n"
  result.add "    Py_DECREF(item);\n"
  result.add "  }\n"

proc objectDefaultExpr(objName: string, default: NimNode): string =
  if objName in valueObjectConstructors and valueObjectConstructors[objName] != "":
    return valueObjectConstructors[objName] & "()"
  result = "(" & objName & "){0}"
  if default.kind == nnkCall and default.len > 1 and objName in valueObjectFields:
    let fields = valueObjectFields[objName]
    var parts: seq[string]
    for i in 1 ..< min(default.len, fields.len + 1):
      parts.add "." & toSnakeCase(fields[i - 1].name) & " = " & cDefaultLiteral(default[i])
    if parts.len > 0:
      result = "(" & objName & "){" & parts.join(", ") & "}"

proc emitParamSetup(
  procParams: seq[NimNode],
  defaults: seq[NimNode],
  skipFirst: bool
): tuple[argNames, cNames, declarations, conversions, namesArray: string, required, nparams: int] =
  var parseNames: seq[string]
  var argVars: seq[string]
  var required = 0
  for i, param in procParams:
    if skipFirst and i == 0:
      continue
    for j in 0 .. param.len - 3:
      let
        paramName = toSnakeCase(param[j].repr)
        argVar = "arg_" & paramName
        cVar = "c_" & paramName
        paramType = param[^2]
        default = defaults[i]
      parseNames.add paramName
      argVars.add argVar
      if default.kind == nnkEmpty:
        inc required
      result.declarations.add &"  PyObject *{argVar} = NULL;\n"
      result.declarations.add &"  {cDecl(paramType, cVar)};\n"
      if default.kind == nnkEmpty:
        result.conversions.add convertPyToC(argVar, cVar, paramType, paramName)
      elif default.defaultIsSimple:
        result.conversions.add &"  if ({argVar} == NULL) {{ {cVar} = ({cType(paramType)})({cDefaultLiteral(default)}); }} else {{\n"
        result.conversions.add convertPyToC(argVar, cVar, paramType, paramName).indent(2)
        result.conversions.add "  }\n"
      else:
        let typeName = paramType.pyTypeName()
        if paramType.isSeqType or typeName in seqObjectNames:
          let seqName = if paramType.isSeqType: paramType.getSeqName() else: typeName
          result.conversions.add &"  if ({argVar} == NULL || {argVar} == Py_None) {{ {cVar} = {seqNewProcs.getOrDefault(seqName, \"$lib_new_\" & toSnakeCase(seqName))}(); }} else {{\n"
          result.conversions.add convertPyToC(argVar, cVar, paramType, paramName).indent(2)
          result.conversions.add "  }\n"
        elif typeName in valueObjectNames:
          result.conversions.add &"  if ({argVar} == NULL || {argVar} == Py_None) {{ {cVar} = {objectDefaultExpr(typeName, default)}; }} else {{\n"
          result.conversions.add convertPyToC(argVar, cVar, paramType, paramName).indent(2)
          result.conversions.add "  }\n"
        else:
          result.conversions.add &"  if ({argVar} == NULL || {argVar} == Py_None) {{ memset(&{cVar}, 0, sizeof({cVar})); }} else {{\n"
          result.conversions.add convertPyToC(argVar, cVar, paramType, paramName).indent(2)
          result.conversions.add "  }\n"
      result.cNames.add cVar & ", "
  result.cNames.removeSuffix(", ")
  result.namesArray = "  const char *genny_names[] = {"
  for name in parseNames:
    result.namesArray.add cString(name) & ", "
  result.namesArray.add "NULL};\n"
  result.argNames = argVars.join(", &")
  if result.argNames.len > 0:
    result.argNames = "&" & result.argNames
  result.required = required
  result.nparams = parseNames.len

proc exportProcPyNative*(
  sym: NimNode,
  owner: NimNode = nil,
  prefixes: openarray[NimNode] = []
) =
  let
    procType = sym.getTypeInst()
    procParams = procType[0][1 .. ^1]
    procReturn = procType[0][0]
    procRaises = sym.raises()
    apiName = apiProcName(sym, owner, prefixes)
    pyName = pyProcName(sym, owner, prefixes)
    wrapperName = "GennyPy_wrap_" & cIdent(apiName)
    defaults = getDefaults(sym)
    onType = owner != nil
    ownerTypeName = if owner == nil: "" else: owner.pyTypeName()

  var protoParams: seq[(string, NimNode)]
  for param in procParams:
    for i in 0 .. param.len - 3:
      protoParams.add((toSnakeCase(param[i].repr), param[^2]))
  addProto(apiName, protoParams, procReturn)

  if procRaises:
    needsErrorBridge = true

  cForwardDecls.add &"static PyObject *{wrapperName}(PyObject *self, PyObject *args, PyObject *kwargs);\n"

  let skipFirst = onType
  let setup = emitParamSetup(procParams, defaults, skipFirst)

  cWrappers.add &"static PyObject *{wrapperName}(PyObject *self, PyObject *args, PyObject *kwargs) {{\n"
  cWrappers.add setup.namesArray
  cWrappers.add setup.declarations
  cWrappers.add &"  if (!genny_parse_args({cString(pyName)}, args, kwargs, {setup.nparams}, genny_names, {setup.required}"
  if setup.nparams > 0:
    cWrappers.add ", " & setup.argNames
  cWrappers.add ")) return NULL;\n"
  cWrappers.add setup.conversions

  var callArgs = setup.cNames
  if onType:
    let selfCast = "((" & pyStructName(ownerTypeName) & " *)self)"
    if ownerTypeName in valueObjectNames:
      callArgs = selfCast & "->value" & (if callArgs.len > 0: ", " & callArgs else: "")
    else:
      callArgs = selfCast & "->ref" & (if callArgs.len > 0: ", " & callArgs else: "")

  if procReturn.isVoid:
    cWrappers.add &"  {apiName}({callArgs});\n"
    cWrappers.add addErrorCheck(procRaises)
    cWrappers.add "  Py_RETURN_NONE;\n"
  else:
    cWrappers.add &"  {cReturnType(procReturn)} genny_result = {apiName}({callArgs});\n"
    cWrappers.add addErrorCheck(procRaises)
    cWrappers.add &"  return {pyFromC(\"genny_result\", procReturn)};\n"
  cWrappers.add "}\n\n"

  if not onType:
    addModuleMethod(pyName, wrapperName)
  else:
    typeMethods[ownerTypeName] = typeMethods.getOrDefault(ownerTypeName) &
      &"  {{{cString(pyName)}, (PyCFunction){wrapperName}, METH_VARARGS | METH_KEYWORDS, NULL}},\n"

proc emitValueObjectType(objName: string, fields: seq[FieldInfo], constructor: NimNode) =
  let
    pyStruct = pyStructName(objName)
    typeObj = typeObjName(objName)
    ctorName = if constructor != nil: "$lib_" & toSnakeCase(objName) else: "$lib_" & toSnakeCase(objName)
    initName = &"GennyPy_{cIdent(objName)}_init"
    newName = &"GennyPy_{cIdent(objName)}_new"
    deallocName = &"GennyPy_{cIdent(objName)}_dealloc"
    richName = &"GennyPy_{cIdent(objName)}_richcompare"
    fromValueName = &"GennyPy_{cIdent(objName)}_FromValue"
    asValueName = &"GennyPy_{cIdent(objName)}_AsValue"

  cForwardDecls.add &"static PyTypeObject {typeObj};\n"
  cForwardDecls.add &"static PyObject *{fromValueName}({objName} value);\n"
  cForwardDecls.add &"static int {asValueName}(PyObject *obj, {objName} *out, const char *name);\n"

  cTypeBlocks.add &"typedef struct {{ PyObject_HEAD {objName} value; PyObject *dict; }} {pyStruct};\n\n"
  cTypeBlocks.add &"static PyObject *{newName}(PyTypeObject *type, PyObject *args, PyObject *kwargs) {{\n"
  cTypeBlocks.add &"  {pyStruct} *self = ({pyStruct} *)type->tp_alloc(type, 0);\n"
  cTypeBlocks.add "  if (self != NULL) { memset(&self->value, 0, sizeof(self->value)); self->dict = NULL; }\n"
  cTypeBlocks.add "  return (PyObject *)self;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static void {deallocName}({pyStruct} *self) {{\n"
  cTypeBlocks.add "  Py_XDECREF(self->dict);\n"
  cTypeBlocks.add "  Py_TYPE(self)->tp_free((PyObject *)self);\n"
  cTypeBlocks.add "}\n\n"

  var ctorParams: seq[NimNode]
  if constructor != nil:
    let ctype = constructor.getTypeInst()
    ctorParams = ctype[0][1 .. ^1]
    var protoParams: seq[(string, NimNode)]
    for param in ctorParams:
      for i in 0 .. param.len - 3:
        protoParams.add((toSnakeCase(param[i].repr), param[^2]))
    addProto(ctorName, protoParams, ident(objName))
  else:
    var protoParams: seq[(string, NimNode)]
    for field in fields:
      protoParams.add((toSnakeCase(field.name), field.typ))
    addProto(ctorName, protoParams, ident(objName))

  cTypeBlocks.add &"static int {initName}({pyStruct} *self, PyObject *args, PyObject *kwargs) {{\n"
  if constructor != nil:
    let setup = emitParamSetup(ctorParams, getDefaults(constructor), false)
    cTypeBlocks.add setup.namesArray
    cTypeBlocks.add setup.declarations
    cTypeBlocks.add &"  if (!genny_parse_args({cString(objName)}, args, kwargs, {setup.nparams}, genny_names, {setup.required}"
    if setup.nparams > 0:
      cTypeBlocks.add ", " & setup.argNames
    cTypeBlocks.add ")) return -1;\n"
    cTypeBlocks.add setup.conversions.replace("return NULL", "return -1")
    cTypeBlocks.add &"  self->value = {ctorName}({setup.cNames});\n"
  else:
    cTypeBlocks.add "  const char *genny_names[] = {"
    for field in fields:
      cTypeBlocks.add cString(toSnakeCase(field.name)) & ", "
    cTypeBlocks.add "NULL};\n"
    for field in fields:
      cTypeBlocks.add &"  PyObject *arg_{toSnakeCase(field.name)} = NULL;\n"
      cTypeBlocks.add &"  {cDecl(field.typ, \"c_\" & toSnakeCase(field.name))};\n"
    cTypeBlocks.add &"  if (!genny_parse_args({cString(objName)}, args, kwargs, {fields.len}, genny_names, {fields.len}"
    if fields.len > 0:
      cTypeBlocks.add ", "
      for field in fields:
        cTypeBlocks.add &"&arg_{toSnakeCase(field.name)}, "
      cTypeBlocks.removeSuffix(", ")
    cTypeBlocks.add ")) return -1;\n"
    for field in fields:
      cTypeBlocks.add convertPyToCInt("arg_" & toSnakeCase(field.name), "c_" & toSnakeCase(field.name), field.typ, toSnakeCase(field.name))
    cTypeBlocks.add &"  self->value = {ctorName}("
    for field in fields:
      cTypeBlocks.add "c_" & toSnakeCase(field.name) & ", "
    cTypeBlocks.removeSuffix(", ")
    cTypeBlocks.add ");\n"
  cTypeBlocks.add "  return 0;\n"
  cTypeBlocks.add "}\n\n"

  for field in fields:
    let
      fieldSnake = toSnakeCase(field.name)
      getter = &"GennyPy_{cIdent(objName)}_get_{fieldSnake}"
      setter = &"GennyPy_{cIdent(objName)}_set_{fieldSnake}"
      fieldExpr = &"self->value.{fieldSnake}"
    cTypeBlocks.add &"static PyObject *{getter}({pyStruct} *self, void *closure) {{\n"
    if field.typ.isArrayType:
      cTypeBlocks.add arrayToPy(fieldExpr, field.typ)
    else:
      cTypeBlocks.add &"  return {pyFromC(fieldExpr, field.typ)};\n"
    cTypeBlocks.add "}\n\n"
    cTypeBlocks.add &"static int {setter}({pyStruct} *self, PyObject *value, void *closure) {{\n"
    cTypeBlocks.add "  if (value == NULL) { PyErr_SetString(PyExc_TypeError, \"cannot delete field\"); return -1; }\n"
    if field.typ.isArrayType:
      cTypeBlocks.add arraySetFromPy(fieldExpr, field.typ)
    else:
      cTypeBlocks.add "  " & cDecl(field.typ, "converted") & ";\n"
      cTypeBlocks.add convertPyToCInt("value", "converted", field.typ, fieldSnake)
      cTypeBlocks.add &"  {fieldExpr} = converted;\n"
    cTypeBlocks.add "  return 0;\n"
    cTypeBlocks.add "}\n\n"

  addProto("$lib_" & toSnakeCase(objName) & "_eq", @[("a", ident(objName)), ("b", ident(objName))], ident("bool"))
  cTypeBlocks.add &"static PyObject *{richName}(PyObject *a, PyObject *b, int op) {{\n"
  cTypeBlocks.add &"  if (!PyObject_TypeCheck(a, &{typeObj}) || !PyObject_TypeCheck(b, &{typeObj})) {{ Py_RETURN_NOTIMPLEMENTED; }}\n"
  cTypeBlocks.add &"  int eq = $lib_{toSnakeCase(objName)}_eq((({pyStruct} *)a)->value, (({pyStruct} *)b)->value);\n"
  cTypeBlocks.add "  if (op == Py_EQ) return PyBool_FromLong(eq);\n"
  cTypeBlocks.add "  if (op == Py_NE) return PyBool_FromLong(!eq);\n"
  cTypeBlocks.add "  Py_RETURN_NOTIMPLEMENTED;\n"
  cTypeBlocks.add "}\n\n"

  cTypeBlocks.add &"static PyObject *{fromValueName}({objName} value) {{\n"
  cTypeBlocks.add &"  {pyStruct} *self = PyObject_New({pyStruct}, &{typeObj});\n"
  cTypeBlocks.add "  if (self == NULL) return NULL;\n"
  cTypeBlocks.add "  self->value = value;\n"
  cTypeBlocks.add "  self->dict = NULL;\n"
  cTypeBlocks.add "  return (PyObject *)self;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static int {asValueName}(PyObject *obj, {objName} *out, const char *name) {{\n"
  cTypeBlocks.add &"  if (!PyObject_TypeCheck(obj, &{typeObj})) {{ PyErr_Format(PyExc_TypeError, \"%s must be {objName}\", name); return 0; }}\n"
  cTypeBlocks.add &"  *out = (({pyStruct} *)obj)->value;\n"
  cTypeBlocks.add "  return 1;\n"
  cTypeBlocks.add "}\n\n"

  cTypeBlocks.add &"static PyGetSetDef GennyPy_{cIdent(objName)}_getset[] = {{\n"
  for field in fields:
    let fieldSnake = toSnakeCase(field.name)
    cTypeBlocks.add &"  {{{cString(fieldSnake)}, (getter)GennyPy_{cIdent(objName)}_get_{fieldSnake}, (setter)GennyPy_{cIdent(objName)}_set_{fieldSnake}, NULL, NULL}},\n"
  cTypeBlocks.add "  {NULL}\n};\n\n"
  cTypeBlocks.add &"static PyMethodDef GennyPy_{cIdent(objName)}_methods[] = {{\n"
  cTypeBlocks.add &"/* GENNY_METHODS_{cIdent(objName)} */\n"
  cTypeBlocks.add "  {NULL}\n};\n\n"
  cTypeBlocks.add &"static PyTypeObject {typeObj} = {{\n"
  cTypeBlocks.add "  PyVarObject_HEAD_INIT(NULL, 0)\n"
  cTypeBlocks.add &"  .tp_name = {cString(\"$lib.\" & objName)},\n"
  cTypeBlocks.add &"  .tp_basicsize = sizeof({pyStruct}),\n"
  cTypeBlocks.add "  .tp_itemsize = 0,\n"
  cTypeBlocks.add &"  .tp_dealloc = (destructor){deallocName},\n"
  cTypeBlocks.add "  .tp_flags = Py_TPFLAGS_DEFAULT,\n"
  cTypeBlocks.add &"  .tp_dictoffset = offsetof({pyStruct}, dict),\n"
  cTypeBlocks.add &"  .tp_new = {newName},\n"
  cTypeBlocks.add &"  .tp_init = (initproc){initName},\n"
  cTypeBlocks.add &"  .tp_richcompare = {richName},\n"
  cTypeBlocks.add &"  .tp_methods = GennyPy_{cIdent(objName)}_methods,\n"
  cTypeBlocks.add &"  .tp_getset = GennyPy_{cIdent(objName)}_getset,\n"
  cTypeBlocks.add "};\n\n"
  cModuleInit.add &"  if (PyType_Ready(&{typeObj}) < 0) return NULL;\n"
  cModuleInit.add &"  Py_INCREF(&{typeObj});\n"
  cModuleInit.add &"  if (PyModule_AddObject(m, {cString(objName)}, (PyObject *)&{typeObj}) < 0) return NULL;\n"

proc exportObjectPyNative*(sym: NimNode, constructor: NimNode) =
  let objName = sym.nativeName()
  valueObjectNames.incl(objName)

  var fields: seq[FieldInfo]
  for identDefs in sym.getImpl()[2][2]:
    for property in identDefs[0 .. ^3]:
      fields.add((property[1].repr, identDefs[^2]))
  valueObjectFields[objName] = fields
  valueObjectConstructors[objName] = if constructor != nil: "$lib_" & toSnakeCase(objName) else: ""
  declareFields(objName, fields)
  emitValueObjectType(objName, fields, constructor)

proc emitRefLikeType(objName: string, constructor: NimNode, isSeq = false, entryType: NimNode = nil)
proc emitSeqMethods(objName, procPrefix, refExpr, typePrefix: string, entryType: NimNode, abiObjName = "")

proc emitRefLikeType(objName: string, constructor: NimNode, isSeq = false, entryType: NimNode = nil) =
  let
    pyStruct = pyStructName(objName)
    typeObj = typeObjName(objName)
    newName = &"GennyPy_{cIdent(objName)}_new"
    initName = &"GennyPy_{cIdent(objName)}_init"
    deallocName = &"GennyPy_{cIdent(objName)}_dealloc"
    boolName = &"GennyPy_{cIdent(objName)}_bool"
    richName = &"GennyPy_{cIdent(objName)}_richcompare"
    fromRefName = &"GennyPy_{cIdent(objName)}_FromRef"
    asRefName = &"GennyPy_{cIdent(objName)}_AsRef"
    unrefName = "$lib_" & toSnakeCase(objName) & "_unref"

  cForwardDecls.add &"static PyTypeObject {typeObj};\n"
  cForwardDecls.add &"static PyObject *{fromRefName}(void *ref);\n"
  cForwardDecls.add &"static int {asRefName}(PyObject *obj, void **out, const char *name);\n"
  cTypeBlocks.add &"typedef struct {{ PyObject_HEAD void *ref; PyObject *dict; }} {pyStruct};\n\n"
  addProto(unrefName, @[(toSnakeCase(objName), ident(objName))], newEmptyNode())

  cTypeBlocks.add &"static PyObject *{newName}(PyTypeObject *type, PyObject *args, PyObject *kwargs) {{\n"
  cTypeBlocks.add &"  {pyStruct} *self = ({pyStruct} *)type->tp_alloc(type, 0);\n"
  cTypeBlocks.add "  if (self != NULL) { self->ref = NULL; self->dict = NULL; }\n"
  cTypeBlocks.add "  return (PyObject *)self;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static void {deallocName}({pyStruct} *self) {{\n"
  cTypeBlocks.add &"  if (self->ref != NULL) {{ {unrefName}(self->ref); self->ref = NULL; }}\n"
  cTypeBlocks.add "  Py_XDECREF(self->dict);\n"
  cTypeBlocks.add "  Py_TYPE(self)->tp_free((PyObject *)self);\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static int {boolName}({pyStruct} *self) {{ return self->ref != NULL; }}\n\n"
  cTypeBlocks.add &"static PyObject *GennyPy_{cIdent(objName)}_get_ref({pyStruct} *self, void *closure) {{ return PyLong_FromVoidPtr(self->ref); }}\n\n"
  cTypeBlocks.add &"static PyObject *{richName}(PyObject *a, PyObject *b, int op) {{\n"
  cTypeBlocks.add &"  if (!PyObject_TypeCheck(a, &{typeObj}) || !PyObject_TypeCheck(b, &{typeObj})) {{ Py_RETURN_NOTIMPLEMENTED; }}\n"
  cTypeBlocks.add &"  int eq = (({pyStruct} *)a)->ref == (({pyStruct} *)b)->ref;\n"
  cTypeBlocks.add "  if (op == Py_EQ) return PyBool_FromLong(eq);\n"
  cTypeBlocks.add "  if (op == Py_NE) return PyBool_FromLong(!eq);\n"
  cTypeBlocks.add "  Py_RETURN_NOTIMPLEMENTED;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static PyObject *{fromRefName}(void *ref) {{\n"
  cTypeBlocks.add &"  {pyStruct} *self = PyObject_New({pyStruct}, &{typeObj});\n"
  cTypeBlocks.add "  if (self == NULL) return NULL;\n"
  cTypeBlocks.add "  self->ref = ref;\n"
  cTypeBlocks.add "  self->dict = NULL;\n"
  cTypeBlocks.add "  return (PyObject *)self;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static int {asRefName}(PyObject *obj, void **out, const char *name) {{\n"
  cTypeBlocks.add &"  if (!PyObject_TypeCheck(obj, &{typeObj})) {{ PyErr_Format(PyExc_TypeError, \"%s must be {objName}\", name); return 0; }}\n"
  cTypeBlocks.add &"  *out = (({pyStruct} *)obj)->ref;\n"
  cTypeBlocks.add "  return 1;\n"
  cTypeBlocks.add "}\n\n"

  cTypeBlocks.add &"static int {initName}({pyStruct} *self, PyObject *args, PyObject *kwargs) {{\n"
  if isSeq:
    let newSeq = "$lib_new_" & toSnakeCase(objName)
    addProto(newSeq, @[], ident(objName))
    cTypeBlocks.add &"  if (!genny_parse_args({cString(objName)}, args, kwargs, 0, NULL, 0)) return -1;\n"
    cTypeBlocks.add &"  self->ref = {newSeq}();\n"
  elif constructor != nil:
    let
      constructorApi = "$lib_" & toSnakeCase(constructor.repr)
      ctype = constructor.getTypeInst()
      ctorParams = ctype[0][1 .. ^1]
      setup = emitParamSetup(ctorParams, getDefaults(constructor), false)
    var protoParams: seq[(string, NimNode)]
    for param in ctorParams:
      for i in 0 .. param.len - 3:
        protoParams.add((toSnakeCase(param[i].repr), param[^2]))
    addProto(constructorApi, protoParams, ident(objName))
    cTypeBlocks.add setup.namesArray
    cTypeBlocks.add setup.declarations
    cTypeBlocks.add &"  if (!genny_parse_args({cString(objName)}, args, kwargs, {setup.nparams}, genny_names, {setup.required}"
    if setup.nparams > 0:
      cTypeBlocks.add ", " & setup.argNames
    cTypeBlocks.add ")) return -1;\n"
    cTypeBlocks.add setup.conversions.replace("return NULL", "return -1")
    cTypeBlocks.add &"  self->ref = {constructorApi}({setup.cNames});\n"
    cTypeBlocks.add addErrorCheckInt(constructor.raises())
  else:
    cTypeBlocks.add &"  if (!genny_parse_args({cString(objName)}, args, kwargs, 0, NULL, 0)) return -1;\n"
    cTypeBlocks.add "  self->ref = NULL;\n"
  cTypeBlocks.add "  return 0;\n"
  cTypeBlocks.add "}\n\n"

  cTypeBlocks.add &"static PyNumberMethods GennyPy_{cIdent(objName)}_number = {{ .nb_bool = (inquiry){boolName} }};\n\n"
  if isSeq:
    emitSeqMethods(objName, "$lib_" & toSnakeCase(objName), &"(({pyStruct} *)self)->ref", "GennyPy_" & cIdent(objName), entryType)

  cTypeBlocks.add &"static PyMethodDef GennyPy_{cIdent(objName)}_methods[] = {{\n"
  if isSeq:
    cTypeBlocks.add &"  {{{cString(\"append\")}, (PyCFunction)GennyPy_{cIdent(objName)}_append, METH_O, NULL}},\n"
    cTypeBlocks.add &"  {{{cString(\"add\")}, (PyCFunction)GennyPy_{cIdent(objName)}_append, METH_O, NULL}},\n"
    cTypeBlocks.add &"  {{{cString(\"clear\")}, (PyCFunction)GennyPy_{cIdent(objName)}_clear, METH_NOARGS, NULL}},\n"
  cTypeBlocks.add &"/* GENNY_METHODS_{cIdent(objName)} */\n"
  cTypeBlocks.add "  {NULL}\n};\n\n"

  cTypeBlocks.add &"static PyGetSetDef GennyPy_{cIdent(objName)}_getset[] = {{\n"
  cTypeBlocks.add &"  {{{cString(\"ref\")}, (getter)GennyPy_{cIdent(objName)}_get_ref, NULL, NULL, NULL}},\n"
  cTypeBlocks.add "  {NULL}\n};\n\n"
  cTypeBlocks.add &"static PyTypeObject {typeObj} = {{\n"
  cTypeBlocks.add "  PyVarObject_HEAD_INIT(NULL, 0)\n"
  cTypeBlocks.add &"  .tp_name = {cString(\"$lib.\" & objName)},\n"
  cTypeBlocks.add &"  .tp_basicsize = sizeof({pyStruct}),\n"
  cTypeBlocks.add "  .tp_itemsize = 0,\n"
  cTypeBlocks.add &"  .tp_dealloc = (destructor){deallocName},\n"
  cTypeBlocks.add "  .tp_flags = Py_TPFLAGS_DEFAULT,\n"
  cTypeBlocks.add &"  .tp_dictoffset = offsetof({pyStruct}, dict),\n"
  cTypeBlocks.add &"  .tp_new = {newName},\n"
  cTypeBlocks.add &"  .tp_init = (initproc){initName},\n"
  cTypeBlocks.add &"  .tp_richcompare = {richName},\n"
  cTypeBlocks.add &"  .tp_as_number = &GennyPy_{cIdent(objName)}_number,\n"
  if isSeq:
    cTypeBlocks.add &"  .tp_as_sequence = &GennyPy_{cIdent(objName)}_sequence,\n"
  cTypeBlocks.add &"  .tp_methods = GennyPy_{cIdent(objName)}_methods,\n"
  cTypeBlocks.add &"  .tp_getset = GennyPy_{cIdent(objName)}_getset,\n"
  cTypeBlocks.add "};\n\n"
  cModuleInit.add &"  if (PyType_Ready(&{typeObj}) < 0) return NULL;\n"
  cModuleInit.add &"  Py_INCREF(&{typeObj});\n"
  cModuleInit.add &"  if (PyModule_AddObject(m, {cString(objName)}, (PyObject *)&{typeObj}) < 0) return NULL;\n"

proc emitSeqMethods(objName, procPrefix, refExpr, typePrefix: string, entryType: NimNode, abiObjName = "") =
  let abiName = if abiObjName.len > 0: abiObjName else: objName
  addProto(procPrefix & "_len", @[(toSnakeCase(abiName), ident(abiName))], ident("int"))
  addProto(procPrefix & "_get", @[(toSnakeCase(abiName), ident(abiName)), ("i", ident("int"))], entryType)
  addProto(procPrefix & "_set", @[(toSnakeCase(abiName), ident(abiName)), ("i", ident("int")), ("v", entryType)], newEmptyNode())
  addProto(procPrefix & "_delete", @[(toSnakeCase(abiName), ident(abiName)), ("i", ident("int"))], newEmptyNode())
  addProto(procPrefix & "_add", @[(toSnakeCase(abiName), ident(abiName)), ("v", entryType)], newEmptyNode())
  addProto(procPrefix & "_clear", @[(toSnakeCase(abiName), ident(abiName))], newEmptyNode())

  cTypeBlocks.add &"static Py_ssize_t {typePrefix}_len(PyObject *self) {{ return (Py_ssize_t){procPrefix}_len({refExpr}); }}\n\n"
  cTypeBlocks.add &"static PyObject *{typePrefix}_item(PyObject *self, Py_ssize_t index) {{\n"
  cTypeBlocks.add &"  Py_ssize_t len = {typePrefix}_len(self);\n"
  cTypeBlocks.add "  if (index < 0) index += len;\n"
  cTypeBlocks.add "  if (index < 0 || index >= len) { PyErr_SetString(PyExc_IndexError, \"index out of range\"); return NULL; }\n"
  cTypeBlocks.add &"  {cReturnType(entryType)} value = {procPrefix}_get({refExpr}, (long long)index);\n"
  cTypeBlocks.add &"  return {pyFromC(\"value\", entryType)};\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static int {typePrefix}_ass_item(PyObject *self, Py_ssize_t index, PyObject *value) {{\n"
  cTypeBlocks.add &"  Py_ssize_t len = {typePrefix}_len(self);\n"
  cTypeBlocks.add "  if (index < 0) index += len;\n"
  cTypeBlocks.add "  if (index < 0 || index >= len) { PyErr_SetString(PyExc_IndexError, \"index out of range\"); return -1; }\n"
  cTypeBlocks.add &"  if (value == NULL) {{ {procPrefix}_delete({refExpr}, (long long)index); return 0; }}\n"
  cTypeBlocks.add &"  {cType(entryType)} converted;\n"
  cTypeBlocks.add convertPyToCInt("value", "converted", entryType, "value")
  cTypeBlocks.add &"  {procPrefix}_set({refExpr}, (long long)index, converted);\n"
  cTypeBlocks.add "  return 0;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static PyObject *{typePrefix}_append(PyObject *self, PyObject *value) {{\n"
  cTypeBlocks.add &"  {cType(entryType)} converted;\n"
  cTypeBlocks.add convertPyToC("value", "converted", entryType, "value")
  cTypeBlocks.add &"  {procPrefix}_add({refExpr}, converted);\n"
  cTypeBlocks.add "  Py_RETURN_NONE;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static PyObject *{typePrefix}_clear(PyObject *self, PyObject *Py_UNUSED(ignored)) {{\n"
  cTypeBlocks.add &"  {procPrefix}_clear({refExpr});\n"
  cTypeBlocks.add "  Py_RETURN_NONE;\n"
  cTypeBlocks.add "}\n\n"
  cTypeBlocks.add &"static PySequenceMethods {typePrefix}_sequence = {{\n"
  cTypeBlocks.add &"  .sq_length = {typePrefix}_len,\n"
  cTypeBlocks.add &"  .sq_item = {typePrefix}_item,\n"
  cTypeBlocks.add &"  .sq_ass_item = {typePrefix}_ass_item,\n"
  cTypeBlocks.add "};\n\n"

proc exportRefObjectPyNative*(
  sym: NimNode,
  fields: seq[(string, NimNode)],
  constructor: NimNode
) =
  let objName = sym.nativeName()
  refObjectNames.incl(objName)
  emitRefLikeType(objName, constructor)

  var getsetForwardDecls = ""
  for (fieldName, fieldType) in fields:
    let
      fieldSnake = toSnakeCase(fieldName)
      objSnake = toSnakeCase(objName)
      pyStruct = pyStructName(objName)

    if fieldType.isSeqType:
      let
        entryType = fieldType[1]
        helperName = objName & capitalizeAscii(fieldName)
        helperStruct = pyStructName(helperName)
        helperType = typeObjName(helperName)
        procPrefix = "$lib_" & objSnake & "_" & fieldSnake
        getterName = &"GennyPy_{cIdent(objName)}_get_{fieldSnake}"

      getsetForwardDecls.add &"static PyObject *{getterName}({pyStruct} *self, void *closure);\n"
      cForwardDecls.add &"static PyTypeObject {helperType};\n"
      cTypeBlocks.add &"typedef struct {{ PyObject_HEAD PyObject *parent; PyObject *dict; }} {helperStruct};\n\n"
      cTypeBlocks.add &"static void GennyPy_{cIdent(helperName)}_dealloc({helperStruct} *self) {{ Py_XDECREF(self->parent); Py_XDECREF(self->dict); Py_TYPE(self)->tp_free((PyObject *)self); }}\n\n"
      cTypeBlocks.add &"static PyObject *GennyPy_{cIdent(helperName)}_from_parent(PyObject *parent) {{\n"
      cTypeBlocks.add &"  {helperStruct} *self = PyObject_New({helperStruct}, &{helperType});\n"
      cTypeBlocks.add "  if (self == NULL) return NULL;\n"
      cTypeBlocks.add "  Py_INCREF(parent);\n"
      cTypeBlocks.add "  self->parent = parent;\n"
      cTypeBlocks.add "  self->dict = NULL;\n"
      cTypeBlocks.add "  return (PyObject *)self;\n"
      cTypeBlocks.add "}\n\n"
      emitSeqMethods(helperName, procPrefix, &"(({pyStruct} *)(({helperStruct} *)self)->parent)->ref", "GennyPy_" & cIdent(helperName), entryType, objName)
      cTypeBlocks.add &"static PyMethodDef GennyPy_{cIdent(helperName)}_methods[] = {{\n"
      cTypeBlocks.add &"  {{{cString(\"append\")}, (PyCFunction)GennyPy_{cIdent(helperName)}_append, METH_O, NULL}},\n"
      cTypeBlocks.add &"  {{{cString(\"add\")}, (PyCFunction)GennyPy_{cIdent(helperName)}_append, METH_O, NULL}},\n"
      cTypeBlocks.add &"  {{{cString(\"clear\")}, (PyCFunction)GennyPy_{cIdent(helperName)}_clear, METH_NOARGS, NULL}},\n"
      cTypeBlocks.add "  {NULL}\n};\n\n"
      cTypeBlocks.add &"static PyTypeObject {helperType} = {{\n"
      cTypeBlocks.add "  PyVarObject_HEAD_INIT(NULL, 0)\n"
      cTypeBlocks.add &"  .tp_name = {cString(\"$lib.\" & helperName)},\n"
      cTypeBlocks.add &"  .tp_basicsize = sizeof({helperStruct}),\n"
      cTypeBlocks.add &"  .tp_dealloc = (destructor)GennyPy_{cIdent(helperName)}_dealloc,\n"
      cTypeBlocks.add "  .tp_flags = Py_TPFLAGS_DEFAULT,\n"
      cTypeBlocks.add &"  .tp_dictoffset = offsetof({helperStruct}, dict),\n"
      cTypeBlocks.add &"  .tp_as_sequence = &GennyPy_{cIdent(helperName)}_sequence,\n"
      cTypeBlocks.add &"  .tp_methods = GennyPy_{cIdent(helperName)}_methods,\n"
      cTypeBlocks.add "};\n\n"
      cTypeBlocks.add &"static PyObject *{getterName}({pyStruct} *self, void *closure) {{ return GennyPy_{cIdent(helperName)}_from_parent((PyObject *)self); }}\n\n"
      cModuleInit.add &"  if (PyType_Ready(&{helperType}) < 0) return NULL;\n"
      cModuleInit.add &"  Py_INCREF(&{helperType});\n"
    else:
      let
        getterApi = "$lib_" & objSnake & "_get_" & fieldSnake
        setterApi = "$lib_" & objSnake & "_set_" & fieldSnake
        getterName = &"GennyPy_{cIdent(objName)}_get_{fieldSnake}"
        setterName = &"GennyPy_{cIdent(objName)}_set_{fieldSnake}"
      addProto(getterApi, @[(objSnake, sym)], fieldType)
      addProto(setterApi, @[(objSnake, sym), ("value", fieldType)], newEmptyNode())
      getsetForwardDecls.add &"static PyObject *{getterName}({pyStruct} *self, void *closure);\n"
      getsetForwardDecls.add &"static int {setterName}({pyStruct} *self, PyObject *value, void *closure);\n"
      cTypeBlocks.add &"static PyObject *{getterName}({pyStruct} *self, void *closure) {{\n"
      cTypeBlocks.add &"  {cReturnType(fieldType)} value = {getterApi}(self->ref);\n"
      cTypeBlocks.add &"  return {pyFromC(\"value\", fieldType)};\n"
      cTypeBlocks.add "}\n\n"
      cTypeBlocks.add &"static int {setterName}({pyStruct} *self, PyObject *value, void *closure) {{\n"
      cTypeBlocks.add "  if (value == NULL) { PyErr_SetString(PyExc_TypeError, \"cannot delete field\"); return -1; }\n"
      cTypeBlocks.add &"  {cType(fieldType)} converted;\n"
      cTypeBlocks.add convertPyToCInt("value", "converted", fieldType, fieldSnake)
      cTypeBlocks.add &"  {setterApi}(self->ref, converted);\n"
      cTypeBlocks.add "  return 0;\n"
      cTypeBlocks.add "}\n\n"

  var getsetName = &"GennyPy_{cIdent(objName)}_getset"
  let marker = &"static PyGetSetDef {getsetName}[] = {{\n"
  var replacement = getsetForwardDecls & marker
  for (fieldName, fieldType) in fields:
    let fieldSnake = toSnakeCase(fieldName)
    let setter =
      if fieldType.isSeqType: "NULL"
      else: "(setter)GennyPy_" & cIdent(objName) & "_set_" & fieldSnake
    replacement.add &"  {{{cString(fieldSnake)}, (getter)GennyPy_{cIdent(objName)}_get_{fieldSnake}, {setter}, NULL, NULL}},\n"
  cTypeBlocks = cTypeBlocks.replace(marker, replacement)

proc exportSeqPyNative*(sym: NimNode) =
  let
    seqName = sym.getName()
    entryType = sym[1]
  seqObjectNames.incl(seqName)
  seqEntryTypes[seqName] = entryType
  seqNewProcs[seqName] = "$lib_new_" & toSnakeCase(seqName)
  emitRefLikeType(seqName, nil, true, entryType)

proc exportConstPyNative*(sym: NimNode) =
  let
    name = toCapSnakeCase(sym.repr)
    value = sym.getImpl()[2].repr
    cValue =
      if value == "true": "1"
      elif value == "false": "0"
      else: value
  cTypes.add &"#define {name} {cValue}\n"
  if value.contains(".") or value.contains("e") or value.contains("E"):
    cModuleInit.add &"  if (PyModule_AddObject(m, {cString(name)}, PyFloat_FromDouble((double)({value}))) < 0) return NULL;\n"
  elif value == "true" or value == "false":
    let boolValue = if value == "true": "1" else: "0"
    cModuleInit.add &"  if (PyModule_AddIntConstant(m, {cString(name)}, {boolValue}) < 0) return NULL;\n"
  elif value.startsWith("\""):
    cModuleInit.add &"  if (PyModule_AddObject(m, {cString(name)}, PyUnicode_FromString({value})) < 0) return NULL;\n"
  else:
    cModuleInit.add &"  if (PyModule_AddObject(m, {cString(name)}, PyLong_FromLongLong((long long)({value}))) < 0) return NULL;\n"

proc exportEnumPyNative*(sym: NimNode) =
  enumTypeNames.incl(sym.repr)
  cModuleInit.add &"  Py_INCREF(&PyLong_Type);\n"
  cModuleInit.add &"  if (PyModule_AddObject(m, {cString(sym.repr)}, (PyObject *)&PyLong_Type) < 0) return NULL;\n"
  for i, entry in sym.getImpl()[2][1 .. ^1]:
    let name = toCapSnakeCase(entry.repr)
    cTypes.add &"#define {name} {i}\n"
    cModuleInit.add &"  if (PyModule_AddIntConstant(m, {cString(name)}, {i}) < 0) return NULL;\n"

proc pythonExeFromDefines(): string =
  let env = getEnv("GENNY_PYTHON")
  if env.len > 0:
    return env
  for token in querySetting(commandLine).splitWhitespace():
    for prefix in ["-d:gennyPythonExe=", "--define:gennyPythonExe:"]:
      if token.startsWith(prefix):
        return token[prefix.len .. ^1]
  "python"

proc pyConfig(): Table[string, string] =
  let exe = pythonExeFromDefines()
  let script = "import sysconfig, importlib.machinery;" &
    "keys=['EXT_SUFFIX','INCLUDEPY','LIBDIR','VERSION'];" &
    "print('\\n'.join(str(sysconfig.get_config_var(k) or '') for k in keys))"
  let outp = staticExec(quoteShell(exe) & " -c " & quoteShell(script)).splitLines()
  if outp.len < 4 or outp[0].len == 0 or outp[1].len == 0:
    error("Unable to discover Python build settings. Set GENNY_PYTHON to the Python executable.")
  result["EXT_SUFFIX"] = outp[0]
  result["INCLUDEPY"] = outp[1]
  result["LIBDIR"] = outp[2]
  result["VERSION"] = outp[3]

proc toUnixPath(s: string): string =
  s.replace("\\", "/")

proc writePyNative*(dir, lib: string): NimNode =
  createDir(dir)
  let cfg = pyConfig()
  let cPath = (dir / (toSnakeCase(lib) & "_native.c")).toUnixPath
  var finalTypeBlocks = cTypeBlocks
  for typeName, entries in typeMethods:
    finalTypeBlocks = finalTypeBlocks.replace(
      &"/* GENNY_METHODS_{cIdent(typeName)} */\n",
      entries
    )

  var code = ""
  code.add "#define PY_SSIZE_T_CLEAN\n"
  code.add "#include <Python.h>\n"
  code.add "#include <stdint.h>\n"
  code.add "#include <stdarg.h>\n"
  code.add "#include <stddef.h>\n"
  code.add "#include <string.h>\n\n"
  code.add "extern void NimMain(void);\n"
  code.add "static PyObject *GennyPy_ModuleError = NULL;\n"
  code.add "static int genny_nim_ready = 0;\n"
  code.add "static void genny_ensure_nim(void) {\n"
  code.add "#ifndef _WIN32\n"
  code.add "  if (!genny_nim_ready) { NimMain(); genny_nim_ready = 1; }\n"
  code.add "#else\n"
  code.add "  genny_nim_ready = 1;\n"
  code.add "#endif\n"
  code.add "}\n\n"
  code.add "static int genny_parse_args(const char *func, PyObject *args, PyObject *kwargs, Py_ssize_t nparams, const char **names, Py_ssize_t required, ...) {\n"
  code.add "  Py_ssize_t nargs = PyTuple_GET_SIZE(args);\n"
  code.add "  if (nargs > nparams) { PyErr_Format(PyExc_TypeError, \"%s expected at most %zd arguments, got %zd\", func, nparams, nargs); return 0; }\n"
  code.add "  va_list ap;\n"
  code.add "  va_start(ap, required);\n"
  code.add "  for (Py_ssize_t i = 0; i < nparams; ++i) {\n"
  code.add "    PyObject **slot = va_arg(ap, PyObject **);\n"
  code.add "    PyObject *kw = (kwargs && names) ? PyDict_GetItemString(kwargs, names[i]) : NULL;\n"
  code.add "    if (i < nargs && kw != NULL) { va_end(ap); PyErr_Format(PyExc_TypeError, \"%s got multiple values for argument '%s'\", func, names[i]); return 0; }\n"
  code.add "    *slot = (i < nargs) ? PyTuple_GET_ITEM(args, i) : kw;\n"
  code.add "    if (*slot == NULL && i < required) { va_end(ap); PyErr_Format(PyExc_TypeError, \"%s missing required argument '%s'\", func, names[i]); return 0; }\n"
  code.add "  }\n"
  code.add "  va_end(ap);\n"
  code.add "  if (kwargs && names) {\n"
  code.add "    PyObject *key; PyObject *value; Py_ssize_t pos = 0;\n"
  code.add "    while (PyDict_Next(kwargs, &pos, &key, &value)) {\n"
  code.add "      const char *k = PyUnicode_AsUTF8(key);\n"
  code.add "      if (k == NULL) return 0;\n"
  code.add "      int found = 0;\n"
  code.add "      for (Py_ssize_t i = 0; i < nparams; ++i) if (strcmp(k, names[i]) == 0) { found = 1; break; }\n"
  code.add "      if (!found) { PyErr_Format(PyExc_TypeError, \"%s got an unexpected keyword argument '%s'\", func, k); return 0; }\n"
  code.add "    }\n"
  code.add "  }\n"
  code.add "  return 1;\n"
  code.add "}\n\n"
  code.add "extern char *$lib_genny_buffer_data(void *buffer);\n"
  code.add "extern long long $lib_genny_buffer_len(void *buffer);\n"
  code.add "extern void $lib_genny_buffer_unref(void *buffer);\n\n"
  code.add "static PyObject *genny_buffer_to_py(void *buffer) {\n"
  code.add "  if (buffer == NULL) return PyUnicode_FromString(\"\");\n"
  code.add "  PyObject *result = NULL;\n"
  code.add "  long long len = $lib_genny_buffer_len(buffer);\n"
  code.add "  char *data = $lib_genny_buffer_data(buffer);\n"
  code.add "  if (data == NULL || len <= 0) result = PyUnicode_FromString(\"\");\n"
  code.add "  else result = PyUnicode_FromStringAndSize(data, (Py_ssize_t)len);\n"
  code.add "  $lib_genny_buffer_unref(buffer);\n"
  code.add "  return result;\n"
  code.add "}\n\n"
  code.add "static void genny_set_error_from_buffer(void *buffer) {\n"
  code.add "  PyObject *message = genny_buffer_to_py(buffer);\n"
  code.add "  if (message != NULL) {\n"
  code.add "    PyErr_SetObject(GennyPy_ModuleError, message);\n"
  code.add "    Py_DECREF(message);\n"
  code.add "  } else {\n"
  code.add "    PyErr_SetString(GennyPy_ModuleError, \"Nim exception\");\n"
  code.add "  }\n"
  code.add "}\n\n"
  if needsErrorBridge:
    code.add "extern char $lib_check_error(void);\n"
    code.add "extern void *$lib_take_error(void);\n"
    code.add "static char (*$lib_native_check_error)(void) = $lib_check_error;\n"
    code.add "static void *(*$lib_native_take_error)(void) = $lib_take_error;\n\n"
  code.add cTypes
  code.add "\n"
  code.add cForwardDecls
  code.add "\n"
  code.add cProtos
  code.add "\n"
  code.add finalTypeBlocks
  code.add "\n"
  code.add cWrappers
  code.add "static PyMethodDef GennyPy_ModuleMethods[] = {\n"
  code.add cModuleMethods
  code.add "  {NULL, NULL, 0, NULL}\n};\n\n"
  code.add "static struct PyModuleDef GennyPy_Module = {\n"
  code.add "  PyModuleDef_HEAD_INIT,\n"
  code.add &"  {cString(toSnakeCase(lib))},\n"
  code.add "  NULL,\n"
  code.add "  -1,\n"
  code.add "  GennyPy_ModuleMethods\n"
  code.add "};\n\n"
  code.add "PyMODINIT_FUNC PyInit_$lib(void) {\n"
  code.add "  genny_ensure_nim();\n"
  code.add "  PyObject *m = PyModule_Create(&GennyPy_Module);\n"
  code.add "  if (m == NULL) return NULL;\n"
  code.add &"  GennyPy_ModuleError = PyErr_NewException({cString(toSnakeCase(lib) & \".\" & lib & \"Error\")}, NULL, NULL);\n"
  code.add "  if (GennyPy_ModuleError == NULL) return NULL;\n"
  code.add "  Py_INCREF(GennyPy_ModuleError);\n"
  code.add &"  if (PyModule_AddObject(m, {cString(lib & \"Error\")}, GennyPy_ModuleError) < 0) return NULL;\n"
  code.add cModuleInit
  code.add "  return m;\n"
  code.add "}\n"

  code = code.replace("$lib", toSnakeCase(lib)).replace("$Lib", lib)
  writeFile(cPath, code)

  result = newStmtList()
  let includeOpt = "-I" & cfg["INCLUDEPY"].toUnixPath
  result.add quote do:
    {.passC: `includeOpt`.}
  when defined(windows):
    let libDirOpt = "-L" & cfg["LIBDIR"].toUnixPath
    let pyLibOpt = "-lpython" & cfg["VERSION"]
    let staticLibGccOpt = "-static-libgcc"
    result.add quote do:
      {.passL: `libDirOpt`.}
      {.passL: `pyLibOpt`.}
      {.passL: `staticLibGccOpt`.}
  elif defined(macosx):
    let dynLookup = "-undefined dynamic_lookup"
    result.add quote do:
      {.passL: `dynLookup`.}
  let compilePath = cPath
  result.add quote do:
    {.compile: `compilePath`.}
