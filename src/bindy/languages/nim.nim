import bindy/common, macros, strformat, strutils

proc exportTypeNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr != "seq":
      error(&"Unexpected bracket expression {sym[0].repr}[", sym)
    result = sym.getSeqName()
  else:
    if sym.repr == "string":
      result = "cstring"
    elif sym.repr == "Rune":
      result = "int32"
    elif sym.repr.startsWith("Some"):
      result = sym.repr.replace("Some", "")
    else:
      result = sym.repr

proc convertExportFromNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    discard
  else:
    if sym.repr == "string":
      result = ".cstring"
    elif sym.repr == "Rune":
      result = ".int32"

proc convertImportToNim*(sym: NimNode): string =
  if sym.kind == nnkBracketExpr:
    if sym[0].repr != "seq":
      error(&"Unexpected bracket expression {sym[0].repr}[", sym)
    result = ".s"
  else:
    if sym.repr == "string":
      result = ".`$`"
    elif sym.repr == "Rune":
      result = ".Rune"
