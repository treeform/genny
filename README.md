# Bindy - Generate Nim library bindings for many languages

So you made a cool Nim library but you want it to be available to other languages as well. With `bindy` you can generate a dynamically linked library with a simple C API and generated bindings for many languages.

![Github Actions](https://github.com/treeform/bindy/workflows/Github%20Actions/badge.svg)

## Supported features and languages:

Language      | Method        | Enums  | Objects | Ref Objects | Seqs   |
------------- | ------------- | ------ | ------- | ----------- | ------ |
Nim           | {.importc.}   | ✅     | ✅     | ✅          | ✅    |
Python        | ctypes        | ✅     | ✅     | ✅          | ✅    |

## Why add Nim support?

"Can't you just import your cool library in Nim?" We though it was important to test the library in a what we call Nim-C-Nim sandwich. It makes sure everyone uses your library API the same way. This also means you can ship huge Nim library DLLs and use them in your Nim programs without recompiling everything every time.
