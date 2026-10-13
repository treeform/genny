<img src="docs/gennyBanner.png">

# Genny - Generate Nim library bindings for many languages

So you made a cool Nim library but you want it to be available to other languages as well. With `genny` you can generate a dynamically linked library with a simple C API and generated bindings for many languages. In some ways its similar to [SWIG](http://www.swig.org/) project for C or [djinni](https://github.com/dropbox/djinni) for C++.


`nimble install genny`

![Github Actions](https://github.com/treeform/genny/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/genny)

This library has no dependencies other than the Nim standard library.


See [Pixie's nimble file](https://github.com/treeform/pixie/blob/master/pixie.nimble#L16) for an example of how to compile bindings with `genny`.

## Supported features and languages:

Language      | Method        | Enums  | Objects | Ref Objects | Seqs   | GC |
------------- | ------------- | ------ | ------- | ----------- | ------ | -- |
Nim           | {.importc.}   | ✅     | ✅     | ✅          | ✅    | ✅ |
Python        | ctypes        | ✅     | ✅     | ✅          | ✅    | ✅ |
Node.js       | ffi-napi      | ✅     | ✅     | ✅          | ✅    | no |
C             | .h            | ✅     | ✅     | ✅          | ✅    | no |
Java          | JNI           | ✅     | ✅     | ✅          | ✅    | ✅ |

## Java

Build the library with `JAVA_HOME` pointing at a JDK (9 or newer):

```sh
nim c --mm:arc --app:lib -d:gennyJava -d:noSignalHandler -o:libpixie.so bindings.nim
javac -d classes bindings/generated/java/genny/*.java
```

`-d:noSignalHandler` is required: the JVM uses `SIGSEGV` internally. The package defaults to `genny`; change it with `-d:gennyJavaPackage=com.example.pixie`. Load the library once with `Pixie.load("/absolute/path/libpixie.so")`.

* Ref objects and seqs are `AutoCloseable`. `close()` releases the Nim object right away; otherwise a `Cleaner` queues the release and it runs at the start of the next call into the library (or `Pixie.releasePending()`).
* Nim's reference counts and the error state of raising procs are not thread-safe: call the library from one thread at a time.
* Unsigned integers keep their bits in the signed Java type of the same size; Nim `int` is a Java `long`.
* Strings are converted to and from UTF-8. A string containing `\0` is cut there, like in the C API.
* `pointer` parameters take direct `ByteBuffer`s (or `null`); Nim gets the buffer's base address in native byte order and must not keep it after the call. Heap buffers throw `IllegalArgumentException`.
* Value objects are copied in and out as C structs. Objects over 24 bytes must be `{.bycopy.}`; inherited, packed and variant objects are skipped with a warning.
* Overloads that end up with the same Java signature get the overload prefix appended, e.g. `scaledInt64`.
* Like the other backends, a ref object built by its exported constructor keeps one extra Nim reference and is never freed.

### Hot reload (development)

The JVM cannot unload a JNI library. For development, build the generated C on its own as a small loader with `-DGENNY_JAVA_HOT_RELOAD`; Java loads the loader once and it `dlopen`s the real Nim library, so the Nim code can be rebuilt and swapped while the JVM keeps running. It uses `dlopen`, so it is not available on Windows:

```sh
nim c --mm:arc --app:lib -d:gennyJava -d:noSignalHandler -o:build/libpixie-1.so bindings.nim
cc -shared -fPIC -DGENNY_JAVA_HOT_RELOAD -I$JAVA_HOME/include -I$JAVA_HOME/include/linux \
  bindings/generated/pixie_jni.c -ldl -o libpixie_loader.so
```

The generated class provides `prepareReload(path)`, `activateReload()`,
`rollbackReload()`, `commitReload()` and `cancelReload()`. Preparation checks
every symbol and the generated ABI fingerprint without changing the active
table. Activation retains the previous table and library handle; commit
unloads the previous library, and rollback restores it after the failed
candidate has been disposed. The caller must quiesce all native calls and
stop every native thread before retiring a generation. Run untrusted candidate
initialization in a separate process before calling prepare.

`ABI_FINGERPRINT` covers exported signatures, value layouts, ref-object
accessors, enums, constants and the error protocol. Incompatible API changes
are rejected and need new Java bindings. Every activation and rollback
advances the Java handle generation; rollback never revives old handles.
Live and queued native references are released before changing generations.
Nim string results remain owned by a thread-local holder until JNI finishes
copying them, then JNI releases the holder. This includes error messages and
string getters; returned pointers never outlive their Nim storage.
`reload(path)` remains a convenience prepare/activate/commit sequence for
applications that have already stopped their native runtime.

```java
Pixie.load("/abs/libpixie_loader.so");
Pixie.reload("/abs/build/libpixie-1.so"); // and again after every rebuild
```

* Every call throws `IllegalStateException` until the first successful `reload`. `Pixie.hotReloadable()` tells a loader from a normal build, where `reload` throws `UnsupportedOperationException`.
* A reload that cannot open the library or finds a missing export throws `IllegalStateException` and keeps the current library.
* Each activation and rollback starts a new generation. Ref objects and seqs from an older generation throw `IllegalStateException` when used. Their references are released before switching; closing or collecting stale handles does nothing.
* Copy each build to a new path before reloading: `dlopen` hands back the already loaded library for the same file.
* Stop every thread that runs Nim code, and every call into the library, before reloading: the old library is unloaded.
* The exported API must stay the same between reloads; regenerate and rebuild the loader (and restart the JVM) when it changes.

## Quest for "nice" language binding.

It would be pretty easy to just export a C API from Nim and have users call the ugly C style methods but that is not our goal with Genny. Instead, we try to generate a "nice" API for each language that feels like it was custom-made. This means, where possible, we:

* Use naming conventions that are familiar in the language (CamelCase, Snake_Case or Kebab-Case).
* Make sure regular `object`s are passed by value and behave simply.
* Make `ref object`s behave like OOP objects with members, methods and constructors.
* Generate helper methods like `==` or `isNull`.
* Export `seq[X]` as something that feels like a native array.
* Export `seq[X]` on a `ref object` behaves like what we call a bound-seq.
* Support the `[]` syntax.
* Support the `.` member syntax.
* Overload math operators `+`, `-`, `*`, `/`.
* Overload `proc`s, where we first unpack them to different C calls with unique prefixes and then repack them back into overloaded methods or functions.
* Pass optional arguments.
* Pass enums and constants.
* Synchronize the binding language's GC and Nim's ARC GC.
* And even copy the comments so that automated tools can use them.

## A bindings interface DSL

Genny provides a DSL that you can use to define how things need to be exported. The DSL is pretty simple to follow:

```nim
import genny, pixie

exportConsts:
  defaultMiterLimit
  autoLineHeight

exportEnums:
  FileFormat
  BlendMode

exportProcs:
  readImage
  readmask
  readTypeface

exportObject Matrix3:
  constructor:
    matrix3
  procs:
    mul(Matrix3, Matrix3)

exportRefObject Mask:
  fields:
    width
    height
  constructor:
    newMask(int, int)
  procs:
    writeFile(Mask, string)
    copy(Mask)
    getValue
    setValue

# Must have this at the end.
writeFiles("bindings/generated", "pixie")
include generated/internal
```

See more in the [pixie bindings](https://github.com/treeform/pixie/blob/master/bindings/bindings.nim)

## Genny is experimental and opinionated

Genny generates a dynamic library C API for your Nim library and generates bindings for that dynamic library in many languages. To do this, things like proc overloads, complex types, sequences, and many other Nim features need to be addressed to make them work over a C interface.

To make that C interface, Genny makes assumptions about what your Nim source looks like and how to give overloaded procedures unique names. This may not work out of the box for every Nim library yet!

## Example uses

This version of Genny was created to generate bindings for [Pixie](https://github.com/treeform/pixie). You can see how Pixie's dynamic library API is exported and the bindings generated [in this file](https://github.com/treeform/pixie/blob/master/bindings/bindings.nim) and the [results here](https://github.com/treeform/pixie-python).

## Nim is great, why other languages?

Nim is a niche language. We believe we can broaden Nim's appeal by creating Nim libraries for other more popular language and have Nim slowly work its way into companies. Maybe after companies see that they already use Nim, they will start writing their own code in it.

## Why add Nim binding support for a Nim library?

"Can't you just import your cool library in Nim?" We thought it was important to test the library in a what we call Nim-C-Nim sandwich. It makes sure everyone uses your library API the same way. This also means you could ship huge Nim libraries as DLLs and use them in your Nim programs without recompiling everything every time.
