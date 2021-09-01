# Genny - Generate Nim library bindings for many languages

So you made a cool Nim library but you want it to be available to other languages as well. With `genny` you can generate a dynamically linked library with a simple C API and generated bindings for many languages.

![Github Actions](https://github.com/treeform/genny/workflows/Github%20Actions/badge.svg)

## Supported features and languages:

Language      | Method        | Enums  | Objects | Ref Objects | Seqs   |
------------- | ------------- | ------ | ------- | ----------- | ------ |
Nim           | {.importc.}   | ✅     | ✅     | ✅          | ✅    |
Python        | ctypes        | ✅     | ✅     | ✅          | ✅    |

## Genny is experimental and opinionated

Genny generates a dynamic library C API for your Nim library and generates bindings for that dynamic library in many languages. To do this, things like proc overloads, complex types, sequences, and many other Nim features need to be addressed to make them work over a C interface.

To make that C interface, Genny makes assumptions about what your Nim source looks like and how to give overloaded procedures unique names. This may not work out of the box for every Nim library yet!

## Example uses

This version of Genny was created to generate bindings for [Pixie](https://github.com/treeform/pixie). You can see how Pixie's dynamic library API is exported and the bindings generated [in this file](https://github.com/treeform/pixie/blob/master/bindings/bindings.nim).

## Why add Nim binding support for a Nim library?

"Can't you just import your cool library in Nim?" We though it was important to test the library in a what we call Nim-C-Nim sandwich. It makes sure everyone uses your library API the same way. This also means you could ship huge Nim libraries as DLLs and use them in your Nim programs without recompiling everything every time.
