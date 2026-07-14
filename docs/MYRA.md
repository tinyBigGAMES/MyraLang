<div align="center">

![Myra](../media/logo.jpg)

</div>

<a id="what-is-myra"></a>

## 🚀 What is Myra?

**Myra** is a minimal, statically typed systems language in the Pascal/Oberon tradition that compiles to modern **C++23**. You write Myra; the compiler analyzes it, emits clean C++23, and a bundled zig/clang toolchain builds it into a native binary.

Its defining idea is a **small language with an open floor.** Myra knows only the constructs it needs. Anything it does not recognize is not an error, it is C++, and it passes straight through.

Write a source file. Run the compiler. Get a native binary.

```myra
module exe hello;

#include <cstdio>

begin
  println("Hello from Myra!");
  printf("C++ passthrough: 2 + 3 = %d\n", 2 + 3);
end.
```

```
> Myra -s hello.myra -r
Hello from Myra!
C++ passthrough: 2 + 3 = 5
```

Two builtins and a C function, side by side, with no binding layer between them. `println` is Myra and takes `{}` placeholders. `printf` is the real C `printf` and takes `%d`. Neither one had to be declared.

> [!TIP]
> 💡 **Fast path:** read [Getting Started](#getting-started), skim the [Language Reference](#language-reference), then read the [Langdef System](#langdef-system) to see how the compiler itself is defined in plain text you can edit.

### 🚦 Documentation Roadmap

Nine sections, in the order they appear below.

| # | Reader Goal | Section | What is in it |
|---|-------------|---------|---------------|
| 1 | 🚀 Run your first program | [Getting Started](#getting-started) | Install, your first `.myra` file, the CLI, module kinds, the six targets, the standard library, project layout |
| 2 | 📘 Learn the language | [Language Reference](#language-reference) | Types, records, objects, control flow, exceptions, modules, C++ interop |
| 3 | 🎛️ Configure the build | [Build Directives](#build-directives) | Every `@` directive: targets, optimization, paths, link libraries, version info, conditionals |
| 4 | 🧾 Verify exact syntax | [BNF Grammar](#myra-language-grammar) | Formal EBNF grammar, binding powers, and lexical rules |
| 5 | 🧬 Hack the compiler | [Langdef System](#langdef-system) | The `.mld` files: tokens, types, grammar, semantics, emitters, and all the builtins |
| 6 | 🛠️ Use the toolchain | [Tools](#tools) | Compiler CLI, DAP debugger, LSP language server |
| 7 | 🔌 Embed Myra | [API Reference](#api-reference) | Consuming a compiled Myra `lib` / `dll` from a host |
| 8 | 🧪 Solve a task | [How-To Guide](#how-to-guide) | Practical recipes, each one complete and runnable |
| 9 | 🤝 Contribute | [Contributing](#contributing) | How to get involved |

### 💡 Core Idea

Myra is designed around one direct workflow:

```text
write .myra  ->  compile  ->  C++23  ->  native executable
```

The language the compiler knows is deliberately small: modules, routines, the data and control constructs, objects, and exceptions. Everything else is C++, reachable without ceremony. And the compiler itself is not a black box, it is defined by `.mld` files that ship as readable text beside the binary.

> [!IMPORTANT]
> 🧱 Myra is statically typed and case-sensitive. Every value has a known type at compile time, and `:` introduces a type annotation, as in `n : int32`. All keywords are lowercase. Strings use double quotes. There is no dynamic typing and no runtime type tags in user code.

### 🏛️ The Three Pillars

| Pillar | What It Means |
|--------|---------------|
| **1. Minimal systems language** | Oberon-inspired. Only essential constructs. The language does not grow to swallow every idea, it stays small enough to hold in your head. |
| **2. Seamless C++ passthrough** | Unrecognized tokens pass through verbatim to C++. No escape-hatch syntax, no `extern` blocks, no FFI ceremony. Interop is the absence of a wall, not a door in it. |
| **3. Hackable compiler** | The `.mld` language definition files ship as human-readable text alongside the compiler. The grammar, the type system, and the emitters are all editable. The compiler is not sealed. |

### ✨ Key Features

| Feature | What It Means |
|---------|---------------|
| **🪶 Minimal by design** | A small, Pascal/Oberon-shaped core. `module`, `routine`, `object`, `guard`. No feature sprawl. |
| **🌉 C++ interop is the default** | Raw `#include`, calling `printf` and any C/C++ API directly. `cpplink` is the default linkage; `clink` opts in to C linkage for an unmangled, C-callable name. |
| **⚙️ Compiles to C++23** | Myra emits readable, modern C++23 and builds it with a bundled zig/clang toolchain into a native binary. |
| **🧠 Static typing** | Full-width numeric types (`int8`..`int64`, `uint8`..`uint64`, `float32`, `float64`) for clean C interop. No implicit width games. |
| **📦 Modules** | `exe`, `dll`, and `lib` output kinds, with `import` and `exported` declarations. Imported names stay qualified. |
| **🧱 Rich type system** | Records (inheritance, packed layout, alignment, bitfields), objects (methods, `self` / `parent`), overlays (unions), choices (enumerations), sets, arrays, pointers, and routine types. |
| **🛡️ Structured exceptions** | `guard` / `except` / `finally`, with `raiseexception` and the `getexception*` inspection intrinsics. |
| **🎯 Six targets, one toolchain** | Windows, Linux, macOS, and WebAssembly, cross-compiled from a single bundled zig. |
| **🎛️ Build config lives in the source** | `@target`, `@optimize`, `@linklibrary` and the rest are directives in the file. A source file builds the same way no matter who invoked the compiler. |
| **📚 A standard library** | `Maths`, `StrUtils`, `Console`, `Convert`, `Paths`, `Files`, `DateTime`, `Geometry`, `Assertions`. Always on the module search path. |
| **🧪 Built-in unit testing** | `test` blocks and the full `testAssert*` family are part of the language, not a library. |
| **🔧 Hackable** | The `.mld` files define the compiler. Edit the grammar, edit the emitters, ship your own dialect. |
| **🧰 Zero external dependencies** | The compiler and the bundled zig/clang toolchain are all you need. Nothing else to install. |

### 🏗️ Architecture

```
Source (.myra)
    |
    v
+-------------------------------------------+
|  Myra Pipeline                            |
|                                           |
|  Lex --> Parse --> AST                    |
|              |                            |
|              v                            |
|  ResolveImports (module graph)            |
|              |                            |
|              v                            |
|  Semantics (types, scope, modules)        |
|              |                            |
|              v                            |
|  Emit (C++23)                             |
|              |                            |
|              v                            |
|  Build (zig cc)                           |
+-------------------------------------------+
    |
    v
Native executable
```

Every stage is driven by the `.mld` language-definition files: the tokens, the type system, the grammar, the semantic rules, and the C++23 emitters are all language definition rather than hand-coded compiler stages.

> [!NOTE]
> 🧩 `zig cc` is the sole external toolchain, and it is bundled. There is no separate compiler, linker, or runtime to install, and cross-compilation to every supported target works out of the box from any host.

### 🎯 Six Targets

Cross-**compiling** to any target works from the Windows host. Cross-**running** is a separate question, and the compiler is honest about it: when a target cannot be launched, `-r` warns and continues. It never fails the build.

| `@target` | Triple | `-r` on the Windows host |
|---|---|---|
| `win64` | `x86_64-windows-gnu` | ✅ Runs natively. |
| `linux64` | `x86_64-linux-gnu` | ✅ Runs through WSL. |
| `wasm32` | `wasm32-wasi` | ✅ Opens in your browser, no server needed. |
| `winarm64` | `aarch64-windows-gnu` | ⚠️ Builds. Warns instead of running. |
| `linuxarm64` | `aarch64-linux-gnu` | ⚠️ Builds. Warns instead of running. |
| `macos64` | `aarch64-macos-none` | ⚠️ Builds. Warns instead of running. Apple Silicon only, by design. |

The full table, the WebAssembly story, and the reason `-r` behaves this way are in [Targets, and What Can Actually Run](#targets-and-running).

> [!WARNING]
> ⚠️ `wasm32` builds with `-fno-exceptions`. C++ exceptions are not available on that toolchain, so **`guard` / `except` is a hard compile error on `wasm32`**. This is a property of the target, not a bug to route around.

### 🎯 Who Is This For?

- **Game and application developers** who want a small, fast, native language that sits directly on top of the C/C++ ecosystem without a binding layer. Myra's passthrough pairs naturally with engines and existing libraries.
- **Pascal, Oberon, and Delphi developers** who want a modern, minimal descendant of that lineage that compiles to native code and speaks C++ fluently.
- **C++ developers** who want a cleaner surface syntax that emits readable C++23 they can inspect, build, and integrate, with nothing hidden.
- **Language builders** who want a compiler they can actually open up. The `.mld` files are the language, and they are yours to change.


### 📌 Current Status

The pipeline runs end to end. Everything listed here is implemented, and every construct named below has a passing test behind it.

#### Language

| Area | Surface |
|---|---|
| **Data types** | `int8`..`int64`, `uint8`..`uint64`, `float32`, `float64`, `boolean`, `char`, `wchar`, `string`, `wstring`, `pointer` |
| **Type definitions** | Records (inheritance, packed layout, custom alignment, bitfields), objects (methods, inheritance, `self` / `parent`), overlays (unions), choices (enumerations), arrays, set types, pointer types, routine types |
| **Declarations** | `var`, `const`, `type`, `routine`, `object`, `import`, `exported`, and the `clink` / `cpplink` linkage specifiers |
| **Control flow** | `if` / `then` / `else`, `while` / `do`, `for` / `to` / `downto`, `repeat` / `until`, `match` / `of` (with range arms), `leave`, `skip`, `return` |
| **Exceptions** | `guard` / `except` / `finally`, `raiseexception`, `raiseexceptioncode`, `getexceptioncode`, `getexceptionmessage` |
| **Memory** | `create` / `destroy` for objects; `getmem` / `freemem` / `resizemem` for raw memory; `setlength` for dynamic arrays |
| **Intrinsics** | `len`, `size`, `utf8`, `paramcount`, `paramstr`, `print`, `println` |
| **Expressions** | Full operator set with defined binding powers, set literals `[a, b..c]`, `in`, `address of`, deref `^`, type casts, and `pointer to` casts |
| **Variadics** | `varargs.count` and `varargs.next(type)` |
| **Unit testing** | `test` blocks with `testAssert`, `testAssertTrue` / `False` / `Nil` / `NotNil`, `testFail`, and `testAssertEqualInt` / `UInt` / `Float` / `Str` / `Bool` / `Ptr` |
| **C++ interop** | Raw `#include`, direct calls into any C or C++ API, C++ types as Myra variables. No escape-hatch syntax |

#### Toolchain

| Area | Surface |
|---|---|
| **Compiler CLI** | `-s` source, `-o` output, `-r` run, `-d` debug, `-h` help. See [The Compiler CLI](#compiler-cli) |
| **Build directives** | Targets, optimization, subsystem, search paths, link libraries, DLL copying, version info, icons, and `@ifdef` conditionals. See [Build Directives](#build-directives) |
| **Targets** | All six, cross-compiled from one bundled zig. See [Six Targets](#targets-and-running) |
| **Debugger** | A DAP server, with breakpoints carried in a `.mbp` sidecar. See [Tools](#tools) |
| **Language server** | An LSP server: hover, go to definition, find references, rename, document and workspace symbols, diagnostics, folding, semantic tokens, signature help, inlay hints, formatting, and code actions. See [Tools](#tools) |
| **Standard library** | Nine modules, always on the search path. See [The Standard Library](#standard-library) |

> [!TIP]
> 💡 The exact, verified surface syntax always lives in the [BNF Grammar](#myra-language-grammar). When the prose and the grammar ever seem to disagree, the grammar is authoritative.

### 💻 System Requirements

| Area | Requirement |
|------|-------------|
| **Operating system** | Windows x64 (the compiler host) |
| **Runtime dependencies** | None |
| **External toolchain** | None. zig / clang is bundled |
| **Running a `linux64` build** | WSL, only if you want `-r` to launch it |
| **Building the compiler from source** | Delphi 12 Athens or higher |

### 🗺️ Table of Contents

- 🚀 [Getting Started](#getting-started): install, [your first program](#first-program), [C++ passthrough](#cpp-passthrough), [the CLI](#compiler-cli), [module kinds](#module-kinds), [build configuration](#build-config), [targets](#targets-and-running), [the standard library](#standard-library), [project layout](#project-layout)
- 📘 [Language Reference](#language-reference): types and [composite types](#composite-types), `var` / `const` / `routine` / `object`, control flow, modules, exceptions, and C++ interop
- 🎛️ [Build Directives](#build-directives): [directive classes](#directive-classes), [build config](#directive-build-config), [search paths](#directive-paths), [version info](#directive-verinfo), [conditionals](#directive-conditional), [predefined symbols](#predefined-symbols), and [`@ifdef` vs `#if`](#ifdef-vs-if)
- 🧾 [BNF Grammar](#myra-language-grammar): formal EBNF grammar, binding powers, and lexical rules
- 🧬 [Langdef System](#langdef-system): the [`.mld` file structure](#mld-file-structure), [tokens](#mld-tokens), [types](#mld-types), [grammar](#mld-grammar), [semantics](#mld-semantics), [emitters](#mld-emitters), and [every builtin](#mld-builtins)
- 🛠️ [Tools](#tools): compiler CLI, DAP debugger, and LSP language server
- 🔌 [API Reference](#api-reference): consuming a compiled Myra `lib` / `dll` from a host
- 🧪 [How-To Guide](#how-to-guide): practical recipes for common tasks
- 🤝 [Contributing](#contributing): how to get involved

<a id="getting-started"></a>

## 🚀 Getting Started

Myra compiles to C++23 and builds the result with a bundled Zig/Clang toolchain. You write `.myra`, you get a native binary. There is no separate C++ compiler to install, no linker to configure, and no runtime to ship alongside your program.

This section takes you from an empty directory to a running executable, then to a shared library, a static library, and a WebAssembly build that opens in a browser.

### 📦 What Ships

Two executables ship in `bin`:

| Binary | Role |
|---|---|
| `Myra.exe` | The compiler. Lexes, parses, emits C++23, drives the toolchain, and can run or debug the result. |
| `MyraLSP.exe` | The language server. Speaks LSP over stdio. Editors launch it; you never run it by hand. |

Everything each one needs is resolved relative to the executable, under `bin/res`:

| Path | What lives there |
|---|---|
| `res/zig/` | The bundled Zig/Clang toolchain. This is the "no install" part. |
| `res/language/` | The `.mld` language definition. `myra.mld` is the root. |
| `res/libs/std/` | The standard library, as `.myra` source. |
| `res/runtime/` | `myr_runtime.h` / `myr_runtime.cpp`, linked into every build. |
| `res/wasm/` | The WASI shim and the HTML runner template used by `wasm32`. |

`bin/build.toml` points the compiler at that tree:

```toml
[build]
toolchain_path = "...\\repo\\bin\\res"
```

> [!NOTE]
> 🪟 The compiler is hosted on **Windows x64**. From that one host it cross-compiles to all six targets. Hosting is a separate question from targeting -- see [Targets](#targets-and-running) for what can actually be launched from the host and what cannot.

<a id="first-program"></a>

### ✍️ Your First Program

Create `hello.myra`:

```myra
module exe hello;

begin
  println("Hello from Myra!");
end.
```

Compile and run it in one step:

```
> Myra -s hello.myra -r
Hello from Myra!
```

That is the whole loop. Three things are worth naming in those five lines:

- **`module exe hello;`** declares both the kind of artifact (an executable) and its name. The binary is named after the module, so this produces `hello.exe`.
- **`begin ... end.`** is the module body -- the program's entry point. Note the terminating period. Every module ends with `end.`
- **`println`** is a builtin. Its format placeholder is `{}`, not `%d`:

```myra
println("sum = {}", sum);
```

`print` is the same thing without the trailing newline.

> [!TIP]
> 💡 The module name and the filename should match. It is a hard requirement for a `lib` you intend to `import`, because that is how the compiler finds the file on the module search path.

<a id="cpp-passthrough"></a>

### 🔗 C++ Passthrough, Immediately

Myra has no escape-hatch syntax for reaching C++. Anything the compiler does not recognize as Myra is emitted verbatim into the generated C++ and handed to the toolchain. That means the C and C++ worlds are available from line one:

```myra
module exe hello;

#include <cstdio>

begin
  println("Hello from Myra!");
  printf("C++ passthrough: 2 + 3 = %d\n", 2 + 3);
end.
```

`#include <cstdio>` is a C++ preprocessor line and passes straight through. `printf` is the real C `printf`, which is exactly why it takes `%d` and not `{}`.

The same applies to conditional compilation. Myra has **two** conditional systems and they are not the same mechanism:

| System | Resolved by | Reads |
|---|---|---|
| `@ifdef` / `@else` / `@endif` | The Myra lexer, **before** the compiler runs | Myra's own define table |
| `#if defined(...)` / `#elif` / `#endif` | The C++ preprocessor, **after** the compiler runs | The macros the toolchain defines for the selected target |

Symbols flow **one way**. Every Myra define is handed to the C++ compiler as a `-D` on the command line, so `@define FEATURE_A`, the built-in `MYRA`, and the live `TARGET_*` symbol are all visible to a later `#if defined(...)`. The reverse does not hold: `@ifdef` reads only Myra's own table, so the toolchain's platform macros (`_WIN32`, `__linux__`) are invisible to it. It is a one-way mirror, not two sealed rooms.

Platform detection therefore belongs to `#if`, because the toolchain is the thing that knows what it is building for. From `test_exe_target.myra`:

```myra
module exe test_exe_target;

@target "win64";

begin
@ifdef MYRA
  println("MYRA defined: yes");
@else
  println("MYRA defined: no");
@endif

#if defined(_WIN32)
  println("_WIN32 defined: yes");
#else
  println("_WIN32 defined: no");
#endif
end.
```

> [!NOTE]
> 🧩 The full conditional and directive family is documented in [Build Directives](#build-directives).

<a id="compiler-cli"></a>

### 🧭 The Compiler CLI

`Myra` needs one thing: a source file.

| Flag | Long form | Meaning |
|---|---|---|
| `-s` | `--source <file>` | **Required.** The `.myra` file to compile. |
| `-o` | `--output <path>` | Output path. Defaults to `output`. |
| `-r` | `--autorun` | Build, then run the compiled binary. |
| `-d` | `--debug` | Build, then debug it under the DAP debugger. |
| `-h` | `--help` | Show usage. |

```
> Myra -s hello.myra              // compile into ./output
> Myra -s hello.myra -o build     // compile into ./build
> Myra -s hello.myra -r           // compile, then run
> Myra -s hello.myra -d           // compile, then debug
```

`-r` and `-d` are alternatives, not companions. See [Tools](#tools) for exit codes, the debugger, the DAP surface, and the language server.

<a id="module-kinds"></a>

### 🏗️ Module Kinds

The `module` declaration decides what gets built. There are exactly three kinds:

```
module exe <name>;
module dll <name>;
module lib <name>;
```

| Declaration | Produces | Use it for |
|---|---|---|
| `module exe name;` | `name.exe` | A program with an entry point. |
| `module dll name;` | `name.dll` | A shared library, loaded at runtime. |
| `module lib name;` | A static library | Reusable code, linked into whatever imports it. |

#### Static library (`lib`)

A `lib` is Myra code that other Myra modules `import`. From `test_lib_utils.myra`:

```myra
module lib test_lib_utils;

routine Clamp(val: int32; lo: int32; hi: int32): int32;
begin
  if val < lo then
    return lo;
  end;
  if val > hi then
    return hi;
  end;
  return val;
end;

routine IsEven(n: int32): boolean;
begin
  return n mod 2 = 0;
end;

end.
```

Import it and call it with the module name as a qualifier. From `test_exe_uselib.myra`:

```myra
module exe test_exe_uselib;

import test_lib_mathlib;

var
  LIntResult: int32;

begin
  LIntResult := test_lib_mathlib.Add(3, 4);
  println("Add(3, 4) = {}", LIntResult);
end.
```

Calls are **always qualified** by the module name. `import` does not pull names into your scope.

> [!TIP]
> 💡 `import` takes a comma-separated list: `import Maths, StrUtils, Convert;`

#### Shared library (`dll`)

A `dll` publishes a surface for the outside world. Mark it with `exported`, and use the `clink` linkage specifier when you want an unmangled, C-callable symbol:

```myra
module dll mathlib;

exported routine clink Square(const n: int32): int32;
begin
  return n * n;
end;

end.
```

`cpplink` is the default linkage and gives ordinary C++ mangling. Consuming a Myra `dll` or `lib` from a C++ host is its own topic -- see [API Reference](#api-reference).

<a id="build-config"></a>

### ⚙️ Build Configuration Lives in the Source

Build settings are **directives**, not command-line flags. They start with `@`, end with a semicolon, and sit after the module declaration. Because they are part of the source, a file builds the same way no matter how `Myra` was invoked or who invoked it.

```myra
module exe fib;

@target win64;
@optimize releasefast;
@subsystem console;

routine fib(const n: int32): int32;
begin
  if n <= 1 then
    return n;
  end;
  return fib(n - 1) + fib(n - 2);
end;

begin
  println("fib(30) = {}", fib(30));
end.
```

The three you will reach for first:

| Directive | Values | Purpose |
|---|---|---|
| `@target` | `win64`, `winarm64`, `linux64`, `linuxarm64`, `macos64`, `wasm32` | The platform the binary is built for. |
| `@optimize` | `debug`, `releasesafe`, `releasefast` (alias: `release`), `releasesmall` | Optimization level passed to the toolchain. |
| `@subsystem` | `console`, `gui` | Subsystem of the produced binary. Default is `console`. |

The value may be written bare or quoted. Both forms appear in the test suite and both are accepted:

```myra
@target win64;
@target "win64";
```

> [!NOTE]
> 🧩 These three are the entry points to a much larger family -- conditional compilation, module and include search paths, link libraries, version info, icons, and more. All of them are in [Build Directives](#build-directives).

<a id="targets-and-running"></a>

### 🎯 Targets, and What Can Actually Run

There are exactly six targets. Cross-**compiling** to any of them works from the Windows host. Cross-**running** is a different question, and the compiler is honest about it: when a target cannot be launched, `-r` emits a **warning and continues**. It never fails the build.

| `@target` | Triple | `-r` on the Windows host |
|---|---|---|
| `win64` | `x86_64-windows-gnu` | ✅ Runs natively. |
| `linux64` | `x86_64-linux-gnu` | ✅ Runs through WSL (WSL must be installed). |
| `wasm32` | `wasm32-wasi` | ✅ Opens in your browser. See below. |
| `winarm64` | `aarch64-windows-gnu` | ⚠️ Builds. Warns instead of running. |
| `linuxarm64` | `aarch64-linux-gnu` | ⚠️ Builds. Warns instead of running. |
| `macos64` | `aarch64-macos-none` | ⚠️ Builds. Warns instead of running. Apple Silicon only, by design. |

The rule behind the table: a binary can only be launched when **both** the architecture and the OS match the host. An `aarch64` PE cannot execute on an x64 machine, and a Mach-O binary needs a Mac. Checking the OS alone would not be enough.

#### WebAssembly

`wasm32` is the interesting one, because it runs with no server and no runtime install. The compiler emits a self-contained `<project>.html` beside the `.wasm`, with **both** the WASI shim and the wasm bytes inlined as base64. `-r` opens it. Double-clicking it works too.

```
> Myra -s hello.myra -r     // with @target wasm32; in the source
```

> [!WARNING]
> ⚠️ `wasm32` builds with `-fno-exceptions`. C++ exceptions are not available on this toolchain, so **`guard` / `except` is a hard compile error on `wasm32`**. This is a property of the target, not a bug to route around.

<a id="standard-library"></a>

### 📚 The Standard Library

The standard library ships with the compiler and is always on the module search path. `import` it and it is there -- nothing to fetch, nothing to configure.

| Module | Provides |
|---|---|
| `Maths` | `Sqrt`, `Abs`, `Min`, and the rest of the numeric surface. |
| `StrUtils` | `UpperCase`, `Trim`, `Length`, string manipulation. |
| `Console` | Console control and colour constants (`clGreen`, `clReset`). |
| `Convert` | `IntToStr`, `StrToInt`, `BoolToStr`. |
| `Paths` | `ExtractFileExt`, `HasExtension`, path handling. |
| `Files` | `FileExists` and file system queries. |
| `DateTime` | `IsLeapYear`, `DaysInMonth`, date and time. |
| `Geometry` | `TRect`, `Rect`, `RectWidth`, `IsRectEmpty`. |
| `Assertions` | `AssertTrue`, `AssertEqual`. |

From `test_exe_std.myra`:

```myra
module exe test_exe_std;

import
  Maths,
  StrUtils,
  Convert,
  Geometry;

var
  LRect: Geometry.TRect;

begin
  println("Sqrt(4.0) = {}", Maths.Sqrt(4.0));
  println("Trim(\"  x  \") = {}", StrUtils.Trim("  x  "));
  println("IntToStr(42) = {}", Convert.IntToStr(42));

  LRect := Geometry.Rect(0, 0, 100, 50);
  println("RectWidth = {}", Geometry.RectWidth(LRect));
end.
```

Note `Geometry.TRect` -- types are qualified by their module exactly like routines are.

<a id="project-layout"></a>

### 🗂️ Project Layout

A Myra program is just `.myra` files. There is no project file, no manifest, and no build script. The smallest project is one source file:

```
my-project/
  hello.myra              // your source
  output/                 // created by Myra
    zig-out/
      bin/
        hello.exe         // the binary, named after the module
```

`Myra -s hello.myra` emits C++23, builds it with the bundled toolchain, and writes the binary to `<output>/zig-out/bin/<module name>.exe`. `-o` moves the whole `output` tree somewhere else.

A project with a library is still just files sitting next to each other:

```
my-project/
  main.myra               // module exe main;  -- import utils;
  utils.myra              // module lib utils;
```

If the library lives elsewhere, point at it with `@modulepath`:

```myra
@modulepath "libs";
```

<a id="first-run-issues"></a>

### 🧯 Common First-Run Issues

| Symptom | Cause | Fix |
|---|---|---|
| Module not found | The `lib` file is not beside the main file and not on a `@modulepath`. | Move it alongside, or add `@modulepath "folder";` |
| Module not found, file is right there | The module name does not match the filename. | Rename one so they agree. |
| Unknown symbol | An imported routine was called without its module qualifier. | Write `modulename.routinename(...)`. |
| Routine invisible across a boundary | The declaration is not marked `exported`. | Add `exported`. |
| Clang errors you did not write | Raw C++ passthrough has a syntax error in it. | Passthrough is emitted verbatim. Check that C++ carefully. |
| `guard` / `except` will not compile | The target is `wasm32`. | Exceptions are unavailable there. See [Targets](#targets-and-running). |
| Built fine, but `-r` only warned | The target cannot run on this host. | Expected. See the target table above. |

<a id="editor-support"></a>

### 🧠 Editor Support

`MyraLSP.exe` is a Language Server. Point any LSP-capable editor at it and you get live diagnostics, hover, go-to-definition, find-references, rename, document and workspace symbols, folding, semantic highlighting, signature help, inlay hints, formatting, and code actions while you edit.

It speaks JSON-RPC over stdio and takes no arguments -- the editor launches it. Configuration, the full method list, and the debugger are all covered in [Tools](#tools).

<a id="language-reference"></a>

## 📘 Language Reference

Myra is a minimal, Pascal/Oberon-inspired systems language. It is case-sensitive, all keywords are lowercase, statements are terminated by `;`, and bodies are delimited by `begin` ... `end`. Control-flow constructs carry their own terminating `end` and take no `begin`.

Types are static. Every value has a type known at compile time, and `:` introduces a type annotation in the form `name: type`.

Myra compiles to C++23. Any token Myra does not recognize is emitted verbatim to the generated C++ -- there is no escape-hatch syntax, because there is no boundary to escape.

### 💬 Comments

```myra
// line comment
/* block comment */
```

Block comments do not nest.

### 🔡 Lexical Elements

#### Identifiers

An identifier starts with a letter or `_` and continues with letters, digits, or `_`. Myra is **case-sensitive**: `Count` and `count` are two different names.

#### Numeric Literals

| Form | Example | Notes |
|---|---|---|
| Decimal integer | `42`, `-10` | |
| Hexadecimal integer | `0xFF00`, `0XFF00` | `0x` or `0X` prefix |
| Float | `3.14159`, `1.5` | A digit is required on **both** sides of the `.` |

#### Text Literals

| Form | Example | Type |
|---|---|---|
| String | `"Hello"` | `string` (UTF-8) |
| Wide string | `w"Hello"` | `wstring` |
| Character | `'A'` | `char` |

A source file is UTF-8, and a string literal may contain any UTF-8 text directly:

```myra
emoji := "🔥🚀💡🎉";
jp    := "こんにちは世界";
mixed := "Hello 🌍 Wörld café résumé naïve";
```

#### Escape Sequences

Escapes are available in both `"..."` and `w"..."` literals.

| Escape | Meaning |
|---|---|
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Tab |
| `\0` | Null |
| `\\` | Backslash |
| `\"` | Double quote |
| `\xNN` | Byte with hex value `NN` |

```myra
println("tab:\there");
println("quote: \"quoted\"");
println("hex escape: \x41\x42\x43");   // ABC
```

> [!NOTE]
> 🔤 `{` and `}` are the format placeholders in `print` / `println`. To print a literal brace, double it: `println("{{1,3,5}} raw: {}", int32(small));`

### 📦 Modules

Every program is a module. The declaration names a **kind**, then a name. The module ends with `end.`

```myra
module exe HelloWorld;

begin
  println("Hello, World!");
end.
```

| Kind | Produces |
|------|----------|
| `exe` | An executable program. |
| `dll` | A shared library. |
| `lib` | A **static** library. |

A module is a declaration header followed by an optional body, in this order:

```
module <kind> <name>;
  directives          @target, @optimize, ...
  import clause       import A, B;
  declarations        const / type / var / routine
begin
  statement sequence
end.
  test blocks         test "..." begin ... end;
```

The output artifact is named after the module, so `module exe HelloWorld;` builds `HelloWorld.exe`. A module's declared name must match its filename.

> [!IMPORTANT]
> 🧱 There are exactly **three** module kinds: `exe`, `dll`, `lib`. There is no `unit` kind.

### 🔢 Primitive Types

Myra has a concrete type system that maps directly to machine reality. Every primitive has a fixed size, which `size()` reports at compile time.

#### Integer Types

| Myra | C++ | `size()` | Range |
|------|-----|------|-------|
| `int8` | `int8_t` | 1 | -128 to 127 |
| `int16` | `int16_t` | 2 | -32,768 to 32,767 |
| `int32` | `int32_t` | 4 | -2,147,483,648 to 2,147,483,647 |
| `int64` | `int64_t` | 8 | Full 64-bit signed range |
| `uint8` | `uint8_t` | 1 | 0 to 255 |
| `uint16` | `uint16_t` | 2 | 0 to 65,535 |
| `uint32` | `uint32_t` | 4 | 0 to 4,294,967,295 |
| `uint64` | `uint64_t` | 8 | Full 64-bit unsigned range |

#### Floating-Point Types

| Myra | C++ | `size()` | Description |
|------|-----|------|-------------|
| `float32` | `float` | 4 | 32-bit IEEE 754 |
| `float64` | `double` | 8 | 64-bit IEEE 754 |

#### Boolean, Character, String, Pointer, Set

| Myra | C++ | `size()` | Description |
|------|-----|------|-------------|
| `boolean` | `bool` | 1 | Literals `true` / `false` |
| `char` | `char` | 1 | 8-bit character, literal `'a'` |
| `wchar` | `wchar_t` | 2 | Wide character |
| `string` | `std::string` | managed | UTF-8 string, literal `"..."` |
| `wstring` | `std::wstring` | managed | Wide string, literal `w"..."` |
| `pointer` | `void*` | 8 | Untyped pointer; `nil` is the null pointer |
| `set` | bit set | varies | See [Composite Types](#composite-types) |

`string` and `wstring` are **managed**: they own their storage, they are freed automatically when they leave scope, and reassignment releases the old value. This holds inside records and inside dynamic arrays too.

> [!NOTE]
> 🔤 The boolean type keyword is `boolean`, not `bool`.

### 🧵 Strings

A `string` is UTF-8. `len()` returns its **byte** length, not its character count, so a multi-byte character counts for more than one:

```myra
println("len of ABC = {}", len("ABC"));      // 3
println("len of café = {}", len("café"));    // 5
```

`+` concatenates. It works between two strings, between a string and a literal in either order, and between a string and a `char` in either order:

```myra
var
  s1: string;
  s3: string;
  c: char;

begin
  s1 := "Hello";
  s3 := s1 + " World";     // Hello World
  s3 := "Hi " + s1;        // Hi Hello

  c := '!';
  s3 := s1 + c;            // Hello!
  s3 := c + s1;            // !Hello
end.
```

The comparison operators are lexicographic across the whole family: `=`, `<>`, `<`, `>`, `<=`, `>=`.

A `wstring` behaves the same way -- `+` concatenates, the comparisons order it -- but it cannot go straight into a format placeholder. Convert it with `utf8()` first:

```myra
var
  wide: wstring;

begin
  wide := w"Hello, Wide World!";
  println("{}", utf8(wide));
  println("wlen = {}", len(wide));
end.
```

### 📥 Variables and Constants

`var` declares mutable storage; `const` declares a compile-time constant. Both are **blocks**: one keyword, many declarations, each terminated by `;`.

```myra
const
  MaxItems: int32 = 100;    // explicit type
  AppName = "Myra Test";    // type inferred from the initializer
  Version = 1;

var
  x: int32;
  name: string;
  pi: float64;
```

A `const` may carry an explicit type or infer it from its initializer. A `var` may carry an initializer:

```myra
var
  total: int32 = 0;
  greeting: string = "Myra";
```

A `var` declaration may instead bind to an externally linked symbol:

```myra
var
  version: int32; external "mathdll";
```

Variables declared inside a routine sit between the signature and the `begin`. A `var` block is also a statement, so it may open a nested scope inside a body.

### ➕ Operators

Assignment is written `:=`. A single `=` is the **equality operator**, never assignment.

#### Assignment

| Operator | Meaning |
|---|---|
| `a := b` | Assign |
| `a += b` | Add and assign |
| `a -= b` | Subtract and assign |
| `a *= b` | Multiply and assign |
| `a /= b` | Divide and assign |

```myra
x := 10;
x += 5;      // 15
x -= 3;      // 12
x *= 2;      // 24
x /= 4;      // 6
```

Assignment is an **expression**, and it is right associative.

#### Arithmetic

| Operator | Operation |
|----------|-----------|
| `a + b` | Addition (also string concatenation, also set union) |
| `a - b` | Subtraction (also set difference) |
| `a * b` | Multiplication (also set intersection) |
| `a / b` | Division |
| `a div b` | Integer division |
| `a mod b` | Modulo (remainder) |
| `-x` / `+x` | Unary negate / plus |

```myra
a := 10;
b := 3;
println("{}", a div b);   // 3
println("{}", a mod b);   // 1
```

#### Comparison

| Operator | Operation |
|----------|-----------|
| `a = b` | Equal |
| `a <> b` | Not equal |
| `a < b` | Less than |
| `a > b` | Greater than |
| `a <= b` | Less than or equal |
| `a >= b` | Greater than or equal |
| `a in s` | Set membership |

#### Logical and Bitwise

| Operator | Operation |
|----------|-----------|
| `a and b` | AND |
| `a or b` | OR |
| `a xor b` | XOR |
| `not x` | NOT |
| `a shl n` | Shift left |
| `a shr n` | Shift right |

#### Unary and Postfix

| Operator | Operation |
|----------|-----------|
| `address of x` | Take the address of `x` |
| `x^` | Dereference a pointer (postfix) |
| `a[i]` | Index |
| `a.field` | Field selection |
| `f(...)` | Call |

#### Precedence

Tightest binding last.

| Power | Operators |
|---|---|
| 2 | `:=` `+=` `-=` `*=` `/=` (right associative) |
| 6 | `or` |
| 8 | `and` `xor` |
| 10 | `=` `<>` `<` `>` `<=` `>=` `in` |
| 20 | `+` `-` (binary) |
| 25 | `shl` `shr` |
| 30 | `*` `/` `div` `mod` |
| 35 | `not` `-` `+` `address of` (prefix) |
| 40 | call `( )` |
| 45 | index `[ ]`, field `.` |
| 50 | deref `^` (postfix) |

```myra
c := a + b * 2;      // 16   -- * binds tighter
c := (a + b) * 2;    // 26
```

> [!IMPORTANT]
> 🧱 `=` is **equality**, never assignment. All mutation goes through `:=` or a compound assignment. This is the single most common thing to trip over coming from C.

### 🔄 Type Casts

A builtin type name, applied like a call, converts a value to that type.

```myra
var
  d: float64;
  n: int32;

begin
  d := 3.7;
  n := int32(d);            // 3
  println("{}", int64(n));
end.
```

This is the everyday way to widen, narrow, or reinterpret between the numeric types, and it is how you print a `choices` value or a `set`, neither of which has a format of its own:

```myra
type
  Color = choices(Red, Green, Blue);

var
  c: Color;
  s: set;

begin
  c := Green;
  println("Color Green = {}", int32(c));   // 1

  s := [1, 3, 5];
  println("bits = {}", int64(s));          // 42
end.
```

Casting a **pointer** uses the longer `pointer to T(expr)` form -- see [Pointers](#-pointers).

<a id="composite-types"></a>

### 🧱 Composite Types

The `type` block names new types. Each declaration is `Name = definition;`

```myra
type
  Celsius = int32;                                             // alias
  Point = record x: int32; y: int32; end;                      // record
  Color = choices(Red, Green, Blue);                           // enumeration
  Value = overlay i: int32; f: float32; end;                   // union
  Buffer = array[0..255] of uint8;                             // fixed array
  Items = array of int32;                                      // dynamic array
  IntPtr = pointer to int32;                                   // typed pointer
  Flags = set of 0..31;                                        // set
  TCompare = routine(const a: int32; const b: int32): int32;   // routine type
```

#### Type Aliases

An alias is a new name for an existing type.

```myra
type
  Counter = int32;
  Offset = float64;

var
  count: Counter;
  off: Offset;

begin
  count := 99;
  off := 3.14;
end.
```

#### Records

A record is a value type with named fields, emitted as a C++ `struct`.

```myra
type
  Point = record
    x: int32;
    y: int32;
  end;

var
  p: Point;

begin
  p.x := 10;
  p.y := 20;
  println("Point: {}, {}", p.x, p.y);
end.
```

**Record literals.** A record type name, applied like a call, constructs a value from its fields positionally:

```myra
litPoint := Point(77, 88);
println("Literal: {}, {}", litPoint.x, litPoint.y);
```

**Inheritance.** Name the parent in parentheses. The derived record carries the parent's fields:

```myra
type
  Point = record
    x: int32;
    y: int32;
  end;

  Point3D = record(Point)
    z: int32;
  end;

var
  p3d: Point3D;

begin
  p3d.x := 100;      // inherited
  p3d.y := 200;      // inherited
  p3d.z := 300;
end.
```

**Nesting.** A record may contain another record, to any depth. Access chains with `.`:

```myra
type
  Point = record x: int32; y: int32; end;
  Box = record corner: Point; depth: int32; end;
  Container = record box: Box; id: int32; end;

var
  cont: Container;

begin
  cont.box.corner.x := 100;
end.
```

**Packed layout.** `packed` removes padding:

```myra
type
  PackedRec = record packed
    a: int8;
    b: int8;
    c: int8;
  end;

begin
  println("PackedSize: {}", size(PackedRec));   // 3
end.
```

**Alignment.** `align(N)` sets a custom alignment. `1`, `2`, `4`, `8`, and `16` are all in use in the test suite:

```myra
type
  AlignedVec = record align(16)
    x: float32;
    y: float32;
    z: float32;
    w: float32;
  end;
```

**Bitfields.** A second `:` after the field type gives a bit width:

```myra
type
  BitRec = record packed
    a: uint8 : 3;
    b: uint8 : 2;
    c: uint8 : 1;
  end;

var
  bits: BitRec;

begin
  bits.a := 7;
  bits.b := 3;
  bits.c := 1;
  println("Bits: {}, {}, {}",
    static_cast<int>(bits.a), static_cast<int>(bits.b), static_cast<int>(bits.c));
end.
```

> [!NOTE]
> 🧩 A bitfield emits as a real C++ bitfield, and a narrow bitfield prints as a character unless it is widened first. `static_cast<int>(...)` above is not a Myra construct at all -- it is raw C++, passing straight through.

#### Overlays (Unions)

An overlay shares storage across all its fields, emitted as a C++ `union`.

```myra
type
  IntOrFloat = overlay
    i: int32;
    f: float32;
  end;

var
  u: IntOrFloat;

begin
  u.i := 42;
  println("Union: {}", u.i);
  u.f := 3.14;
  println("UnionFloat: {:.2f}", u.f);
end.
```

**An overlay may nest inside a record**, anonymously -- the C union-in-struct pattern. The overlay's fields are reached directly on the record:

```myra
type
  RecWithAnonOverlay = record
    tag: int32;
    overlay
      asInt: int32;
      asFloat: float32;
    end;
  end;

var
  rau: RecWithAnonOverlay;

begin
  rau.asInt := 99;
end.
```

**And a record may nest inside an overlay**, anonymously -- the classic hi/lo split:

```myra
type
  OverlayWithAnonRec = overlay
    single: int64;
    record
      lo: int32;
      hi: int32;
    end;
  end;

var
  uwar: OverlayWithAnonRec;

begin
  uwar.lo := 11;
  uwar.hi := 22;
end.
```

#### Choices (Enumerations)

`choices` declares an enumeration. Values are auto-numbered from zero, or given explicit values, which may have gaps.

```myra
type
  Color = choices(Red, Green, Blue);
  ErrorCode = choices(None = 0, NotFound = 404, Internal = 500);
  SparseEnum = choices(A = 0, B = 5, C = 10);

var
  c: Color;
  ec: ErrorCode;

begin
  c := Green;
  println("Color Green = {}", int32(c));          // 1

  ec := NotFound;
  println("ErrorCode NotFound = {}", int32(ec));  // 404
end.
```

A choice value is referenced **bare** -- `Green`, not `Color.Green`. Compare with `=` and `<>`; cast with `int32(...)` to print.

```myra
if c = Red then
  println("c is Red");
end;
```

#### Arrays

**Fixed arrays** carry bounds. The lower bound need not be zero.

```myra
type
  IntArr5 = array[0..4] of int32;
  IntArr3OneBased = array[1..3] of int32;

var
  arr: IntArr5;
  arr1: IntArr3OneBased;
  arrInline: array[0..2] of int32;    // inline type, no name needed

begin
  arr[0] := 10;
  arr1[1] := 1;
  println("LenStatic: {}", len(arr));          // 5
  println("Sizeof5: {}", size(IntArr5));       // 20
end.
```

`len()` gives the element count; `size()` gives the byte size of the whole array.

**Multi-dimensional arrays** are arrays of arrays, indexed `[i][j]`:

```myra
var
  arr2d: array[0..1] of array[0..2] of int32;

begin
  for i := 0 to 1 do
    for j := 0 to 2 do
      arr2d[i][j] := i * 10 + j;
    end;
  end;
  println("{}", arr2d[1][2]);   // 12
end.
```

**Whole-array assignment copies:**

```myra
arr2 := arr;      // element-wise copy, not an alias
```

**Dynamic arrays** omit the bounds. They start empty; `setlength` sizes them and `len` reports the current length. `array of T` and `array[] of T` are the same thing.

```myra
type
  DynInts = array of int32;
  OpenFloats = array[] of float64;

var
  dyn: DynInts;

begin
  setlength(dyn, 3);
  dyn[0] := 100;
  dyn[1] := 200;
  dyn[2] := 300;
  println("dyn len = {}", len(dyn));   // 3
end.
```

Resizing preserves the existing elements. Growing zero-fills the new ones; shrinking keeps the first N:

```myra
setlength(arr, 3);        // 10 20 30
setlength(arr, 5);        // 10 20 30 0 0
setlength(arr, 2);        // 10 20
```

Dynamic arrays hold **any** element type, including records and managed types, and the cleanup is handled for you at end of scope:

```myra
var
  names: array of string;
  people: array of Person;

begin
  setlength(names, 3);
  names[0] := "Alice";
  names[0] := "NewAlice";     // the old value is released

  setlength(people, 2);
  people[0].personName := "John";
  people[0].age := 25;
end.
```

**Arrays as parameters.** `array of T` in a parameter list takes an array of any length. `const` passes it read-only; `var` allows the routine to write through it:

```myra
routine SumArray(const arr: array of int32): int32;
var
  i: int32;
  total: int32;
begin
  total := 0;
  for i := 0 to len(arr) - 1 do
    total := total + arr[i];
  end;
  return total;
end;

routine FillArray(var arr: array of int32; const value: int32);
var
  i: int32;
begin
  for i := 0 to len(arr) - 1 do
    arr[i] := value;
  end;
end;
```

**Arrays combine freely** with the other composite types -- an array inside a record, an array of records, an array of records that hold strings:

```myra
type
  RecWithArr = record
    values: array[0..2] of int32;
    tag: int32;
  end;

var
  rec: RecWithArr;
  points: array[0..1] of Point;

begin
  rec.values[0] := 10;
  points[0].x := 1;
  points[1].y := 4;
end.
```

#### Sets

A set is a **bit set**. A bare `set` is a usable type in its own right; `set of` gives it an explicit range or an enumeration to draw from.

```myra
type
  ByteSet = set of 0..255;
  ColorSet = set of Color;

var
  s: set;                 // bare set
  small: set of 0..7;     // 8-bit
  medium: set of 0..31;   // 32-bit
  offset: set of 100..163;
  colors: set of Color;
```

A set literal is written in brackets, may list elements, ranges, or both, and `[]` is the empty set:

```myra
s := [];              // empty
s := [1, 3, 5];       // elements       -> bits 1, 3, 5 set  -> 42
s := [1..5];          // a range        -> 62
s := [1, 5, 6, 10];   // both           -> 1122
```

The set is sized to its declared range, and an **offset** range works exactly as a zero-based one does -- `set of 100..163` holds 100 through 163, and nothing outside it:

```myra
offset := [100, 105, 110];
if 100 in offset then ... end;    // true
if 99 in offset then ... end;     // false
if 164 in offset then ... end;    // false
```

The operators carry their classic Pascal set meanings:

| Operator | Operation |
|----------|-----------|
| `x in s` | Membership |
| `a + b` | Union |
| `a * b` | Intersection |
| `a - b` | Difference |
| `a = b` / `a <> b` | Equality |

```myra
var
  s1: set;
  s2: set;
  s3: set;

begin
  s1 := [1, 3, 5];      // 42
  s2 := [3, 5, 10];     // 1064

  s3 := s1 + s2;        // union        [1, 3, 5, 10]
  s3 := s1 * s2;        // intersection [3, 5]
  s3 := s1 - s2;        // difference   [1]

  if 3 in s1 then
    println("3 is in s1");
  end;
end.
```

**A `set of` an enumeration** is the natural way to carry a bag of flags, and it works with sparse enumerations too:

```myra
type
  Color = choices(Red, Green, Blue, Yellow);

var
  colors: set of Color;

begin
  colors := [Red, Blue];
  colors := colors + [Green];

  if Green in colors then
    println("Green is in colors");
  end;
end.
```

A set has no format of its own. Cast it to see the raw bits: `println("{}", int64(s));`

#### Pointer Types

A typed pointer names its target. `const` makes the target read-only. A bare `pointer` is untyped (`void*`), and `nil` is the null pointer.

```myra
type
  PInt32 = pointer to int32;
  PConstInt = pointer to const int32;

var
  p: pointer to int32;    // inline, no named type needed
  raw: pointer;           // untyped
```

See [Pointers](#-pointers) for taking addresses, dereferencing, and pointer arithmetic.

#### Routine Types

A routine type is a callable value -- Myra's function pointer. It carries a parameter list, an optional return type, and an optional **linkage specifier**.

```myra
type
  // C++ linkage (the default) -- for Myra and C++ callbacks
  TIntFunc = routine(const a: int32; const b: int32): int32;

  // C linkage -- for the callback slot a C library expects
  TCCallback = routine clink (const x: int32): int32;
  TEventHandler = routine clink (const code: int32; const data: pointer): int32;
```

Assign a routine of a matching signature and linkage, then call through the variable:

```myra
var
  mathOp: TIntFunc;
  cCallback: TCCallback;

routine Add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

routine clink DoubleValue(const x: int32): int32;
begin
  return x * 2;
end;

begin
  mathOp := Add;
  println("{}", mathOp(10, 20));       // 30

  cCallback := DoubleValue;
  println("{}", cCallback(100));       // 200
end.
```

`cpplink` is the default. `clink` gives the type the C calling convention -- which is what a C library's callback slot requires.

#### Objects

An `object` carries fields and methods. Instances are heap-allocated with `create` and released with `destroy`. `self` accesses the current instance; `parent` reaches the base.

```myra
type
  TCounter = object
    value: int32;

    method increment();
    begin
      self.value := self.value + 1;
    end;

    method get_value(): int32;
    begin
      return self.value;
    end;
  end;
```

**Inheritance.** Name the parent in parentheses; a derived method overrides the base, and `parent.method()` calls the base implementation:

```myra
type
  TDerived = object (TBase)
    y: int32;

    method describe(): int32;
    begin
      return parent.describe() + self.y;
    end;
  end;
```

> [!NOTE]
> 🧩 Objects give you real C++ class semantics -- a vtable, single inheritance, and `self` / `parent` dispatch. Reach for an `object` when the C++ boundary demands a genuine class; reach for a `record` otherwise.

### 📍 Pointers

Take an address with `address of`. Dereference with the postfix `^`. Cast with `pointer to T(expr)`.

```myra
var
  x: int32;
  p: pointer to int32;

begin
  x := 42;
  p := address of x;

  println("Value via pointer: {}", p^);   // 42
  p^ := 100;                              // x is now 100
end.
```

`address of` works on any addressable thing, including an array element:

```myra
p := address of arr[2];
println("{}", p^);
```

**Reaching a field through a pointer uses a plain `.`** -- Myra knows the operand is a pointer and emits the C++ arrow for you:

```myra
var
  p: pointer to TPoint;

begin
  create(p);
  p.x := 10;          // no `^` needed
  destroy(p);
end.
```

**Pointer arithmetic works.** Adding an integer to a typed pointer advances it by whole elements, exactly as in C:

```myra
var
  p: pointer;
  pb: pointer to int8;

begin
  p := getmem(100);

  pb := pointer to int8(p);
  pb^ := 42;                        // byte 0

  pb := pointer to int8(p) + 50;
  pb^ := 99;                        // byte 50

  freemem(p);
end.
```

### 🧠 Memory Management

| Form | Purpose |
|------|---------|
| `create(x)` | Allocate and construct a typed instance |
| `destroy(x)` | Destruct and free an instance |
| `getmem(n)` | Allocate `n` bytes of raw memory, returns a pointer |
| `freemem(p)` | Free a raw memory pointer |
| `resizemem(p, n)` | Resize a raw allocation, preserving contents |
| `setlength(a, n)` | Resize a dynamic array |

`getmem` and `resizemem` are usable both as statements and as expressions.

```myra
var
  p: pointer;
  pb: pointer to int8;

begin
  p := getmem(100);

  pb := pointer to int8(p);
  pb^ := 42;

  p := resizemem(p, 200);     // the 42 at byte 0 survives

  freemem(p);
end.
```

> [!WARNING]
> ⚠️ Every `create` needs a matching `destroy`, and every `getmem` a matching `freemem`. Managed values -- `string`, `wstring`, and dynamic arrays -- clean themselves up and need neither.

### 🧮 Intrinsics

| Form | Returns |
|------|---------|
| `len(x)` | Length of a string (bytes), a wide string, or an array |
| `size(x)` | Size in bytes of a type name or a variable |
| `utf8(x)` | Convert a wide string to UTF-8 |
| `paramcount()` | Number of command-line arguments |
| `paramstr(n)` | The nth command-line argument |
| `getexceptioncode()` | Exception code, inside an `except` block |
| `getexceptionmessage()` | Exception message, inside an `except` block |

`size` takes a single name -- a builtin type (`size(int32)`), a user type (`size(PackedRec)`, `size(IntArr5)`), or a variable (`size(x)`) -- not a compound expression.

`paramstr(0)` is the full path to the executable; the user arguments run from `1` to `paramcount()`:

```myra
var
  i: int32;
  n: int32;

begin
  n := paramcount();
  i := 1;
  while i <= n do
    println("paramstr({}) = {}", i, paramstr(i));
    i := i + 1;
  end;
end.
```

### 🔁 Variadics

A trailing `...` in the parameter list marks a routine variadic. `varargs` reads the arguments.

```myra
routine sumInts(...): int32;
var
  i: int32;
  total: int32;
begin
  total := 0;
  for i := 0 to varargs.count - 1 do
    total := total + varargs.next(int32);
  end;
  return total;
end;
```

| Form | Returns |
|------|---------|
| `varargs.count` | Total number of variadic arguments |
| `varargs.next(T)` | Retrieve and consume the next argument as type `T` |

> [!IMPORTANT]
> 🧭 `varargs` is a **one-way cursor**. `next(T)` reads the next argument and advances -- it cannot go back, re-read, or jump to an index. Read the arguments once, in the order they were passed. Mixed types are fine, as long as each `next(T)` names the type that was actually passed at that position.

### 🌉 C++ Types as Myra Types

A type annotation is not restricted to Myra's own types. Any C++ type name is a valid type expression, because an unrecognized token is not an error -- it is C++.

```myra
#include <string>
#include <vector>

module exe Demo;

var
  s: std::string;
  buf: std::vector<int32_t>*;
  pc: char*;

begin
  s := "hello world";
  println("s.length() = {}", s.length());
end.
```

The variable is an ordinary C++ object from that point on, and its methods are callable in Myra expressions. This is the same passthrough rule as everywhere else in the language, applied at the type position.


### 🛠️ Routines

`routine` is the only callable declaration in Myra. There is no separate `procedure` and `function`: a routine that names a return type returns a value, one that does not returns nothing.

```
routine [linkage] name [( params )] [: return-type] ;
  [ var / const / type blocks ]
begin
  statements
end;
```

Everything between `routine` and the `;` is the **signature**. Everything after it is either a body or an `external` clause -- never both.

| Part | Rule |
|------|------|
| `linkage` | Optional. `clink` or `cpplink`. `cpplink` is the **default**. |
| params | `( p1 ; p2 ; p3 )`. Separated by **semicolons**, not commas. |
| return type | Optional. Omit it and the routine returns nothing. |
| body | `begin` ... `end;` -- note the closing semicolon. |
| `external` | Replaces the body entirely. See **C++ Interop**. |

#### Parameters

A parameter is `[modifier] name: type`. Three forms, all green in `test_exe_routines`:

| Form | Passing | Example |
|------|---------|---------|
| `const a: int32` | By value, read-only inside the routine | `routine add(const a: int32; const b: int32): int32;` |
| `var x: int32` | **By reference** -- writes are visible to the caller | `routine inc(var x: int32);` |
| `val: int32` | Bare. No modifier. | `routine Clamp(val: int32; lo: int32; hi: int32): int32;` |

```myra
routine add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

routine inc(var x: int32);
begin
  x := x + 1;
end;
```

```myra
var
  x: int32;
begin
  println("add(3, 4) = {}", add(3, 4));   // add(3, 4) = 7
  x := 10;
  inc(x);
  println("after inc: x = {}", x);        // after inc: x = 11
end.
```

> [!NOTE]
> 🔗 `var` is the only modifier that changes calling semantics. A `var` parameter is a reference: the routine writes through it and the caller sees the change. `const` and the bare form both pass by value.

#### Local Declarations

`var`, `const` and `type` blocks sit **between** the signature's `;` and the `begin`. They are local to the routine.

```myra
routine factorial(const n: int32): int32;
var
  result: int32;
  i: int32;
begin
  result := 1;
  for i := 1 to n do
    result := result * i;
  end;
  return result;
end;
```

`factorial(5)` is `120`. There is no implicit result variable -- `return` is the only way a value leaves a routine, and `result` above is an ordinary local that happens to carry that name.

#### Returning

`return` with an expression yields a value. `return` on its own leaves a routine that has no return type. A routine may return from more than one place:

```myra
routine max(const a: int32; const b: int32): int32;
begin
  if a > b then
    return a;
  end;
  return b;
end;
```

#### Recursion

Routines are visible to themselves. No forward declaration is needed.

```myra
routine fib(const n: int32): int32;
begin
  if n <= 1 then
    return n;
  end;
  return fib(n - 1) + fib(n - 2);
end;
```

`fib(10)` is `55`.

#### Overloading

Two routines may share a name if their parameter types differ. The call site picks the match.

```myra
routine max(const a: int32; const b: int32): int32;
begin
  if a > b then
    return a;
  end;
  return b;
end;

routine max(const a: float64; const b: float64): float64;
begin
  if a > b then
    return a;
  end;
  return b;
end;
```

```myra
println("{}", max(3, 7));       // 7      -- int32 overload
println("{}", max(3.5, 2.8));   // 3.5    -- float64 overload
```

Overloading rides on C++ name mangling, so it cannot coexist with C linkage. If an overloaded routine is marked `clink`, the compiler **demotes it to `cpplink`** and emits a warning. The routine still works; its exported symbol is simply mangled rather than plain. This is proven by `test_lib_mathlib`, where `exported routine clink Max(int32, int32)` is retroactively demoted the moment a `float32` overload of `Max` arrives.

#### Linkage

The optional keyword after `routine` selects the ABI.

| Linkage | Emits | Use when |
|---------|-------|----------|
| `cpplink` (**default**) | Ordinary C++ symbol, mangled. Supports overloads. | Myra calling Myra; anything overloaded. |
| `clink` | Wrapped in `extern "C" { ... }`. Plain, unmangled symbol. | The symbol crosses a binary boundary and must be callable from C, MSVC, gcc, or a `dlsym` lookup. |

`clink` on a routine that is *not* `exported` still gets C linkage -- it is simply `static` as well, so the plain name never leaves the object file. The full visibility matrix is under **Imports and Visibility**.

#### Variadic Routines

A trailing `...` in the parameter list makes a routine variadic. Inside the body, `varargs` reads the arguments.

```myra
routine sumInts(...): int32;
var
  i: int32;
  sum: int32;
  arg: int32;
begin
  sum := 0;
  for i := 0 to varargs.count - 1 do
    arg := varargs.next(int32);
    sum := sum + arg;
  end;
  return sum;
end;
```

```myra
println("{}", sumInts(10, 20, 30));      // 60
println("{}", sumInts(1, 2, 3, 4, 5));   // 15
println("{}", sumInts());                // 0
```

`varargs.count` is the number of arguments actually passed. `varargs.next(type)` reads the **next** one and advances. Types may be mixed within one call, but they must be read back in the order they were passed -- see **Variadics** for why the cursor is one-way.

#### External Routines

`external` replaces the body and binds the routine to a symbol that lives in a linked artifact. The signature is still fully typed, so the call site is checked exactly as any other routine.

```myra
routine clink add(const a: int32; const b: int32): int32; external "test_dll_exports";
```

The string names the artifact. It is optional in the grammar; the form above is what `test_exe_usedll` uses to call into a Myra-built dll. Details are in **C++ Interop**.

### 🔀 Control Flow

Every control-flow construct carries **its own terminating `end`** and takes **no `begin`**. `begin` is reserved for bodies -- the module body, a routine body, a method body, a `test` block. This is the single rule that makes Myra's block structure predictable: if you wrote `begin`, you are opening a body; if you wrote `if` / `while` / `for` / `match` / `guard`, the `end` is already implied.

| Construct | Shape | Terminator |
|-----------|-------|------------|
| `if` | `if` *expr* `then` ... [`else` ...] | `end;` |
| `while` | `while` *expr* `do` ... | `end;` |
| `for` | `for` *v* `:=` *a* (`to` \| `downto`) *b* `do` ... | `end;` |
| `repeat` | `repeat` ... `until` *expr* | `until` |
| `match` | `match` *expr* `of` *arms* [`else` ...] | `end;` |
| `guard` | `guard` ... [`except` ...] [`finally` ...] | `end;` |

#### if / then / else

```myra
var
  x: int32;
begin
  x := 42;

  if x > 100 then
    println("big");
  else
    println("small");
  end;

  if x = 42 then
    println("the answer");
  end;
end.
```

There is no `elseif` keyword. Chain by nesting an `if` inside the `else`:

```myra
if x < 0 then
  println("negative");
else
  if x = 0 then
    println("zero");
  else
    println("positive");
  end;
end;
```

Each nested `if` closes with its own `end`, so the chain ends with a run of them. The condition is an ordinary expression and needs no parentheses.

#### while

Tests first, then runs. The body may not execute at all.

```myra
var
  i: int32;
  sum: int32;
begin
  sum := 0;
  i := 1;
  while i <= 10 do
    sum := sum + i;
    i := i + 1;
  end;
  println("{}", sum);   // 55
end.
```

#### repeat / until

Runs the body, **then** tests. The body always executes at least once. `until` is the terminator -- there is no `end`.

```myra
i := 0;
repeat
  i := i + 1;
until i = 5;
println("{}", i);   // 5
```

The sense of the condition is inverted relative to `while`: `repeat` loops *until* the condition becomes true.

#### for / to / downto

Counts a variable across an inclusive range. `to` counts up, `downto` counts down. The loop variable is an ordinary variable declared in an enclosing `var` block -- `for` does not declare it.

```myra
for i := 1 to 5 do
  println("{}", i);
end;
// 1 2 3 4 5

for i := 5 downto 1 do
  println("{}", i);
end;
// 5 4 3 2 1
```

Both bounds are expressions, evaluated before the loop runs. They can be anything -- including a C++ call:

```myra
for i := std::abs(-3) downto 0 do
  print("{} ", i);
end;
// 3 2 1 0
```

#### match / of

`match` dispatches on a value. Each arm is one or more labels, a `:`, and a statement list. The `else` arm is **optional**; if no arm matches and there is no `else`, nothing runs.

```myra
match x of
  1: println("one");
  2: println("two");
  3: println("three");
else
  println("other");
end;
```

A label may be a **range**, written `lo..hi`, and both endpoints are inclusive:

```myra
match x of
  1..3: print("one to three");
  4..6: print("four to six");
  7..9: print("seven to nine");
else
  print("else");
end;
```

Ranges may be **negative**:

```myra
match x of
  -10..-6: result := 1;
  -5..-1:  result := 2;
  0..5:    result := 3;
else
  result := 0;
end;
```

Labels are not restricted to integers. `char` works, as single values and as ranges:

```myra
match ch of
  'a'..'z': print("lowercase");
  'A'..'Z': print("uppercase");
  '0'..'9': print("digit");
else
  print("other");
end;
```

An arm may carry several labels separated by commas (`1, 3, 5:`) -- the grammar allows it (BNF section 5, `match arm`).

> [!NOTE]
> 🎯 With no `else` and no matching arm, `match` is simply a no-op. In `test_exe_control_flow`, `result` is pre-set to `999`, `x` is `50`, and no arm covers it -- so `result` stays `999`.

#### leave, skip, return

| Keyword | Effect | Emits |
|---------|--------|-------|
| `leave` | Exits the innermost loop or `match` immediately | `break;` |
| `skip` | Abandons the rest of this iteration and starts the next | `continue;` |
| `return` | Leaves the routine, optionally with a value | `return;` / `return expr;` |

`leave` and `skip` map one-for-one onto C++ `break` and `continue` (`myra_emitters.mld`, `stmt.leave` / `stmt.skip`). `return` is covered under **Routines**.

### 🖨️ Output

`print` and `println` are statements, not routines. Both take a format string followed by zero or more arguments. `println` appends a newline; `print` does not.

```myra
println("Hello, World!");
print("no newline");
println("");              // a bare newline
```

#### Placeholders

`{}` is the placeholder. Arguments fill placeholders left to right.

```myra
println("add(3, 4) = {}", add(3, 4));           // add(3, 4) = 7
println("localA={}, localB={}", localA, localB); // localA=10, localB=20
```

A placeholder may carry a **format spec** after a colon. The spec is passed through to the underlying C++ formatter, so the familiar precision and width forms work:

```myra
println("{:.1f}", 3.75);    // 3.8   -- one decimal place
println("{:.2f}", u.f);     // two decimal places
```

To print a literal brace, double it: `{{` produces `{`.

#### What can go in a placeholder

| Type | Direct? | Notes |
|------|---------|-------|
| integers (`int8`..`uint64`) | ✅ | |
| `float32`, `float64` | ✅ | `{:.Nf}` controls precision |
| `boolean` | ✅ | prints as `true` / `false` |
| `char` | ✅ | |
| `string` | ✅ | |
| C++ types (`std::string`, `size_t`, ...) | ✅ | anything the C++ formatter knows |
| `wstring` | ❌ | wrap it: `println("{}", utf8(wide))` |
| `choices` value | ❌ | cast it: `println("{}", int32(c))` |
| `set` | ❌ | cast or test membership first |

```myra
println("Enum variable c = {}", int32(c));   // choices -- cast to int32
println("{}", utf8(wide));                   // wstring -- through utf8()
```

> [!NOTE]
> 🔢 A `boolean` prints as text, not as `0`/`1`. If you want the numeric form, cast: `println("{}", int32(isPositive(42)))` prints `1`.

#### Escapes

The format string is an ordinary Myra string literal, so the full escape table applies -- `\n`, `\t`, `\"`, `\\`. Escaping a quote inside a placeholder-bearing string is common in practice:

```myra
println("StrToInt(\"123\") = {}", Convert.StrToInt("123"));
```

### 🧩 Imports and Visibility

Myra has exactly **two** visibility levels, and one keyword to move between them.

| Declared | Visibility | Emitted as |
|----------|------------|------------|
| `routine helper(...)` | **Private.** Visible only inside its own module. | `static` |
| `exported routine Add(...)` | **Public.** Visible to importing modules and across a binary boundary. | `MYR_EXPORT` + a forward declaration in the generated header |

That mapping is the emitter's, not a convention: a declaration without `exported` is emitted `static`, and a declaration with it gets the export attribute (`myra_emitters.mld`, `decl.routine`). There is no third level, no `protected`, no per-module friend list.

`exported` is a **prefix on any declaration** -- routines, variables, types, constants:

```myra
exported routine clink add(const a: int32; const b: int32): int32;
exported var version: int32 = 1;
```

#### Declaring a library

```myra
// test_lib_math.myra
module lib test_lib_math;

// Private helper - only visible within this module
routine dbl(const x: int32): int32;
begin
  return x + x;
end;

// Public - visible to importing modules
exported routine clink add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

// Public - calls the private routine internally
exported routine clink quadruple(const x: int32): int32;
begin
  return dbl(dbl(x));
end;

end.
```

`dbl` is invisible outside the module, but `quadruple` calls it freely. Private does not mean unusable -- it means unexported.

#### Importing

`import` names one or more modules. One clause, comma-separated:

```myra
module exe test_exe_import;

import test_lib_math;

begin
  println("{}", test_lib_math.add(3, 5));        // 8
  println("{}", test_lib_math.quadruple(5));     // 20
end.
```

Several modules in a single clause:

```myra
import
  Maths,
  StrUtils,
  Convert;
```

#### Qualified calls

An imported name is reached through `module.name`. The module name is the qualifier:

```myra
test_lib_math.add(3, 5)
Maths.Sqrt(4.0)
Geometry.RectWidth(LRect)
```

This is not decoration. Each module emits a C++ namespace, and `module.name` compiles to a namespace-qualified call. Which leads to the one hard rule:

> [!IMPORTANT]
> 🧷 **A module's declared name must match its filename.** `module lib test_lib_math;` must live in `test_lib_math.myra`. A qualified call resolves against the module's emitted namespace, and the namespace is derived from the declared name -- so a mismatch produces a call to a namespace that does not exist.

#### Visibility crossed with linkage

`exported` decides *whether* a symbol leaves the module. Linkage decides *what it is called* when it does. They are independent, and all four combinations are legal:

| Declaration | Meaning |
|-------------|---------|
| `routine Foo()` | private, C++ linkage |
| `routine clink Foo()` | private, C linkage (`extern "C"`, still `static`) |
| `exported routine Foo()` | public, C++ linkage -- mangled name, supports overloads |
| `exported routine clink Foo()` | public, C linkage -- plain unmangled name, callable from C |

All four are exercised by `test_lib_mathlib`. The one thing you cannot have is `exported routine clink` on an **overloaded** name: overloads require mangling, so the compiler demotes that routine to `cpplink` and warns. See **Routines**.

### 📚 The Standard Library

The standard library is nine ordinary Myra `lib` modules, living in `res/libs/std`. There is nothing special about them: they are written in Myra, they use `exported` like any other library, and they are reached with `module.name` like any other library. The only privilege they have is that their path is **always on the module search path**, so `import Maths;` works with no `@modulepath` and no configuration.

| Module | Surface |
|--------|---------|
| `Maths` | `Abs` `Sqr` `Sqrt` `Cbrt` `Hypot`; trigonometry (`Sin` `Cos` `Tan` `ArcSin` `ArcCos` `ArcTan` `ArcTan2`) and the hyperbolic family; logarithms and exponentials (`Ln` `Log10` `Log2` `LogN` `Exp` `Exp2` `Power`); rounding (`Trunc` `Round` `Ceil` `Floor` `Int` `Frac` `FMod`); `Min` `Max` `Sign` `Clamp` `Lerp`; `DegToRad` `RadToDeg`; `Randomize` `Random` `RandomRange` `RandomF`; `Swap`; `IsNaN` `IsInfinite` `IsFinite` |
| `StrUtils` | `UpperCase` `LowerCase` `UpCase` `LowCase` `Trim` `TrimLeft` `TrimRight` `Length`, and the rest of the string surface |
| `Convert` | `IntToStr` `UIntToStr` `IntToHex` `IntToBin` `IntToOct` and their inverses; `StrToInt` `StrToInt64` `StrToFloat` `StrToBool` plus a `...Def` default-valued form of each; `FloatToStr` `FloatToStrF` `BoolToStr`; `Ord` `Chr`; `FormatNumber` |
| `Console` | Colour constants (`clGreen`, `clReset`, ...); `ReadChar` `ReadLn` `Pause`; screen and line clearing; cursor movement and save/restore; `SetFgColor` `SetBgColor` `SetFgRGB` `SetBgRGB` `ResetColors` |
| `Paths` | `ExtractFilePath` `ExtractFileName` `ExtractFileExt` `ExtractFileDrive`; `ChangeFileExt` `ExpandFileName` `CanonicalPath` `RelativePath`; `CombinePath`; `IsAbsolutePath` `HasExtension` `HasFileName`; `GetCurrentDir` `SetCurrentDir` `GetTempDir` |
| `Files` | `TFileStream` plus `OpenRead` / `OpenWrite` / `OpenAppend` and their binary forms; `ReadLine` `WriteStr` `ReadBytes` `WriteBytes` `Seek` `FilePos` `FileSize` `Eof`; `ReadAllText` `WriteAllText` `ReadAllLines`; `FileExists` `DirectoryExists` `DeleteFile` `CopyFile` `CreateDir` `RemoveDir` |
| `DateTime` | `TDateTime`; `Now` `Date` `Time` `NowUTC`; `EncodeDate` / `DecodeDate` and the time equivalents; `YearOf` `MonthOf` `DayOf` `HourOf` ...; `IncDay` `IncMonth` `IncYear` ...; `DaysBetween` `SecondsBetween` ...; `IsLeapYear` `DaysInMonth` `DayOfWeek` `WeekOfYear`; `DateTimeToUnix` `UnixToDateTime` |
| `Geometry` | `TPoint` `TRect` `TSize` and their `float64` variants; constructors `Point` `Rect` `Bounds` `Size`; `RectWidth` `RectHeight` `IsRectEmpty` `RectCenter` `PtInRect` `EqualRect`; `OffsetRect` `InflateRect` `NormalizeRect` `IntersectRect` `UnionRect`; `Distance` |
| `Assertions` | `Assert` `AssertTrue` `AssertFalse`; `AssertEqual` / `AssertNotEqual` overloaded across `int64` `float64` `string` `boolean`; `AssertNil` `AssertNotNil`; `AssertInRange` `AssertGreater` `AssertLess` and their `OrEqual` forms; `Fail` `Pass` |

> [!NOTE]
> 📐 Nearly every standard library routine is **overloaded**. `Maths.Abs` has `int32`, `int64` and `float64` forms; `Convert.IntToStr` takes `int32` or `int64`; `Geometry.Rect` builds either a `TRect` or a `TRectF` depending on whether you hand it integers or floats. You do not pick the variant -- the argument types do.

A worked example, every line of it green in `test_exe_std`:

```myra
module exe test_exe_std;

import
  Maths,
  StrUtils,
  Console,
  Convert,
  Paths,
  DateTime,
  Files,
  Assertions,
  Geometry;

var
  LRect: Geometry.TRect;

begin
  println("Sqrt(4.0) = {}", Maths.Sqrt(4.0));                     // 2
  println("Abs(-5) = {}", Maths.Abs(-5));                         // 5
  println("Min(3, 7) = {}", Maths.Min(3, 7));                     // 3

  println("UpperCase(\"hello\") = {}", StrUtils.UpperCase("hello"));  // HELLO
  println("Trim(\"  x  \") = {}", StrUtils.Trim("  x  "));            // x
  println("Length(\"test\") = {}", StrUtils.Length("test"));          // 4

  println("{}Console test (green){}", Console.clGreen, Console.clReset);

  println("IntToStr(42) = {}", Convert.IntToStr(42));             // 42
  println("StrToInt(\"123\") = {}", Convert.StrToInt("123"));       // 123
  println("BoolToStr(true) = {}", Convert.BoolToStr(true));       // True

  println("ExtractFileExt(\"test.txt\") = {}", Paths.ExtractFileExt("test.txt"));  // .txt

  println("IsLeapYear(2024) = {}", int32(DateTime.IsLeapYear(2024)));        // 1
  println("DaysInMonth(2024, 2) = {}", DateTime.DaysInMonth(2024, 2));       // 29

  println("FileExists(...) = {}", int32(Files.FileExists("nonexistent.xyz"))); // 0

  LRect := Geometry.Rect(0, 0, 100, 50);
  println("RectWidth = {}", Geometry.RectWidth(LRect));           // 100

  Assertions.AssertTrue(true, "test");
  Assertions.AssertEqual(int64(1), int64(1), "test");
end.
```

Note `Geometry.TRect` in the `var` block: a **type** exported by a module is qualified exactly like a routine.

Because a `boolean` prints as `true`/`false`, the tests above cast to `int32` where a `1`/`0` is wanted. See **Output**.

### 🧰 Vendor Libraries

A third-party native library is wrapped by a **self-describing** Myra `lib` module. The wrapper owns every path it needs -- include path, library paths, link libraries, DLLs to copy -- gated per target with `@ifdef TARGET_*`. The compiler is told nothing about it, and neither is the language definition.

The consumer does exactly two things: point `@modulepath` at the folder, and `import` the wrapper.

```myra
module exe test_exe_raylib;

@modulepath "res/libs/vendor/raylib";

import
  raylib_import;

const
  CScreenWidth  = 800;
  CScreenHeight = 450;
begin
  InitWindow(CScreenWidth, CScreenHeight, "Raylib Window");
  SetTargetFPS(60);
  while not WindowShouldClose() do
    BeginDrawing();
      ClearBackground(RAYWHITE);
      DrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);
    EndDrawing();
  end;
  CloseWindow();
end.
```

`InitWindow`, `RAYWHITE`, `LIGHTGRAY` -- none of these are declared anywhere in Myra. They come from raylib's own C header, pulled in by the wrapper, and reach the call site through ordinary C++ passthrough.

#### What the wrapper looks like

This is the whole of `raylib_import.myra`:

```myra
module lib raylib_import;

// Self-describing vendor module: it owns every path it needs. The langdef
// knows nothing about raylib.
@includepath "res/libs/vendor/raylib/include";

@ifdef STATIC

  @ifdef TARGET_WIN64
    @librarypath "res/libs/vendor/raylib/win64/lib";
    @linklibrary "opengl32";
    @linklibrary "gdi32";
    @linklibrary "winmm";
  @elseif TARGET_LINUX64
    @librarypath "res/libs/vendor/linux64";
    @librarypath "res/libs/vendor/raylib/linux64/lib";
    @linklibrary "GL";
    @linklibrary "X11";
    @linklibrary "m";
    @linklibrary "pthread";
    @linklibrary "dl";
    @linklibrary "rt";
  @endif

@else

  @ifdef TARGET_WIN64
    @librarypath "res/libs/vendor/raylib/win64/bin";
    @copydll "res/libs/vendor/raylib/win64/bin/raylib.dll";
  @elseif TARGET_LINUX64
    @librarypath "res/libs/vendor/linux64";
    @librarypath "res/libs/vendor/raylib/linux64/bin";
    @copydll "res/libs/vendor/raylib/linux64/bin/libraylib.so.550";
  @endif

@endif

@linklibrary "raylib";

#include "raylib.h"

end.
```

Read it top to bottom and the whole mechanism is visible:

| Directive | Job |
|-----------|-----|
| `@includepath` | Where the C headers live |
| `@librarypath` | Where the linker should look |
| `@linklibrary` | Which library to link |
| `@copydll` | A runtime DLL to place beside the built executable |
| `#include "raylib.h"` | The actual declarations -- plain C++ passthrough |

`@ifdef STATIC` selects between a static and a dynamic build; `@ifdef TARGET_WIN64` / `@elseif TARGET_LINUX64` selects the platform. Exactly one `TARGET_*` symbol is defined per build (see **Directives**).

> [!NOTE]
> 🧩 **The compiler knows nothing about raylib.** Dropping a new vendor library into the tree requires no change to the compiler, no change to the `.mld` language definition, and no change to the consumer beyond one `@modulepath` and one `import`. This is what "self-describing" means: the library carries its own build configuration, in the same file that declares its API. Vendor wrappers for raylib and SDL3 ship in `res/libs/vendor/`.

> [!IMPORTANT]
> 🎯 `@ifdef` is resolved by the **lexer**, before the compiler runs. That is what lets a vendor module gate a **directive** -- a C++ `#ifdef` cannot, because by the time the C++ preprocessor runs the build is already configured. See [Build Directives](#build-directives).

### 🛡️ Exceptions

There is one protected-block construct: `guard`. It takes an optional `except` handler and an optional `finally` block, and **at least one of the two is required** -- a bare `guard ... end` is not a thing.

```
guard
  ... protected statements ...
except
  ... runs only if an exception was raised ...
finally
  ... runs always, exception or not ...
end;
```

| Form | Purpose |
|------|---------|
| `guard` ... `except` ... `end` | Catch |
| `guard` ... `finally` ... `end` | Clean up, do not catch |
| `guard` ... `except` ... `finally` ... `end` | Both. `except` first, then `finally`. |

#### The exception API

| Intrinsic | Purpose |
|-----------|---------|
| `raiseexception(msg)` | Raise with the default software code |
| `raiseexceptioncode(code, msg)` | Raise with an explicit integer code and message |
| `getexceptioncode()` | The code, valid inside an `except` block |
| `getexceptionmessage()` | The message, valid inside an `except` block |

```myra
guard
  raiseexception("Test error");
  println("Should not print");
except
  println("Exception caught: code={}, msg={}",
    getexceptioncode(), getexceptionmessage());
end;
// Exception caught: code=1, msg=Test error
```

A `raiseexception` gets the default software code, which is **1**. `raiseexceptioncode` sets it explicitly:

```myra
guard
  raiseexceptioncode(42, "Custom error");
except
  println("Custom code: {}, msg={}", getexceptioncode(), getexceptionmessage());
end;
// Custom code: 42, msg=Custom error
```

#### finally

`finally` runs whether or not an exception was raised. With no exception:

```myra
guard
  println("In guard block");
finally
  println("In finally block");
end;
println("After guard");
// In guard block
// In finally block
// After guard
```

With one, all three blocks run, in order:

```myra
guard
  println("In guard block");
  raiseexception("Error!");
except
  println("In except block: code={}", getexceptioncode());
finally
  println("In finally block");
end;
// In guard block
// In except block: code=1
// In finally block
```

#### Hardware exceptions

`guard` catches more than what Myra raises. A hardware trap -- division by zero, for instance -- arrives as an exception with its own code and message:

```myra
guard
  x := 10 div getZero();
  println("Should not print: {}", x);
except
  println("Hardware exception caught: code={}, msg={}",
    getexceptioncode(), getexceptionmessage());
end;
// Hardware exception caught: code=2, msg=Divide by zero
```

#### Nesting and propagation

`guard` blocks nest. An inner `except` that handles an exception stops it; an outer `finally` still runs.

```myra
guard
  guard
    raiseexception("Inner error");
  except
    println("Inner exception caught");
  end;
finally
  println("Outer finally");
end;
```

An exception raised inside a routine propagates out of it to the caller's `guard`:

```myra
routine throwingRoutine();
begin
  raiseexception("Propagated error");
end;

routine testPropagation();
begin
  guard
    throwingRoutine();
  except
    println("Caught propagated: code={}", getexceptioncode());
  end;
end;
```

#### Scope inside a guard

A `guard` body sees, reads and **writes** the enclosing scope -- locals, parameters, globals. Writes survive the block.

```myra
routine testLocalCapture();
var
  localVar: int32;
begin
  localVar := 100;
  guard
    println("Inside guard: localVar={}", localVar);
    localVar := 200;
  except
    println("Should not reach");
  end;
  println("After guard: localVar={}", localVar);   // 200
end;
```

> [!WARNING]
> 🚫 `guard` / `except` is a **hard compile error** on the `wasm32` target -- caught at compile time, with a source location, rather than emitted as C++ that clang would then reject. C++ exceptions are impossible on that toolchain: wasm builds run with `-fno-exceptions`. If a module must build for wasm, it cannot contain a `guard` block at all.

### 🎛️ Directives

Directives configure the build. Every one is introduced by `@` and, apart from the conditionals, terminated by `;`. They sit **after** the `module` line.

```myra
module exe test_exe_mixedmode;

@addverinfo on;
@vimajor 0;
@viminor 1;
@viproductname "Myra Demo";
@exeicon "res/assets/icons/myra.ico";
```

They fall into five groups:

| Group | Directives |
|-------|------------|
| **Build** | `@target` `@optimize` `@subsystem` `@unitTestMode` |
| **Conditional** | `@define` `@undef` `@ifdef` `@ifndef` `@elseif` `@else` `@endif` |
| **Paths and linking** | `@modulepath` `@includepath` `@librarypath` `@linklibrary` `@copydll` |
| **Version info and resources** | `@addverinfo` `@vimajor` `@viminor` `@vipatch` `@viproductname` `@videscription` `@vifilename` `@vicompanyname` `@vicopyright` `@exeicon` |
| **Diagnostics** | `@message` `@breakpoint` |

The complete reference, with the argument shape of every one, is in [Build Directives](#build-directives). `@target`, `@optimize` and `@subsystem` are also covered in [Getting Started](#getting-started).

#### Two conditional systems

Myra has `@ifdef`. C++ has `#if defined(...)`. **They are separate systems with separate symbol tables and they cannot see each other.**

| | `@ifdef` | `#if defined(...)` |
|---|---|---|
| Resolved by | Myra's **lexer**, before the compiler runs | The C++ preprocessor, after Myra has emitted |
| Symbols come from | `@define`, and the compiler's predefines | `-D` flags and `#define` |
| Can gate a **directive** | ✅ | ❌ |
| Can gate a statement | ✅ | ✅ |

That first row is the whole distinction. Because `@ifdef` runs in the lexer, it can decide *whether a `@linklibrary` line even exists* -- which is exactly how a vendor library configures its own linking per platform. `#if defined(...)` cannot: by the time it runs, the build is already configured and the link line is fixed.

#### Predefined symbols

| Symbol | When |
|--------|------|
| `MYRA` | **Always** defined |
| `TARGET_WIN64` | Target is `win64` |
| `TARGET_WINARM64` | Target is `winarm64` |
| `TARGET_LINUX64` | Target is `linux64` |
| `TARGET_LINUXARM64` | Target is `linuxarm64` |
| `TARGET_MACOS64` | Target is `macos64` |
| `TARGET_WASM32` | Target is `wasm32` |

**Exactly one** `TARGET_*` symbol is live in any given build. Selecting the target -- with `@target` or the CLI -- publishes the matching symbol, which is what makes `@ifdef TARGET_WIN64` work.

```myra
@ifdef TARGET_WIN64
  @librarypath "res/libs/vendor/raylib/win64/bin";
  @copydll "res/libs/vendor/raylib/win64/bin/raylib.dll";
@elseif TARGET_LINUX64
  @librarypath "res/libs/vendor/raylib/linux64/bin";
  @copydll "res/libs/vendor/raylib/linux64/bin/libraylib.so.550";
@endif
```

### 🧪 Unit Testing

Unit testing is **in the language**, not in a library. There is a `test` block, a family of assertion statements, and one directive to switch the whole thing on.

#### The shape

A `test` block is `test`, a name in quotes, an optional `var` block, and a body. Test blocks sit **after** the module's terminating `end.` -- they are not part of the module body.

```myra
module exe test_exe_unittest;

@unitTestMode on;

routine add(const A: int32; const B: int32): int32;
begin
  return A + B;
end;

routine isPositive(const A: int32): boolean;
begin
  return A > 0;
end;

begin
  println("Hello from test_exe_unittest!");
end.

test "Addition works correctly"
begin
  testAssertEqualInt(5, add(2, 3));
  testAssertEqualInt(0, add(-1, 1));
  testAssertEqualInt(0, add(0, 0));
end;

test "Boolean assertions"
begin
  testAssertTrue(isPositive(5));
  testAssertFalse(isPositive(-5));
  testAssertEqualBool(true, isPositive(1));
end;

test "Pointer assertions"
var
  p: pointer;
begin
  p := nil;
  testAssertNil(p);
end;

test "Deliberate failure"
begin
  testAssertEqualInt(1, 2);
end;
```

Note the third block: a `test` may declare its own locals in a `var` block between the name and the `begin`.

#### @unitTestMode

`@unitTestMode on;` is what makes the tests real. With it on, the compiler builds the `test` blocks and **replaces the normal entry point with the test runner** -- the module body is no longer what runs. Routines declared in the module remain available to the tests, which is the whole point: the tests exercise the module's own code.

#### Running

The runner prints one line per test, then a summary. A failure names the file and line, which the compiler injects automatically.

```
╔══════════════════════════════════════════════════════════════╗
║                     Unit Test Runner                         ║
╚══════════════════════════════════════════════════════════════╝

Running 5 test(s)...

✅ PASS: Addition works correctly
✅ PASS: Multiplication works correctly
✅ PASS: Boolean assertions
✅ PASS: Pointer assertions
❌ FAIL: Deliberate failure
  🔴 TestAssertEqualInt failed at test_exe_unittest.myra:86: expected 1, got 2
════════════════════════════════════════════════════════════════
Results: 4 passed, 1 failed, 5 total
════════════════════════════════════════════════════════════════
```

The process exits with a **non-zero exit code** when any test fails, so a test module drops straight into a build pipeline.

#### Assertion Family

Assertions are statements, not routines. Failures **accumulate** -- a failing assertion does not abort the test block, so one run reports every problem it finds rather than just the first.

| Form | Fails if |
|------|----------|
| `testAssert(expr)` | the expression is false |
| `testAssertTrue(expr)` | the expression is not true |
| `testAssertFalse(expr)` | the expression is not false |
| `testAssertNil(expr)` | the expression is not `nil` |
| `testAssertNotNil(expr)` | the expression is `nil` |
| `testFail("message")` | always -- unconditional failure |
| `testAssertEqualInt(expected, actual)` | signed integers differ |
| `testAssertEqualUInt(expected, actual)` | unsigned integers differ |
| `testAssertEqualFloat(expected, actual)` | floats differ |
| `testAssertEqualStr(expected, actual)` | strings differ |
| `testAssertEqualBool(expected, actual)` | booleans differ |
| `testAssertEqualPtr(expected, actual)` | pointers differ |

The `expected` value always comes **first**.

> [!NOTE]
> 🔤 Myra is case-sensitive and its keywords are lowercase, but the `testAssert*` forms carry the mixed case shown here. `testassertequalint` will not compile.

### 🌉 C++ Interop

Interop is not a feature bolted onto Myra. It is what Myra **is**. The surface compiles to modern **C++23**, and from that point the program is an ordinary C++ translation unit that the bundled zig/clang toolchain compiles and links. There is no FFI, no binding layer, no marshalling -- because there is no boundary. The code already *is* C++.

That gives the full interop matrix, in both directions:

| | Consume C / C++ | Produce for C / C++ |
|---|---|---|
| **Source level** | `#include` any header and call C/C++ functions directly; declare `external` symbols with a typed signature | your Myra-as-C++ shares one translation unit with any raw C++ you write inline |
| **Binary level** | link a `.lib` or load a `.dll` built by any modern C/C++ compiler and call it through `external` declarations | compile a `lib` / `dll` module into an artifact a C/C++ compiler links against, with `exported` controlling visibility |

#### Source level: raw C/C++ in the same file

`#include` goes **after** the `module` line, alongside the directives:

```myra
module exe HelloWorld;

#include <cstdio>

begin
  println("Hello, World!");
  printf("C++ passthrough: 2 + 3 = %d\n", 2 + 3);
end.
```

`printf` here is the real C `printf`. No `external` declaration, no binding layer, no import list -- the header was included, so the name exists.

> [!NOTE]
> 📄 A preprocessor line at **module level** is hoisted into the generated header. Inside a **body**, it stays in the generated source. You do not manage this; it is where the emitter puts it.

#### Calling C++ functions

Any C++ function reachable through an included header is callable directly in a Myra expression:

```myra
#include <cmath>
#include <cstring>

LX := std::abs(-42);          // 42
LX := std::max(10, 20);       // 20
LX := int32(strlen("hello")); // 5
LD := std::sqrt(16.0) * 2.0;  // Myra arithmetic on a C++ result
```

They compose with Myra control flow exactly as Myra expressions do:

```myra
for LI := std::abs(-3) downto 0 do
  print("{} ", LI);
end;

while std::abs(LX) < 1 do
  LX := 1;
end;
```

#### C++ types as Myra variables

A `var` declaration may name a C++ type. From that point the variable is an ordinary C++ object, and its methods are callable in Myra expressions:

```myra
#include <string>

var
  LS: std::string;
  LPos: size_t;

begin
  LS := "hello world";
  println("s.length() = {}", LS.length());   // 11

  if LS.empty() then
    println("empty");
  end;

  LPos := LS.find("world");
  if LPos <> std::string::npos then
    println("Found 'world' at position {}", LPos);   // 6
  end;

  println("Substring: {}", LS.substr(1, 3));
  LS.clear();
end.
```

Indexing works. Method chaining works. `std::string::npos` -- a qualified C++ constant -- works.

#### C++ memory, casts and templates

Myra's `create` / `destroy` manage a Myra `object`. C++ `new` / `delete` pass straight through and manage a C++ one. Both are available; they are not the same thing and do not mix.

```myra
LPCppInt := new int32_t(42);
println("value = {}", *LPCppInt);
delete LPCppInt;

LPCppVec := new std::vector<int32_t>();
LPCppVec->push_back(1);
println("size={}, first={}", LPCppVec->size(), (*LPCppVec)[0]);
delete LPCppVec;
```

Every C++ cast form passes through:

```myra
LPChar   := (char*)(&LBuffer[0]);                  // C-style
LPCppInt := reinterpret_cast<int32_t*>(LPVoid);    // reinterpret_cast
LX       := static_cast<int32_t>(LD);              // static_cast
```

#### Where the two languages meet

Myra keywords do not shadow C++ names inside a qualified C++ expression. `end` and `in` are Myra keywords; `std::ios::end` and `std::ios::in` are C++, and both resolve correctly:

```myra
LSeekDir  := std::ios::end;
LOpenMode := std::ios::in;
```

And a Myra keyword immediately following a C++ expression is still a Myra keyword:

```myra
if LS.length() > 0 then          // 'then' after a C++ method call
  println("passed");
end;

match int32(LS.length()) of      // 'of' after a C++ expression
  4: println("matched 4");
else
  println("no match");
end;
```

This is the passthrough rule doing its job: **if it is not Myra, it is C++, and it goes through verbatim.** Every line above is green in `test_exe_mixedmode`.

#### Binary level: ship and consume native libraries

Compile a `lib` or `dll` and any modern C/C++ compiler can link against it. `exported` marks what crosses the boundary; `clink` decides what the symbol is called when it gets there.

```myra
module dll test_dll_exports;

// Private helper - NOT exported
routine helper(const x: int32): int32;
begin
  return x * 2;
end;

exported routine clink add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

exported routine clink quadruple(const x: int32): int32;
begin
  return helper(helper(x));
end;

// A variable can be exported too
exported var version: int32 = 1;

end.
```

Going the other way, `external` binds a routine **or a variable** to a symbol that lives in a linked artifact. The consumer names the artifact, tells the linker where to find it, and declares the typed signature:

```myra
module exe test_exe_usedll;

@ifdef TARGET_LINUX64
@copydll "output/zig-out/lib/libtest_dll_exports.so";
@librarypath "output/zig-out/lib";
@elseif TARGET_WIN64
@librarypath "output/zig-out/bin";
@endif

@linklibrary "test_dll_exports";

routine clink add(const a: int32; const b: int32): int32; external "test_dll_exports";
routine clink add(const a: float32; const b: float32): float32; external "test_dll_exports";
routine clink quadruple(const x: int32): int32; external "test_dll_exports";

var version: int32; external "test_dll_exports";

var
  LIntResult: int32;
  LFloatResult: float32;

begin
  LIntResult := add(3, 5);
  println("{}", LIntResult);            // 8
  LFloatResult := add(3.0, 4.5);
  println("{:.1f}", LFloatResult);      // 7.5
  LIntResult := quadruple(4);
  println("{}", LIntResult);            // 16
  println("{}", version);               // 1
end.
```

The `external` declarations are **overloaded** on the consumer side too -- `add(int32, int32)` and `add(float32, float32)` coexist, and the call site picks by argument type. There is no `name` clause and no ordinal: the artifact string plus the typed signature is the whole binding.

> [!NOTE]
> 🔗 The linkage choice is inherited straight from C++, not a Myra quirk. **C linkage** (`clink`) is a stable, universal ABI: plain unmangled names that link cleanly against MSVC, gcc, or clang. **C++ linkage** (`cpplink`) is the **default**, and it is richer -- overloads, namespaces, classes -- but toolchain-bound, since name mangling, the exception ABI, and STL layout are all compiler- and version-specific. Overloading rides on mangling, so an overloaded routine cannot use C linkage: mark one `clink` and the compiler demotes it to `cpplink` with a warning. Choose per export where on that spectrum to sit. The artifact-level detail is in [Embedding and Scripting](#api-reference).

> [!TIP]
> 💡 Because Myra *is* C++ underneath, "what can it interoperate with?" has the same answer as "what can C++ interoperate with?" -- the entire C and C++ ecosystem, at both source and binary level, in both directions.

<a id="build-directives"></a>

## 🎛️ Build Directives

A directive is a compile-time instruction. It is prefixed with `@`, and every directive except the conditionals is terminated with `;`.

Directives are part of the source file, not command-line flags. A `.myra` file therefore carries its own build: the target, the optimization level, the libraries it links, the DLLs it ships beside, the icon it wears, and the version resource stamped into it. Hand someone the source and you have handed them the build.

```pascal
module exe MyApp;

@target win64;
@optimize releasefast;
@subsystem console;

begin
  println("Hello!");
end.
```

> [!IMPORTANT]
> 🧱 The build is fully described by the source. There are no project files and no makefiles. If you can read the file, you know how it builds.

<a id="directive-classes"></a>

### 🧬 Two Classes of Directive

Myra has twenty-eight directives, and they are not all handled at the same stage. Which stage a directive belongs to is the single most useful thing to know about it, because it decides what the directive is *able* to do.

| Class | Count | Handled by | Becomes an AST node? |
|-------|-------|-----------|----------------------|
| **Conditional** | 7 | The **lexer**, before parsing | ❌ No. The lexer either emits the guarded tokens or discards them. |
| **Build** | 21 | The **parser**, then forwarded to the build at emit time | ✅ Yes, one `stmt.directive_*` node each. |

The conditionals (`@define`, `@undef`, `@ifdef`, `@ifndef`, `@elseif`, `@else`, `@endif`) are consumed by the lexer and never reach the parser. Everything else is a real statement in the tree.

That split is why a conditional can wrap a build directive, and why the reverse can never be true. See [`@ifdef` Is Not `#if`](#ifdef-vs-if).

<a id="directive-forwarding"></a>

### 📡 What Each Directive Forwards To

Every one of the twenty-one build directives is a thin front end over a single build builtin. The parser captures the value into an attribute, and the emitter hands that attribute to the toolchain driver. Nothing is interpreted in between.

| Directive | Value token | Forwards to |
|-----------|-------------|-------------|
| `@target` | identifier, string, or components | `applyTarget` (in the module pre-scan, see below) |
| `@optimize` | identifier | `setOptimize(value)` |
| `@subsystem` | identifier | `setSubsystem(value)` |
| `@addverinfo` | identifier | `setAddVerInfo(value)` |
| `@vimajor` | integer | `setVersionMajor(value)` |
| `@viminor` | integer | `setVersionMinor(value)` |
| `@vipatch` | integer | `setVersionPatch(value)` |
| `@viproductname` | string | `setProductName(value)` |
| `@videscription` | string | `setDescription(value)` |
| `@vifilename` | string | `setFilename(value)` |
| `@vicompanyname` | string | `setCompanyName(value)` |
| `@vicopyright` | string | `setCopyright(value)` |
| `@exeicon` | string | `setExeIcon(value)` |
| `@copydll` | string | `addCopyDLL(value)` |
| `@linklibrary` | string | `addLinkLibrary(value)` |
| `@librarypath` | string | `addLibraryPath(value)` |
| `@modulepath` | string | `addModulePath(value)` |
| `@includepath` | string | `addIncludePath(value)` |
| `@breakpoint` | none | `addBreakpoint(file, line)` |
| `@message` | identifier + string | nothing at emit time (see [Diagnostics](#directive-message)) |
| `@unitTestMode` | identifier | nothing directly; read during the module pre-scan |

> [!NOTE]
> 🔎 The `set*` forms replace. The `add*` forms accumulate. So a second `@optimize` overwrites the first, while a second `@linklibrary` appends another library. Repeat `@linklibrary`, `@librarypath`, `@includepath`, `@modulepath` and `@copydll` freely.

`@modulepath` is the one directive that acts **twice**: once during semantic analysis, so that `import` can resolve modules along the new path, and again at emit time. It has to run early, because by the time code is emitted the imports have long since been resolved.

<a id="directive-placement"></a>

### 📍 Placement and Ordering

Build directives sit at module scope, after the `module` line and before the body:

```pascal
module exe MyApp;      // 1. module declaration

@target win64;         // 2. directives
@optimize releasefast;

import std;            // 3. imports

const                  // 4. declarations
  Greeting = "Hello";

begin                  // 5. body
  println(Greeting);
end.
```

Order within the directive block does not matter, with one exception worth understanding.

#### The Pre-Scan

Two directives are read **before any code is emitted**, in a pre-scan over the module's children:

| Directive | Why it must run first |
|-----------|----------------------|
| `@target` | The emitters query the selected platform to reject constructs the toolchain cannot support. The clearest case: `guard` / `except` is a hard error on `wasm32`. If the target were applied in source order, a `guard` inside a routine could be emitted *before* the directive was seen, the platform check would read an empty target, and the error would silently not fire. |
| `@unitTestMode` | The module body's entry point is rewritten when it is `on`, and every `test` block has to be numbered and registered. That decision has to be made before the body is emitted. |

The practical consequence: `@target` works no matter where in the module it appears. It is still good manners to put it first.

<a id="directive-build-config"></a>

### ⚙️ Build Configuration

#### `@target`

`@target` accepts three forms, all feeding the same underlying triple.

```pascal
@target win64;                    // curated alias, the everyday form
@target "win64";                  // the same alias, quoted, identical in effect
@target "x86_64-windows-gnu";     // raw triple, handed to zig verbatim
```

There are exactly six curated aliases. They are resolved in the compiler host, not in the language definition, because target resolution belongs where the toolchain is driven from.

| Alias | Triple | Can the compiler run the result? |
|-------|--------|----------------------------------|
| `win64` | `x86_64-windows-gnu` | ✅ natively |
| `winarm64` | `aarch64-windows-gnu` | ⚠️ warns |
| `linux64` | `x86_64-linux-gnu` | ✅ via WSL |
| `linuxarm64` | `aarch64-linux-gnu` | ⚠️ warns |
| `macos64` | `aarch64-macos-none` | ⚠️ warns |
| `wasm32` | `wasm32-wasi` | ✅ in your browser |

An unknown alias is rejected with a located error.

> [!NOTE]
> 🚀 Cross-compilation always works. Every target builds from every host, because zig carries the entire toolchain. What varies is only whether the compiler can *run* what it just built. `win64` (native), `linux64` (via WSL) and `wasm32` (the emitted self-contained HTML opens in a browser) auto-run. The other three warn. They never error.

> [!WARNING]
> 🕸️ `macos64` is Apple Silicon only, by design. And `wasm32` builds with `-fno-exceptions`, because C++ exceptions are impossible on that toolchain: `guard` / `except` is a **hard compile error** when targeting WebAssembly.

#### `@optimize`

```pascal
@optimize releasesmall;
```

| Value | Meaning |
|-------|---------|
| `debug` | No optimization, full debug info. The default when no `@optimize` is given. |
| `releasesafe` | Optimized, runtime safety checks retained. |
| `releasefast` | Optimized for speed. |
| `release` | An accepted alias for `releasefast`. |
| `releasesmall` | Optimized for size. |

The value is matched case-insensitively. A value outside this set is ignored and the level is left as it was.

#### `@subsystem`

```pascal
@subsystem gui;
```

| Value | Meaning |
|-------|---------|
| `console` | Console application. A console window is allocated. |
| `gui` | Windows GUI application. No console window. |

Matched case-insensitively. This shapes the Windows subsystem the linker stamps into the executable.

<a id="directive-verinfo"></a>

### 🏷️ Version Info

Embed a Windows version resource into the built executable. `@addverinfo on;` is the master switch. The rest are ignored without it.

| Directive | Value | Purpose |
|-----------|-------|---------|
| `@addverinfo` | identifier (`on` / `off`) | Enable the version resource |
| `@vimajor` | integer | Major version |
| `@viminor` | integer | Minor version |
| `@vipatch` | integer | Patch version |
| `@viproductname` | string | Product name |
| `@videscription` | string | File description |
| `@vifilename` | string | Original filename |
| `@vicompanyname` | string | Company name |
| `@vicopyright` | string | Copyright notice |

```pascal
@addverinfo on;
@vimajor 1;
@viminor 0;
@vipatch 0;
@viproductname "My Application";
@videscription "Does the thing";
@vifilename "myapp.exe";
@vicompanyname "tinyBigGAMES LLC";
@vicopyright "Copyright (c) 2026-present tinyBigGAMES LLC";
```

Note the value types: the three version numbers are bare **integers**, everything else is a **string**. `@addverinfo` takes a bare identifier, not a string and not a boolean literal.

<a id="directive-paths"></a>

### 🔗 Resources, Libraries, and Paths

| Directive | Value | Effect |
|-----------|-------|--------|
| `@exeicon` | string | Icon resource embedded into the executable |
| `@linklibrary` | string | Link against a native library, by base name |
| `@librarypath` | string | Add a library search path |
| `@includepath` | string | Add a C++ include search path |
| `@modulepath` | string | Add a `.myra` module search path for `import` |
| `@copydll` | string | Copy a shared library next to the built output |

```pascal
@exeicon "res/app.ico";
@includepath "res/libs/vendor/raylib/include";
@librarypath "res/libs/vendor/raylib/win64/bin";
@linklibrary "raylib";
@copydll "res/libs/vendor/raylib/win64/bin/raylib.dll";
```

`@linklibrary` takes the **base name**, not a filename: `"raylib"`, not `"raylib.lib"` or `"libraylib.so"`. The toolchain decorates it per target. `@copydll`, by contrast, takes a real path to a real file, because it is a file copy.

> [!TIP]
> 💡 `@linklibrary` plus an `external` routine declaration is the whole story for calling a native library. There is no binding generator and no FFI layer, because [C++ passthrough](#language-reference) means the C API was already reachable.

#### Self-Describing Modules

Because these directives accumulate and a `lib` module can carry them, a library can own every path it needs. The compiler ships no knowledge of any third-party library. The vendor module below declares its own include path, library paths, link libraries and DLLs, per target, and a consumer just imports it:

```pascal
module lib raylib_import;

// Self-describing vendor module: it owns every path it needs.
@includepath "res/libs/vendor/raylib/include";

@ifdef TARGET_WIN64
  @librarypath "res/libs/vendor/raylib/win64/bin";
  @copydll "res/libs/vendor/raylib/win64/bin/raylib.dll";
@elseif TARGET_LINUX64
  @librarypath "res/libs/vendor/linux64";
  @librarypath "res/libs/vendor/raylib/linux64/bin";
  @copydll "res/libs/vendor/raylib/linux64/bin/libraylib.so.550";
@endif

@linklibrary "raylib";

#include "raylib.h"

end.
```

That is the entire raylib binding: paths, libraries, per-target DLLs, and the C header passed through. This is the shipped `res/libs/vendor/raylib/raylib_import.myra`.

<a id="directive-debug"></a>

### 🐞 Debug and Diagnostics

#### `@breakpoint`

```pascal
@breakpoint;
```

Takes no value. It records a breakpoint at its own file and line, which the debugger picks up. Because it lives in the source, the breakpoint travels with the code instead of living in an editor's private state. See [Tools](#tools) for the debugger and the `.mbp` breakpoint sidecar.

#### `@unitTestMode`

```pascal
@unitTestMode on;
```

When `on`, the module's `test` blocks are compiled and registered, and the entry point is replaced by the test runner. When `off`, which is the default, `test` blocks are ignored entirely. See [Language Reference](#language-reference) for `test` blocks and the `testAssert*` family.

<a id="directive-message"></a>

#### `@message`

Emits a compile-time diagnostic at the severity you choose.

```pascal
@message hint  "consider the fast path here";
@message warn  "this routine is deprecated";
@message error "unsupported configuration";
@message fatal "cannot continue";
```

| Severity | Meaning |
|----------|---------|
| `hint` | Advisory. The build continues. |
| `warn` | Warning. The build continues. |
| `error` | The configuration is wrong. |
| `fatal` | Compilation cannot continue. |

The severity is a bare identifier and the text is a quoted string. Both are required, and the directive ends with a semicolon.

Paired with `@ifdef`, it is how a module refuses a configuration it does not support:

```pascal
@ifdef LEGACY_MODE
@message error "LEGACY_MODE is no longer supported";
@endif
```

<a id="directive-conditional"></a>

### 🧩 Conditional Compilation

Seven directives decide which source the compiler ever sees. They are resolved by the **lexer**, before parsing, so a discarded branch is not merely unemitted: it is never parsed and never has to be valid beyond its tokens.

| Directive | Takes | Effect |
|-----------|-------|--------|
| `@define` | symbol | Define a symbol |
| `@undef` | symbol | Remove a symbol |
| `@ifdef` | symbol | Keep the block if the symbol is defined |
| `@ifndef` | symbol | Keep the block if the symbol is **not** defined |
| `@elseif` | symbol | Alternative branch, tested only if no earlier branch was taken |
| `@else` | none | Fallback branch |
| `@endif` | none | Close the innermost conditional |

Note there is **no terminating semicolon** on a conditional. They are lexer directives, not statements.

#### What They Test

`@ifdef` tests **definedness only**. A symbol is defined or it is not. There are no values to compare, no expressions, no `and` / `or`, and no arithmetic. `@define` at the Myra level takes a bare symbol and nothing else:

```pascal
@define STATIC_BUILD          // correct
@define VERSION = 3           // not a thing. There is no value form here.
```

If you need a valued define, set it from the host API or the command line, where the `NAME=VALUE` form is understood.

#### Nesting

Conditionals nest to any depth. Each `@ifdef` pushes an entry recording whether its parent was already skipping and whether any branch in the chain has been taken, so an inner conditional inside a discarded outer block stays discarded regardless of its own symbol:

```pascal
@define OUTER
@define INNER

@ifdef OUTER
  @ifdef INNER
const
    NestedResult = "inner_true";
  @else
const
    NestedResult = "inner_false";
  @endif
@else
const
  NestedResult = "outer_false";
@endif
```

`@elseif` is tested only when no earlier branch in its chain has been taken, so exactly one branch of a chain survives, and possibly none.

#### A Complete Worked Example

Every conditional form in one module, this is the shipped `test_exe_conditional`:

```pascal
module exe test_exe_conditional;

@define FEATURE_A

@ifdef FEATURE_A
const
  FeatureAEnabled = "yes";
@else
const
  FeatureAEnabled = "no";
@endif

@ifdef FEATURE_B                // never defined
const
  FeatureBEnabled = "yes";
@else
const
  FeatureBEnabled = "no";
@endif

@ifndef UNDEFINED_SYMBOL
const
  IfndefResult = "undefined_symbol";
@else
const
  IfndefResult = "was_defined";
@endif

@define TEMP_SYMBOL
@undef TEMP_SYMBOL

@ifdef TEMP_SYMBOL
const
  UndefResult = "still_defined";
@else
const
  UndefResult = "was_undefined";
@endif

begin
  println("FEATURE_A={}", FeatureAEnabled);      // yes
  println("FEATURE_B={}", FeatureBEnabled);      // no
  println("IFNDEF_TEST={}", IfndefResult);       // undefined_symbol
  println("UNDEF_TEST={}", UndefResult);         // was_undefined
end.
```

Note that the conditionals here are gating **declarations**, not statements. Because the lexer resolves them, they can wrap anything: a declaration, a statement, a directive, a routine, or nothing at all.

<a id="predefined-symbols"></a>

#### Predefined Symbols

Two families are defined for you.

| Symbol | Defined when |
|--------|--------------|
| `MYRA` | **Always.** Use it in a shared source file to detect that Myra is the one compiling. |
| `TARGET_WIN64`, `TARGET_WINARM64`, `TARGET_LINUX64`, `TARGET_LINUXARM64`, `TARGET_MACOS64`, `TARGET_WASM32` | Exactly one, matching the selected target. |

The `TARGET_*` family is strictly exclusive. Selecting a target first clears all six and then defines the single one that matches, so a stale symbol from an earlier target can never satisfy two arms of the same chain. If the target is a raw triple that matches no curated alias, then **none** of the six is defined and every `@ifdef TARGET_*` is correctly false.

<a id="ifdef-vs-if"></a>

#### `@ifdef` Is Not `#if`

Myra has two conditional systems. They run at different times, against different symbol tables, and they are not interchangeable.

| | `@ifdef` | `#if` |
|---|---|---|
| Resolved by | The Myra **lexer** | The **C++ preprocessor** |
| Runs | **Before** the compiler | **After** the compiler, at the C++ stage |
| Reads | Myra's define table | The C++ macro table |
| Sees `@define`, `MYRA`, `TARGET_*` | ✅ Yes | ✅ Yes, see below |
| Sees `_WIN32`, `__linux__`, `__wasm__` | ❌ No | ✅ Yes |
| Can gate a directive | ✅ Yes | ❌ No |

> [!IMPORTANT]
> 🔁 **Myra's defines flow one way into C++.** Every Myra define is passed to the C++ compiler as a `-DNAME` flag, so `@define FEATURE_A` is visible to a later `#if defined(FEATURE_A)`, and so are `MYRA` and the live `TARGET_*`. The reverse is **not** true: the toolchain's own platform macros exist only inside the C++ preprocessor, and `@ifdef` cannot see them. It is a one-way mirror, not two sealed rooms.

**So which do you reach for?**

Use `#if` for **platform detection**. The toolchain already defines the real macros for whichever target it was pointed at, and Myra deliberately does not maintain a hand-written mirror of them. With sixty architectures and forty-five operating systems, such a list would be a lie waiting to happen.

Use `@ifdef` when the decision has to be made **before the build is configured**. This is the part a C++ `#if` structurally cannot do. `@librarypath`, `@linklibrary` and `@copydll` shape the build itself, and by the time the C++ preprocessor runs, the build is already configured, the libraries are already chosen, and the compile is already underway. Only a lexer-stage conditional can reach that decision in time. That is exactly why the raylib module above gates its `@linklibrary` lines with `@ifdef TARGET_WIN64` and not with `#if defined(_WIN32)`.

Both systems in one module, this is the shipped `test_exe_target`:

```pascal
module exe test_exe_target;

@target "win64";

begin
  // Myra level: our own define table, resolved before the compiler runs.
@ifdef MYRA
  println("MYRA defined: yes");
@else
  println("MYRA defined: no");
@endif

  // C++ passthrough: the toolchain's macros for the selected target.
#if defined(_WIN32)
  println("_WIN32 defined: yes");
#else
  println("_WIN32 defined: no");
#endif

#if defined(__wasm__)
  println("__wasm__ defined: yes");
#else
  println("__wasm__ defined: no");
#endif
end.
```

Built for `win64`, that prints `yes`, `yes`, `no`.

<a id="directive-recipes"></a>

### 🍳 Recipes

**Ship a release build with a version resource and an icon.**

```pascal
module exe MyApp;

@target win64;
@optimize releasefast;
@subsystem gui;

@exeicon "res/app.ico";

@addverinfo on;
@vimajor 2;
@viminor 1;
@vipatch 0;
@viproductname "My Application";
@videscription "Does the thing";
@vifilename "MyApp.exe";
@vicompanyname "tinyBigGAMES LLC";
@vicopyright "Copyright (c) 2026-present tinyBigGAMES LLC";

begin
  println("shipping");
end.
```

**Link a different library per platform.**

```pascal
@ifdef TARGET_WIN64
  @linklibrary "opengl32";
  @linklibrary "gdi32";
  @linklibrary "winmm";
@elseif TARGET_LINUX64
  @linklibrary "GL";
  @linklibrary "X11";
  @linklibrary "m";
  @linklibrary "pthread";
@endif
```

**Guard code that cannot exist on a target.** `guard` / `except` is a hard error on `wasm32`, so gate it at the Myra level, before the emitter ever sees it:

```pascal
@ifndef TARGET_WASM32
  guard
    Risky();
  except
    println("recovered");
  end
@endif
```

**Compile a module's tests instead of its program.**

```pascal
module exe test_exe_unittest;

@unitTestMode on;

test "arithmetic"
  testAssertEqual(2 + 2, 4);
end
```

# Myra Language Grammar

Grammar in EBNF (ISO/IEC 14977).

Notation: `,` concatenation, `|` alternation, `{ }` zero or more,
`[ ]` optional, `( )` grouping, `"..."` literal source text. Non-terminals
are lowercase words. This file is the surface-syntax contract: it describes
what the programmer writes.

Myra is case-sensitive. All keywords are lowercase. Statements are terminated
by `;`. Bodies are delimited by `begin` ... `end`; control-flow constructs
carry their own terminating `end` and do not take a `begin`.

## 1. Program and Modules

```ebnf
program         = module ;
module          = "module" , module kind , identifier , ";" ,
                  { directive } ,
                  [ import clause ] ,
                  { declaration } ,
                  [ module body ] ,
                  "end" , "." ,
                  { test block } ;

module kind     = "exe" | "dll" | "lib" ;
import clause   = "import" , identifier , { "," , identifier } , ";" ;
module body     = "begin" , statement sequence ;
```

- `exe` emits an executable, `dll` a shared library, `lib` a static library.
- Test blocks follow the terminating `end.` of the module.

## 2. Directives

Every directive is introduced by `@`.

```ebnf
directive       = conditional directive | build directive ;

conditional directive
                = "@define" , identifier
                | "@undef" , identifier
                | "@ifdef" , identifier
                | "@ifndef" , identifier
                | "@elseif" , identifier
                | "@else"
                | "@endif" ;

build directive = "@optimize" , identifier , ";"
                | "@subsystem" , identifier , ";"
                | "@target" , target spec , ";"
                | "@addverinfo" , identifier , ";"
                | "@unitTestMode" , identifier , ";"
                | "@vimajor" , integer , ";"
                | "@viminor" , integer , ";"
                | "@vipatch" , integer , ";"
                | "@viproductname" , cstring , ";"
                | "@videscription" , cstring , ";"
                | "@vifilename" , cstring , ";"
                | "@vicompanyname" , cstring , ";"
                | "@vicopyright" , cstring , ";"
                | "@exeicon" , cstring , ";"
                | "@copydll" , cstring , ";"
                | "@linklibrary" , cstring , ";"
                | "@librarypath" , cstring , ";"
                | "@modulepath" , cstring , ";"
                | "@includepath" , cstring , ";"
                | "@breakpoint" , ";"
                | "@message" , severity , cstring , ";" ;

target spec     = identifier
                | cstring
                | target component , "," , target component ,
                  [ "," , target component ] ;
target component
                = identifier | cstring ;
severity        = "hint" | "warn" | "error" | "fatal" ;
```

- `@target` takes a curated alias (`win64`, `winarm64`, `linux64`,
  `linuxarm64`, `macos64`, `wasm32`), a raw triple as a string, or
  arch/os/abi components.

## 3. Declarations

```ebnf
declaration     = var block | const block | type block
                | routine decl | exported decl ;

exported decl   = "exported" , declaration ;

var block       = "var" , { var decl } ;
var decl        = identifier , ":" , type expr , [ "=" , expression ] , ";" ,
                  [ external clause ] ;

const block     = "const" , { const decl } ;
const decl      = identifier , [ ":" , type expr ] , "=" , expression , ";" ;

routine decl    = "routine" , [ linkage ] , identifier ,
                  [ param list ] , [ ":" , type expr ] , ";" ,
                  ( external clause | routine body ) ;

routine body    = { var block | const block | type block } , block , ";" ;

method decl     = "method" , identifier , [ param list ] ,
                  [ ":" , type expr ] , ";" ,
                  { var block } , block , ";" ;

linkage         = "clink" | "cpplink" ;
external clause = "external" , [ cstring | identifier ] , ";" ;

param list      = "(" , [ params ] , ")" ;
params          = "..." | param , { ";" , param } , [ "..." ] ;
param           = [ "var" | "const" ] , identifier , ":" , type expr ;
```

- `cpplink` is the default. `clink` selects C linkage (`extern "C"`, unmangled).
- C linkage cannot express overloads; an overloaded routine is demoted to
  `cpplink` with a warning.
- A trailing `...` marks the routine variadic; `varargs` reads the arguments.
- `external` replaces a body and binds an externally linked symbol.

## 4. Types

```ebnf
type block      = "type" , { type decl } ;
type decl       = identifier , "=" , type def , ";" ;

type def        = record type | object type | overlay type | choices type
                | array type | pointer type | set type | routine type
                | alias type ;

alias type      = identifier ;

record type     = "record" , [ "(" , identifier , ")" ] ,
                  [ "packed" ] , [ "align" , "(" , integer , ")" ] ,
                  { field decl | anon overlay } , "end" ;

object type     = "object" , [ "(" , identifier , ")" ] ,
                  { field decl | method decl } , "end" ;

overlay type    = "overlay" , { field decl | anon record } , "end" ;

anon record     = "record" , [ "packed" ] ,
                  { field decl | anon overlay } , "end" , ";" ;
anon overlay    = "overlay" , { field decl | anon record } , "end" , ";" ;

field decl      = identifier , ":" , type expr , [ ":" , integer ] , ";" ;

choices type    = "choices" , "(" , choice value ,
                  { "," , choice value } , ")" ;
choice value    = identifier , [ "=" , expression ] ;

array type      = "array" , [ "[" , [ expression , ".." , expression ] , "]" ] ,
                  "of" , type expr ;

pointer type    = "pointer" , [ "to" , [ "const" ] , type expr ] ;

set type        = "set" , [ "of" , ( integer , ".." , integer | type expr ) ] ;

routine type    = "routine" , [ linkage ] , param list ,
                  [ ":" , type expr ] ;

type expr       = builtin type | identifier | pointer type | array type ;

builtin type    = "int8"  | "int16"  | "int32"  | "int64"
                | "uint8" | "uint16" | "uint32" | "uint64"
                | "float32" | "float64"
                | "boolean" | "char" | "wchar"
                | "string" | "wstring"
                | "pointer" | "set" ;
```

- A field's trailing `: integer` is a bitfield width.
- `record` and `object` may name a parent type in parentheses.
- Unrecognized type text passes through verbatim to C++ (see section 10).

## 5. Statements

```ebnf
statement sequence
                = { statement } , "end" ;

block           = "begin" , { statement } , "end" ;

statement       = block
                | if stmt | while stmt | for stmt | repeat stmt | match stmt
                | guard stmt
                | return stmt | leave stmt | skip stmt
                | memory stmt | exception stmt | io stmt | assert stmt
                | var block | const block | type block
                | expression statement ;

if stmt         = "if" , expression , "then" , { statement } ,
                  [ "else" , { statement } ] , "end" , [ ";" ] ;

while stmt      = "while" , expression , "do" , { statement } , "end" , [ ";" ] ;

for stmt        = "for" , identifier , ":=" , expression ,
                  ( "to" | "downto" ) , expression , "do" ,
                  { statement } , "end" , [ ";" ] ;

repeat stmt     = "repeat" , { statement } , "until" , expression , [ ";" ] ;

match stmt      = "match" , expression , "of" , { match arm } ,
                  [ "else" , { statement } ] , "end" , [ ";" ] ;
match arm       = match label , { "," , match label } , ":" , { statement } ;
match label     = expression , [ ".." , expression ] ;

guard stmt      = "guard" , { statement } ,
                  [ "except" , { statement } ] ,
                  [ "finally" , { statement } ] ,
                  "end" , [ ";" ] ;

return stmt     = "return" , [ expression ] , [ ";" ] ;
leave stmt      = "leave" , [ ";" ] ;
skip stmt       = "skip" , [ ";" ] ;

expression statement
                = expression , [ ";" ] ;
```

- Assignment is an expression (see section 6): `:=` `+=` `-=` `*=` `/=`.
- `leave` exits the innermost loop or match; `skip` advances to the next
  iteration.
- `guard` requires at least one of `except` or `finally`.

## 6. Expressions

```ebnf
expression      = assign expr ;

assign expr     = or expr , [ assign op , assign expr ] ;
assign op       = ":=" | "+=" | "-=" | "*=" | "/=" ;

or expr         = and expr , { "or" , and expr } ;
and expr        = rel expr , { ( "and" | "xor" ) , rel expr } ;
rel expr        = add expr , { rel op , add expr } ;
rel op          = "=" | "<>" | "<" | ">" | "<=" | ">=" | "in" | "is" ;

add expr        = shift expr , { ( "+" | "-" ) , shift expr } ;
shift expr      = mul expr , { ( "shl" | "shr" ) , mul expr } ;
mul expr        = unary expr ,
                  { ( "*" | "/" | "div" | "mod" ) , unary expr } ;

unary expr      = [ "not" | "-" | "+" | "address" , "of" ] , postfix expr ;

postfix expr    = primary expr , { postfix op } ;
postfix op      = "(" , [ arg list ] , ")"
                | "[" , expression , "]"
                | "." , identifier
                | "^" ;
arg list        = expression , { "," , expression } ;

primary expr    = integer | float | cstring | wstring | cchar
                | "true" | "false" | "nil"
                | "self" | "parent"
                | identifier
                | varargs expr
                | type cast
                | pointer cast
                | set literal
                | intrinsic call
                | "(" , expression , ")" ;

type cast       = builtin type , "(" , expression , ")" ;

pointer cast    = "pointer" , "to" , [ "const" ] , type expr ,
                  "(" , expression , ")" ;

set literal     = "[" , [ set element , { "," , set element } ] , "]" ;
set element     = expression , [ ".." , expression ] ;

varargs expr    = "varargs" , [ "." , "count"
                              | "." , "next" , "(" , type expr , ")" ] ;
```

Binding power, tightest last:

| Power | Operators |
|---|---|
| 2 | `:=` `+=` `-=` `*=` `/=` (right associative) |
| 6 | `or` |
| 8 | `and` `xor` |
| 10 | `=` `<>` `<` `>` `<=` `>=` `in` `is` |
| 20 | `+` `-` (binary) |
| 25 | `shl` `shr` |
| 30 | `*` `/` `div` `mod` |
| 35 | `not` `-` `+` `address of` (prefix) |
| 40 | call `( )` |
| 45 | index `[ ]`, field `.` |
| 50 | deref `^` (postfix) |

## 7. Intrinsics

```ebnf
intrinsic call  = "len" , "(" , expression , ")"
                | "size" , "(" , type expr , ")"
                | "utf8" , "(" , expression , ")"
                | "paramcount" , "(" , ")"
                | "paramstr" , "(" , expression , ")"
                | "getmem" , "(" , expression , ")"
                | "resizemem" , "(" , expression , "," , expression , ")"
                | "getexceptioncode" , "(" , ")"
                | "getexceptionmessage" , "(" , ")" ;

memory stmt     = "create" , "(" , expression , ")" , [ ";" ]
                | "destroy" , "(" , expression , ")" , [ ";" ]
                | "getmem" , "(" , expression , ")" , [ ";" ]
                | "freemem" , "(" , expression , ")" , [ ";" ]
                | "resizemem" , "(" , expression , "," , expression , ")" , [ ";" ]
                | "setlength" , "(" , expression , "," , expression , ")" , [ ";" ] ;

exception stmt  = "raiseexception" , "(" , expression , ")" , [ ";" ]
                | "raiseexceptioncode" , "(" , expression , "," ,
                  expression , ")" , [ ";" ] ;

io stmt         = ( "print" | "println" ) , "(" , [ arg list ] , ")" , [ ";" ] ;
```

- `getmem` and `resizemem` are usable as expressions and as statements.
- `create` / `destroy` construct and destruct an `object` instance.

## 8. Unit Testing

```ebnf
test block      = "test" , cstring , [ var block ] , block , [ ";" ] ;

assert stmt     = assert1 , "(" , expression , ")" , [ ";" ]
                | assert2 , "(" , expression , "," , expression , ")" , [ ";" ] ;

assert1         = "testAssert" | "testAssertTrue" | "testAssertFalse"
                | "testAssertNil" | "testAssertNotNil" | "testFail" ;

assert2         = "testAssertEqualInt"   | "testAssertEqualUInt"
                | "testAssertEqualFloat" | "testAssertEqualStr"
                | "testAssertEqualBool"  | "testAssertEqualPtr" ;
```

## 9. Lexical

```ebnf
identifier      = letter , { letter | digit | "_" } ;
letter          = "A" .. "Z" | "a" .. "z" | "_" ;
digit           = "0" .. "9" ;
hex digit       = digit | "A" .. "F" | "a" .. "f" ;

integer         = decimal | hexadecimal ;
decimal         = digit , { digit } ;
hexadecimal     = ( "0x" | "0X" ) , hex digit , { hex digit } ;
float           = digit , { digit } , "." , digit , { digit } ;

cstring         = '"' , { character | escape } , '"' ;
wstring         = 'w"' , { character | escape } , '"' ;
cchar           = "'" , ( character | escape ) , "'" ;
escape          = "\" , character ;

comment         = line comment | block comment ;
line comment    = "//" , { character } , newline ;
block comment   = "/*" , { character } , "*/" ;
```

- Myra is case-sensitive. Keywords are lowercase; the `testAssert*` forms
  carry their documented mixed case.

## 10. C++ Passthrough

There is no escape-hatch syntax. Any token Myra does not recognize is emitted
verbatim to the generated C++.

```ebnf
passthrough     = cpp preprocessor | cpp declaration | cpp expression ;

cpp preprocessor
                = "#" , { character } , newline ;

cpp declaration = identifier , identifier , { raw token } , ";" ;
```

- A C++ preprocessor line at module level is hoisted to the generated header;
  inside a body it stays in the generated source.
- Two adjacent identifiers begin a C++ declaration and are collected raw.
- C++ keywords, operators and qualified names are recognized by the engine and
  passed through without a Myra production.

<a id="langdef-system"></a>

## 🧬 Langdef System

Most compilers are sealed. The grammar lives in generated tables, the type rules live in hand-written passes, and the code generator is a wall of string building buried in the source. If you want to change the language, you fork the compiler.

Myra is not built that way. **The language is defined by `.mld` files that ship as plain text beside the compiler.** The tokens, the type system, the grammar, the semantic rules, and the C++23 emitters are all readable, editable definition files. The engine loads them at startup, populates its dispatch tables, and then compiles your `.myra` source with whatever those files say the language is.

Change an `.mld` file and you have changed the language. That is the third pillar.

> [!IMPORTANT]
> 🔓 This is not a plugin API or an extension point. There is no privileged "real" grammar hidden underneath. The `.mld` files **are** Myra. Everything the compiler knows about the language, it read from them.

This section is a complete reference for **MLD**, the Myra Language Definition format. It is written so you can build a language with it, not merely admire that it exists.

### 🗂️ Section Contents

| Part | Covers |
|------|--------|
| [The Engine and the Pipeline](#mld-engine) | What MLD is, how the two phases work, the eight files |
| [File Structure](#mld-file-structure) | The `language` declaration and every top-level construct |
| [Tokens Block](#mld-tokens) | Keywords, operators, comments, strings, directives, lexer config |
| [Types Block](#mld-types) | Type keywords, C++ mappings, literal types, the compatibility matrix |
| [Grammar Block](#mld-grammar) | Pratt parsing: prefix, infix, statement rules, binding powers |
| [Semantics Block](#mld-semantics) | Scopes, symbols, multi-pass analysis |
| [Emitters Block](#mld-emitters) | Statement and expression emission, headers, directives |
| [The Imperative Language](#mld-imperative) | Variables, control flow, operators, interpolation, diagnostics |
| [Routines, Constants, Enums](#mld-routines) | User-defined helpers |
| [Fragments, Imports, Guards](#mld-fragments) | Reuse and conditional inclusion |
| [Built-in Function Reference](#mld-builtins) | Every builtin, by context |
| [Formal Grammar (EBNF)](#mld-ebnf) | The complete MLD meta-grammar |

<a id="mld-engine"></a>

### ⚙️ The Engine and the Pipeline

MLD is the meta-language used to define Myra. An `.mld` file describes a **complete compiler pipeline**: lexer tokens, Pratt parser grammar, multi-pass semantic analysis, and code generation. The engine reads the `.mld` files, populates its internal dispatch tables, and then uses those tables to compile `.myra` source into C++23, which the bundled zig/clang toolchain builds into a native binary.

Compilation happens in two phases:

| Phase | What Happens |
|-------|--------------|
| **Setup** | The `.mld` files are parsed. Their contents populate dispatch tables: token registrations, grammar rules, semantic handlers, emitter handlers, user-defined routines. |
| **Compile** | Those tables drive a generic lexer, a Pratt parser, a semantic analyzer, and a code generator, which process `.myra` source and produce C++23. |

Nothing about Myra is hard-coded into the engine. The engine is a machine that runs language definitions. Myra is one such definition.

#### The Eight Files

Myra's definition lives in `bin/res/language/`. `myra.mld` is the root; it imports the rest.

| File | Purpose |
|------|---------|
| `myra.mld` | Root: language declaration, imports, defines, module paths |
| `myra_tokens.mld` | Token declarations and the type system |
| `myra_utils.mld` | Shared utilities (target alias resolution) |
| `myra_helpers.mld` | Shared routines (`resolveType`, `collectTypeText`, `buildRoutineSig`) |
| `myra_grammar.mld` | Grammar rules: prefix, infix, and statement |
| `myra_semantics.mld` | Semantic analysis handlers |
| `myra_emitters.mld` | C++23 code generation handlers |
| `myra_targets.mld` | Target arch / os / abi tags and validators (**generated**) |

> [!NOTE]
> 🧩 There is no host-language glue. No C, no Python, no build-system integration, no escape hatch out of MLD into "the real compiler." An `.mld` file is a complete, self-contained, portable language specification.

<a id="mld-file-structure"></a>

### 📄 File Structure

An `.mld` file begins with a `language` declaration and contains top-level blocks. Comments use `//` (line) and `/* ... */` (block).

```mld
language Myra version "1.0";

// Constants must appear before they are referenced.
const {
  ENABLE_OVERLOADS    = true;
  ENABLE_FORWARD_REFS = true;
}

// Conditional-compilation symbols visible to @ifdef in .myra source.
setDefine("MYRA");

// Where `import` in .myra source looks for modules.
addModulePath("res/libs/std");

// Load the rest of the definition.
import "myra_tokens.mld";
import "myra_utils.mld";
import "myra_helpers.mld";
import "myra_grammar.mld";
import "myra_semantics.mld";
import "myra_emitters.mld";

tokens    { /* keywords, operators, delimiters, strings, directives, config */ }
types     { /* type keywords, C++ mappings, compatibility matrix */ }
grammar   { /* prefix, infix, and statement rules */ }
semantics { /* scope, declare, visit */ }
emitters  { /* code generation */ }

// Reusable helpers, callable from any handler.
routine resolveType(typeText: string) -> string {
  if typeText == "int32" { return "int32_t"; }
  return typeText;
}
```

Every top-level construct:

| Construct | Description |
|-----------|-------------|
| `language Name version "X.Y";` | Language declaration. **Required, must be first.** |
| `tokens { ... }` | Token declarations and lexer configuration |
| `types { ... }` | Type system configuration |
| `grammar { ... }` | Parser grammar rules |
| `semantics { ... }` | Semantic analysis handlers |
| `emitters { ... }` | Code generation handlers |
| `const { ... }` | Named constants |
| `enum Name { ... }` | Enum declaration |
| `routine name(...) -> t { ... }` | User-defined routine |
| `fragment name { ... }` | Reusable declaration block |
| `import "file.mld";` | Load an external `.mld` file |
| `include fragmentName;` | Expand a fragment |
| `guard EXPR { ... }` | Conditional inclusion |

Each block feeds one stage of the pipeline:

| Block | Drives | Answers |
|-------|--------|---------|
| `tokens` | The lexer | What words and symbols exist? |
| `types` | The type system | What is `int32`, and what C++ does it become? |
| `grammar` | The Pratt parser | How do tokens become an AST? |
| `semantics` | The analyzer | Is this program meaningful? |
| `emitters` | The code generator | What C++23 comes out? |

<a id="mld-tokens"></a>

### 🔤 Tokens Block

The `tokens {}` block teaches the lexer how to break source into meaningful pieces. Every declaration follows one pattern:

```mld
token category.name = "text" [flags];
```

The category prefix determines how the token is registered with the engine.

| Category | Description |
|----------|-------------|
| `keyword.*` | Reserved word |
| `op.*` | Operator |
| `delimiter.*` | Punctuation |
| `comment.line` | Line-comment prefix |
| `comment.block_open` / `comment.block_close` | Block-comment delimiters |
| `string.*` | String literal style |
| `directive.*` | Named directive |

#### Keywords

Once declared, the lexer emits the specified token kind instead of `identifier`. These words can never be used as variable or routine names.

```mld
tokens {
  casesensitive = true;

  // Module structure
  token keyword.module    = "module";
  token keyword.import    = "import";
  token keyword.exported  = "exported";
  token keyword.external  = "external";

  // Linkage. cpplink is the DEFAULT; clink selects C linkage.
  token keyword.clink     = "clink";
  token keyword.cpplink   = "cpplink";

  // Control flow
  token keyword.begin     = "begin";
  token keyword.end       = "end";
  token keyword.if        = "if";
  token keyword.then      = "then";
  token keyword.else      = "else";
  token keyword.while     = "while";
  token keyword.do        = "do";
  token keyword.for       = "for";
  token keyword.to        = "to";
  token keyword.downto    = "downto";
  token keyword.repeat    = "repeat";
  token keyword.until     = "until";
  token keyword.match     = "match";
  token keyword.return    = "return";
  token keyword.leave     = "leave";
  token keyword.skip      = "skip";

  // Declarations
  token keyword.var       = "var";
  token keyword.const     = "const";
  token keyword.type      = "type";
  token keyword.routine   = "routine";
  token keyword.method    = "method";

  // Type definitions
  token keyword.record    = "record";
  token keyword.object    = "object";
  token keyword.overlay   = "overlay";
  token keyword.choices   = "choices";
  token keyword.packed    = "packed";
  token keyword.align     = "align";
  token keyword.array     = "array";
  token keyword.of        = "of";
  token keyword.set       = "set";
  token keyword.pointer   = "pointer";

  // Word operators
  token keyword.and       = "and";
  token keyword.or        = "or";
  token keyword.not       = "not";
  token keyword.xor       = "xor";
  token keyword.div       = "div";
  token keyword.mod       = "mod";
  token keyword.shl       = "shl";
  token keyword.shr       = "shr";
  token keyword.in        = "in";
  token keyword.is        = "is";

  // Output intrinsics
  token keyword.print     = "print";
  token keyword.println   = "println";

  // Literals
  token keyword.true      = "true";
  token keyword.false     = "false";
  token keyword.nil       = "nil";
}
```

Want `func` instead of `routine`? Change one string.

> [!WARNING]
> ⚠️ `keyword.is` is **declared** in `myra_tokens.mld` but has **no grammar production**. It lexes, and then nothing consumes it. The same is true of `op.pipe` (`|`) and `op.ampersand` (`&`). These are reserved for future use. Do not build on them.

#### Operators and Delimiters

The engine sorts operators by length internally so longest-match wins (`:=` matches before `:`). Declaring multi-character operators first is documentation, not a requirement.

```mld
tokens {
  // Multi-character
  token op.assign       = ":=";
  token op.plus_assign  = "+=";
  token op.minus_assign = "-=";
  token op.mul_assign   = "*=";
  token op.div_assign   = "/=";
  token op.neq          = "<>";
  token op.lte          = "<=";
  token op.gte          = ">=";
  token op.ellipsis     = "...";
  token op.range        = "..";

  // Single-character
  token op.eq           = "=";
  token op.lt           = "<";
  token op.gt           = ">";
  token op.plus         = "+";
  token op.minus        = "-";
  token op.multiply     = "*";
  token op.divide       = "/";
  token op.deref        = "^";

  // Delimiters
  token delimiter.lparen    = "(";
  token delimiter.rparen    = ")";
  token delimiter.lbracket  = "[";
  token delimiter.rbracket  = "]";
  token delimiter.comma     = ",";
  token delimiter.colon     = ":";
  token delimiter.semicolon = ";";
  token delimiter.dot       = ".";
}
```

#### Comments

Line comments use `comment.line`. Block comments require a matched open/close pair. Multiple styles may be declared.

```mld
tokens {
  token comment.line        = "//";
  token comment.block_open  = "/*";
  token comment.block_close = "*/";
}
```

#### String Styles

With no flags, a string style processes backslash escapes (`\n`, `\t`, `\\`) and uses its pattern text as both the opening and the closing delimiter.

```mld
tokens {
  token string.cstring = "\"";                  // "..."
  token string.wstring = "w\"" [close "\""];    // w"..." closes on "
}
```

| Flag | Description |
|------|-------------|
| `noescape` | Disable backslash escapes. Two consecutive close delimiters mean one literal close delimiter (the Pascal `''` convention). |
| `close "X"` | Use `X` as the closing delimiter instead of the opening pattern. |

#### Directives

Directives are a **two-tier system**. Conditional-compilation directives are consumed by the **lexer** at lex time and never reach the parser. Every other directive is passed through as a regular token for a `stmt.directive_*` grammar rule to consume.

```mld
tokens {
  directive_prefix = "@";

  // Tier 1: consumed by the lexer
  token directive.define  = "define" [define];
  token directive.undef   = "undef"  [undef];
  token directive.ifdef   = "ifdef"  [ifdef];
  token directive.ifndef  = "ifndef" [ifndef];
  token directive.elseif  = "elseif" [elseif];
  token directive.else    = "else"   [else];
  token directive.endif   = "endif"  [endif];

  // Tier 2: passed to the parser as tokens
  token directive.target        = "target";
  token directive.optimize      = "optimize";
  token directive.subsystem     = "subsystem";
  token directive.exeicon       = "exeicon";
  token directive.copydll       = "copydll";
  token directive.linklibrary   = "linklibrary";
  token directive.librarypath   = "librarypath";
  token directive.modulepath    = "modulepath";
  token directive.includepath   = "includepath";
  token directive.breakpoint    = "breakpoint";
  token directive.message       = "message";
  token directive.unittestmode  = "unitTestMode";
  // ... plus the version-info family
}
```

| Flag | Meaning |
|------|---------|
| `define` | This token is `@define` |
| `undef` | This token is `@undef` |
| `ifdef` | This token is `@ifdef` |
| `ifndef` | This token is `@ifndef` |
| `elseif` | This token is `@elseif` |
| `else` | This token is `@else` |
| `endif` | This token is `@endif` |

> [!IMPORTANT]
> 🧱 This is why Myra has **two** conditional systems that look alike but are not. `@ifdef` is a Myra-level directive resolved by the lexer against a compile-time symbol table. `#if defined(...)` is a C++ preprocessor line that passes straight through to the generated C++ and is resolved by clang. They do not see each other's symbols.

#### Structural Configuration

Key-value assignments inside `tokens {}` configure the engine.

```mld
tokens {
  casesensitive = true;
  terminator    = delimiter.semicolon;
  block_open    = keyword.begin;
  block_close   = keyword.end;
  hex_prefix    = "0x";
  hex_prefix    = "0X";
}
```

| Setting | Description |
|---------|-------------|
| `casesensitive = true/false;` | Keyword matching case sensitivity |
| `identifier_start = "chars";` | Characters that may start an identifier |
| `identifier_part = "chars";` | Characters that may continue an identifier |
| `terminator = kind;` | Statement terminator token kind |
| `block_open = kind;` | Block-open token kind |
| `block_close = kind;` | Block-close token kind |
| `directive_prefix = "text";` | Directive prefix characters |
| `hex_prefix = "text";` | Hex literal prefix (repeatable) |
| `binary_prefix = "text";` | Binary literal prefix |

<a id="mld-types"></a>

### 🔢 Types Block

The `types {}` block connects three worlds: the **source type name** the user writes, the **internal type kind** the engine tracks, and the **C++ type** that comes out the far end. When a user writes `var x : int32;`, the types block says that `int32` is `type.int32` internally, and that `type.int32` becomes `int32_t` in C++.

#### Type Keywords

Map source type names to internal type kind strings.

```mld
types {
  type int8     = "type.int8";
  type int16    = "type.int16";
  type int32    = "type.int32";
  type int64    = "type.int64";
  type uint8    = "type.uint8";
  type uint16   = "type.uint16";
  type uint32   = "type.uint32";
  type uint64   = "type.uint64";
  type float32  = "type.float32";
  type float64  = "type.float64";
  type boolean  = "type.boolean";
  type char     = "type.char";
  type wchar    = "type.wchar";
  type string   = "type.string";
  type wstring  = "type.wstring";
  type pointer  = "type.pointer";
  type set      = "type.set";
}
```

#### Type Mappings

Map internal type kinds to C++ output types.

```mld
types {
  map "type.int8"    -> "int8_t";
  map "type.int16"   -> "int16_t";
  map "type.int32"   -> "int32_t";
  map "type.int64"   -> "int64_t";
  map "type.uint8"   -> "uint8_t";
  map "type.uint16"  -> "uint16_t";
  map "type.uint32"  -> "uint32_t";
  map "type.uint64"  -> "uint64_t";
  map "type.float32" -> "float";
  map "type.float64" -> "double";
  map "type.boolean" -> "bool";
  map "type.char"    -> "char";
  map "type.wchar"   -> "wchar_t";
  map "type.string"  -> "std::string";
  map "type.wstring" -> "std::wstring";
  map "type.pointer" -> "void*";
  map "type.set"     -> "MyrSet";
}
```

This is the whole of "Myra's `int32` is C++'s `int32_t`." It is one line of editable text, not a compiler pass.

#### Literal Type Mappings

Connect AST node kinds produced by the parser to type kinds understood by the type system. Without these, a literal has no type.

```mld
types {
  literal "expr.integer" = "type.int32";
  literal "expr.float"   = "type.float64";
  literal "expr.cstring" = "type.cstring";
  literal "expr.cchar"   = "type.char";
  literal "expr.wstring" = "type.wstring";
  literal "expr.bool"    = "type.boolean";
}
```

#### Type Compatibility

Each `compatible` entry declares a source type, a target type, and the type the pair coerces to. This is how widening and promotion are defined. There is no built-in numeric tower; the matrix *is* the tower.

```mld
types {
  // Signed widening
  compatible "type.int8",  "type.int16" -> "type.int16";
  compatible "type.int8",  "type.int32" -> "type.int32";
  compatible "type.int16", "type.int32" -> "type.int32";
  compatible "type.int32", "type.int64" -> "type.int64";

  // Unsigned widening
  compatible "type.uint8",  "type.uint16" -> "type.uint16";
  compatible "type.uint16", "type.uint32" -> "type.uint32";
  compatible "type.uint32", "type.uint64" -> "type.uint64";

  // Float widening
  compatible "type.float32", "type.float64" -> "type.float64";

  // Integer to float promotion
  compatible "type.int32", "type.float64" -> "type.float64";

  // nil is assignable to any pointer
  compatible "type.nil", "type.pointer";

  // Character to string promotion
  compatible "type.char",  "type.string"  -> "type.string";
  compatible "type.wchar", "type.wstring" -> "type.wstring";
}
```

When the `->` coercion target is omitted, it defaults to the target type.

#### Declaration and Call Kinds

Tell the semantic engine which node kinds are declarations and which are calls, and where a call node stores its callee name.

```mld
types {
  decl_kind "stmt.var_decl";
  call_kind "expr.call";
  call_name_attr = "call.name";
}
```

| Entry | Description |
|-------|-------------|
| `decl_kind "kind";` | Register a declaration node kind |
| `call_kind "kind";` | Register a call node kind |
| `call_name_attr = "attr";` | Attribute holding the callee name on call nodes |

<a id="mld-grammar"></a>

### 🌳 Grammar Block

The `grammar {}` block turns a token stream into an AST. The engine runs a **Pratt parser**: every token can trigger a **prefix** handler (at the start of an expression), an **infix** handler (between two expressions), or a **statement** handler (at statement position).

Which one a rule becomes is decided by its node-kind prefix and whether it declares a precedence.

| Rule Shape | Registered As | Trigger |
|------------|---------------|---------|
| `rule expr.*` (no precedence) | Prefix | Its first `expect` / `consume` token |
| `rule expr.* precedence left N` | Infix, left-associative | Its first `expect` / `consume` token |
| `rule expr.* precedence right N` | Infix, right-associative | Its first `expect` / `consume` token |
| `rule stmt.*` | Statement | Its first `expect` / `consume` token |

#### Declarative Rule Vocabulary

Inside a rule body, these forms are declarative shorthand. Anything they cannot express, you write imperatively (see [The Imperative Language](#mld-imperative)); the two mix freely in one body.

| Syntax | Description |
|--------|-------------|
| `expect TOKEN_KIND;` | Assert the current token is `TOKEN_KIND` and consume it. Error if it is not. |
| `consume TOKEN_KIND -> @attr;` | Consume the token and store its text as an attribute on the result node. |
| `consume [K1, K2, ...] -> @attr;` | Consume if the current token is any of the listed kinds; store its text. |
| `parse expr -> @attr;` | Parse a sub-expression at binding power 0 and add it as a child. |
| `parse many stmt until KIND -> @attr;` | Parse statements until `KIND`; collect them into a block child. |
| `optional { ... }` | Execute the block only if the next token permits it. |
| `sync TOKEN_KIND;` | Declare an error-recovery point. |

#### Prefix Rules

Prefix rules fire when their trigger token appears at expression-start position: literals, identifiers, unary operators, grouped expressions, set literals.

```mld
grammar {
  // Literals
  rule expr.integer { consume literal.integer -> @value; }
  rule expr.float   { consume literal.float   -> @value; }
  rule expr.cstring { consume string.cstring  -> @value; }
  rule expr.wstring { consume string.wstring  -> @value; }

  // Keyword literals
  rule expr.nil  { expect keyword.nil; }
  rule expr.bool { consume keyword.true  -> @value; }
  rule expr.bool { consume keyword.false -> @value; }

  // Identifier
  rule expr.ident { consume identifier -> @name; }

  // Grouped expression
  rule expr.grouped {
    expect delimiter.lparen;
    parse expr -> @inner;
    expect delimiter.rparen;
  }

  // Unary operators bind at power 35
  rule expr.not {
    expect keyword.not;
    let nd = getResultNode();
    addChild(nd, parseExpr(35));
  }
  rule expr.negate {
    expect op.minus;
    let nd = getResultNode();
    addChild(nd, parseExpr(35));
  }

  // Set literal: [a, b, x..y]
  rule expr.set_literal {
    expect delimiter.lbracket;
    let nd = getResultNode();
    if not checkToken("delimiter.rbracket") {
      let elem = createNode("expr.set_element");
      addChild(elem, parseExpr(0));
      if matchToken("op.range") {
        addChild(elem, parseExpr(0));
      }
      addChild(nd, elem);
      while matchToken("delimiter.comma") {
        let e2 = createNode("expr.set_element");
        addChild(e2, parseExpr(0));
        if matchToken("op.range") {
          addChild(e2, parseExpr(0));
        }
        addChild(nd, e2);
      }
    }
    requireToken("delimiter.rbracket");
  }
}
```

> [!WARNING]
> ⚠️ The generic lexer produces `literal.integer` and `literal.float` tokens automatically, but the parser will **not** consume them without explicit prefix rules. Omit `rule expr.integer` and every numeric expression in your language fails to parse. This is the single most common mistake when starting a new `.mld`.

#### Intrinsics as Prefix Rules

Myra's intrinsics (`len`, `size`, `utf8`, `paramcount`, `paramstr`, `getmem`, `resizemem`, and the exception accessors) are not library functions. They are prefix rules that build an `expr.call` node with `call.name` pre-set, so the emitter sees an ordinary call.

```mld
grammar {
  rule expr.call {
    expect keyword.len;
    let nd = getResultNode();
    setAttr(nd, "call.name", "myr_len");
    parseCallArgs(nd);
  }

  rule expr.call {
    expect keyword.size;
    let nd = getResultNode();
    setAttr(nd, "call.name", "sizeof");
    requireToken("delimiter.lparen");
    setAttr(nd, "call.sizeof_type", currentText());
    advance();
    requireToken("delimiter.rparen");
  }
}
```

#### Infix Rules

An infix rule fires when its trigger token appears *after* an already-parsed left expression. That left operand becomes **child 0** of the result node. Binding power decides grouping: `2 + 3 * 4` groups as `2 + (3 * 4)` because `*` (30) binds tighter than `+` (20).

```mld
grammar {
  // Assignment: right-associative, power 2
  rule expr.assign precedence right 2 {
    consume [op.assign, op.plus_assign, op.minus_assign,
             op.mul_assign, op.div_assign] -> @operator;
    parse expr -> @right;
  }

  // Arithmetic
  rule expr.binary precedence left 20 {
    consume [op.plus, op.minus] -> @operator;
    parse expr -> @right;
  }
  rule expr.binary precedence left 30 {
    consume [op.multiply, op.divide] -> @operator;
    parse expr -> @right;
  }
  rule expr.binary precedence left 30 {
    consume [keyword.div, keyword.mod] -> @operator;
    parse expr -> @right;
  }

  // Comparison
  rule expr.binary precedence left 10 {
    consume [op.eq, op.neq, op.lt, op.gt, op.lte, op.gte] -> @operator;
    parse expr -> @right;
  }

  // Logical
  rule expr.binary precedence left 8 {
    consume [keyword.and, keyword.xor] -> @operator;
    parse expr -> @right;
  }

  // Call: power 40
  rule expr.call precedence left 40 {
    expect delimiter.lparen;
    let nd = getResultNode();
    let left = getChild(nd, 0);
    if nodeKind(left) == "expr.ident" {
      setAttr(nd, "call.name", getAttr(left, "name"));
    }
    if not checkToken("delimiter.rparen") {
      addChild(nd, parseExpr(0));
      while matchToken("delimiter.comma") {
        addChild(nd, parseExpr(0));
      }
    }
    requireToken("delimiter.rparen");
  }

  // Array index: power 45
  rule expr.array_index precedence left 45 {
    expect delimiter.lbracket;
    let nd = getResultNode();
    addChild(nd, parseExpr(0));
    requireToken("delimiter.rbracket");
  }

  // Field access: power 45
  rule expr.field_access precedence left 45 {
    expect delimiter.dot;
    let nd = getResultNode();
    setAttr(nd, "field.name", currentText());
    advance();
  }
}
```

#### Binding Power Scale

| Power | Category |
|-------|----------|
| 2 | Assignment (right-associative) |
| 6 | Logical `or` |
| 8 | Logical `and`, `xor` |
| 10 | Comparison (`=`, `<>`, `<`, `>`, `<=`, `>=`) and set membership (`in`) |
| 20 | Addition, subtraction |
| 25 | Bit shift (`shl`, `shr`) |
| 30 | Multiplication, division, `div`, `mod` |
| 35 | Unary prefix (`not`, negate, address-of) |
| 40 | Call |
| 45 | Array index, field access |
| 50 | Dereference |

> [!TIP]
> 💡 The precedence ladder in the [BNF Grammar](#myra-language-grammar) is not documentation *about* the parser. It is a reading of the numbers written in `myra_grammar.mld`. Change a number there and the ladder moves.

#### Statement Rules

Statement rules fire at statement position. They are where a language's shape actually lives.

```mld
grammar {
  // if <expr> then <stmts> [else <stmts>] end
  rule stmt.if {
    expect keyword.if;
    let nd = getResultNode();
    addChild(nd, parseExpr(0));
    requireToken("keyword.then");

    let thenBranch = createNode("stmt.then_branch");
    while not checkToken("keyword.else") and not checkToken("keyword.end")
          and not checkToken("eof") {
      let s = parseStmt();
      if s != nil { addChild(thenBranch, s); }
    }
    addChild(nd, thenBranch);

    if matchToken("keyword.else") {
      let elseBranch = createNode("stmt.else_branch");
      while not checkToken("keyword.end") and not checkToken("eof") {
        let s = parseStmt();
        if s != nil { addChild(elseBranch, s); }
      }
      addChild(nd, elseBranch);
    }

    requireToken("keyword.end");
    matchToken("delimiter.semicolon");
  }

  // while <expr> do <stmts> end
  rule stmt.while {
    expect keyword.while;
    let nd = getResultNode();
    addChild(nd, parseExpr(0));
    requireToken("keyword.do");
    while not checkToken("keyword.end") and not checkToken("eof") {
      let s = parseStmt();
      if s != nil { addChild(nd, s); }
    }
    requireToken("keyword.end");
    matchToken("delimiter.semicolon");
  }

  // for <ident> := <expr> (to|downto) <expr> do <stmts> end
  rule stmt.for {
    expect keyword.for;
    let nd = getResultNode();
    setAttr(nd, "for.var", currentText());
    advance();
    requireToken("op.assign");
    addChild(nd, parseExpr(0));
    if checkToken("keyword.to") {
      setAttr(nd, "for.dir", "to");
      advance();
    } else {
      requireToken("keyword.downto");
      setAttr(nd, "for.dir", "downto");
    }
    addChild(nd, parseExpr(0));
    requireToken("keyword.do");
    while not checkToken("keyword.end") and not checkToken("eof") {
      let s = parseStmt();
      if s != nil { addChild(nd, s); }
    }
    requireToken("keyword.end");
    matchToken("delimiter.semicolon");
  }

  // var { ident : type [= expr]; }
  rule stmt.var_block {
    expect keyword.var;
    let nd = getResultNode();
    while checkToken("identifier") {
      let nameTok = currentText();
      advance();
      let v = createNode("stmt.var_decl");
      setAttr(v, "var.name", nameTok);
      requireToken("delimiter.colon");
      setAttr(v, "var.type_text", collectTypeText());
      if matchToken("op.eq") {
        addChild(v, parseExpr(0));
      }
      requireToken("delimiter.semicolon");
      addChild(nd, v);
    }
  }
}
```

#### Linkage: How `clink` Is Parsed

Linkage is a **keyword**, not a string. `cpplink` is the default and is stamped before any check, so an absent linkage spec still produces a well-formed attribute.

```mld
grammar {
  rule stmt.routine_decl {
    expect keyword.routine;
    let nd = getResultNode();

    // Default first, then override if a spec is present.
    setAttr(nd, "decl.linkage", "cpplink");
    if checkToken("keyword.clink") {
      setAttr(nd, "decl.linkage", "clink");
      advance();
    } else if checkToken("keyword.cpplink") {
      setAttr(nd, "decl.linkage", "cpplink");
      advance();
    }

    setAttr(nd, "decl.name", currentText());
    advance();

    // Parameters, return type, `external`, or a body follow.
  }
}
```

#### The Myra Rule Catalog

What follows is the complete set of rules Myra actually registers. It is the language's surface, enumerated.

**Prefix expressions:** `expr.integer`, `expr.float`, `expr.cstring`, `expr.cchar`, `expr.wstring`, `expr.nil`, `expr.bool`, `expr.ident`, `expr.self`, `expr.parent`, `expr.varargs`, `expr.not`, `expr.negate`, `expr.unary_plus`, `expr.address_of`, `expr.grouped`, `expr.set_literal`, `expr.pointer_cast`, plus the intrinsics that parse to `expr.call` (`len`, `size`, `utf8`, `paramcount`, `paramstr`, `getmem`, `resizemem`, `getexceptioncode`, `getexceptionmessage`).

**Infix expressions:** `expr.assign` (2, right), `expr.binary` (6 / 8 / 10 / 20 / 30), `expr.shl` and `expr.shr` (25), `expr.in` (10), `expr.call` (40), `expr.array_index` (45), `expr.field_access` (45), `expr.deref` (50).

**Statements:**

| Group | Rules |
|-------|-------|
| Module | `stmt.module`, `stmt.exported` |
| Declarations | `stmt.var_block`, `stmt.const_block`, `stmt.type_block`, `stmt.routine_decl`, `stmt.method_decl` |
| Blocks | `stmt.begin_block`, `stmt.expr`, `stmt.self_expr`, `stmt.parent_expr` |
| Control flow | `stmt.if`, `stmt.while`, `stmt.for`, `stmt.repeat`, `stmt.match`, `stmt.return`, `stmt.leave`, `stmt.skip` |
| Exceptions | `stmt.guard`, `stmt.raiseexception`, `stmt.raiseexceptioncode` |
| Memory | `stmt.create`, `stmt.destroy`, `stmt.getmem`, `stmt.freemem`, `stmt.resizemem`, `stmt.setlength` |
| Output | `stmt.print`, `stmt.println` |
| Testing | `stmt.test_block`, `stmt.testassert`, `stmt.testasserttrue`, `stmt.testassertfalse`, `stmt.testassertnil`, `stmt.testassertnotnil`, `stmt.testfail`, `stmt.testassertequalint`, `stmt.testassertequaluint`, `stmt.testassertequalfloat`, `stmt.testassertequalstr`, `stmt.testassertequalbool`, `stmt.testassertequalptr` |
| Directives | `stmt.directive_target`, `stmt.directive_optimize`, `stmt.directive_subsystem`, `stmt.directive_exeicon`, `stmt.directive_copydll`, `stmt.directive_linklibrary`, `stmt.directive_librarypath`, `stmt.directive_modulepath`, `stmt.directive_includepath`, `stmt.directive_breakpoint`, `stmt.directive_message`, `stmt.directive_unittestmode`, `stmt.directive_addverinfo`, `stmt.directive_vimajor`, `stmt.directive_viminor`, `stmt.directive_vipatch`, `stmt.directive_viproductname`, `stmt.directive_videscription`, `stmt.directive_vifilename`, `stmt.directive_vicompanyname`, `stmt.directive_vicopyright` |

> [!NOTE]
> 🖨️ There is no `writeln`. Myra's output statements are `print` and `println`, which lower to `std::print` and `std::println`.

<a id="mld-semantics"></a>

### 🧠 Semantics Block

The `semantics {}` block decides whether a syntactically valid program is *meaningful*. Handlers walk the AST, push and pop scopes, declare and look up symbols, and raise diagnostics. An `on` handler fires once per node of the matching kind.

#### Declarative Vocabulary

| Syntax | Description |
|--------|-------------|
| `scope "name" { ... }` | Push a named scope, run the body, pop it |
| `scope @attr { ... }` | Push a scope named by an attribute's value |
| `declare @attr as variable;` | Declare a symbol as a variable |
| `declare @attr as routine;` | Declare a symbol as a routine |
| `declare @attr as type;` | Declare a symbol as a type |
| `declare @attr as constant;` | Declare a symbol as a constant |
| `declare @attr as parameter;` | Declare a symbol as a parameter |
| `declare @attr as KIND typed @type;` | Declare with type information attached |
| `visit children;` | Visit every child of the current node |
| `visit @attr;` | Visit the child named by an attribute |
| `visit child[N];` | Visit the child at index N |
| `lookup @attr -> let sym;` | Look a symbol up and bind it to a variable |
| `lookup @attr or { ... };` | Look a symbol up; run the block if it is not found |

#### Basic Handlers

```mld
semantics {
  on program.root {
    scope "global" {
      visit children;
    }
  }

  // Module: the module kind decides the build mode.
  on stmt.module {
    let kind = getAttr(node, "module.kind");
    if kind == "exe" { setBuildMode("exe"); }
    else if kind == "lib" { setBuildMode("lib"); }
    else if kind == "dll" { setBuildMode("dll"); }

    let mname = getAttr(node, "module.name");
    setAttr(node, "mname", mname);
    scope @mname {
      visit children;
    }
  }

  // Variable declaration.
  on stmt.var_decl {
    setAttr(node, "vname", getAttr(node, "var.name"));
    setAttr(node, "vtype", getAttr(node, "var.type_text"));
    declare @vname as variable typed @vtype;
    visit children;
  }

  on expr.assign { visit children; }
  on expr.call   { visit children; }
  on expr.binary { visit children; }
  on expr.ident  { }
}
```

#### Imports Trigger Compilation

An import is not a file-inclusion. The semantic handler *recursively compiles the imported module*, with the parent's build configuration saved and restored around it so the child cannot corrupt it.

```mld
semantics {
  on stmt.import_item {
    let iname = getAttr(node, "import.name");
    setAttr(node, "iname", iname);
    setAttr(node, "itype", "module");

    pushBuildState();          // protect the parent's config
    setModuleExtension("myra");
    compileModule(iname);      // recursive compile
    popBuildState();           // restore it

    declare @iname as variable typed @itype;
  }
}
```

#### Overload Detection and Linkage Demotion

C has no name mangling, so a `clink` routine cannot be overloaded. When Myra sees a second routine with a name it already knows, it **demotes** the linkage to `cpplink` and warns, rather than emitting C++ that will not link.

```mld
semantics {
  on stmt.routine_decl {
    let rname = getAttr(node, "decl.name");

    // Build a signature key: "Name(type1,type2)"
    let sig = rname + "(";
    let first = true;
    let pi = 0;
    while pi < child_count() {
      let pch = getChild(node, pi);
      if nodeKind(pch) == "stmt.param_decl" {
        if not first { sig = sig + ","; }
        sig = sig + getAttr(pch, "param.type_text");
        first = false;
      }
      pi = pi + 1;
    }
    sig = sig + ")";

    // If this name already exists, every version of it must be C++-linked.
    if symbolExistsWithPrefix(rname + "(") {
      demoteCLinkageForPrefix(rname + "(");
      warning("clink demoted to cpplink for previously declared overload(s) of '" + rname + "'");
    }
    if getAttr(node, "decl.linkage") == "clink" {
      setAttr(node, "decl.linkage", "cpplink");
      warning("clink demoted to cpplink for overloaded routine '" + rname + "'");
    }

    setAttr(node, "sig", sig);
    declare @sig as routine;
    scope @rname {
      visit children;
    }
  }
}
```

#### Multi-Pass Semantics

Forward references need more than one walk. A `pass` block scopes a set of handlers to a single pass. Each pass walks the whole AST with only that pass's handlers active. The **scope tree persists** across passes; the scope *stack* resets to the root between them. So pass 1 can declare every routine, and pass 2 can resolve calls to routines declared later in the file.

```mld
semantics {
  pass 1 "declarations" {
    on stmt.routine_decl {
      declare @name as routine;
    }
  }

  pass 2 "analysis" {
    on expr.ident {
      lookup @name or {
        error "undefined identifier '{@name}'";
      };
    }
  }
}
```

#### What Myra's Semantic Layer Actually Does

| Feature | Mechanism |
|---------|-----------|
| **Overload detection** | Builds a `Name(type,type)` signature key and checks for an existing name prefix; demotes `clink` to `cpplink` when a collision is found. |
| **Module compilation** | `stmt.import_item` calls `compileModule()` between `pushBuildState()` / `popBuildState()`. |
| **Pointer access detection** | `expr.field_access` tests whether the left side is a pointer (directly, through a type alias, or through a call's return type) and stamps `pointer_access = "true"` so the emitter writes `->` instead of `.`. This is why Myra source uses a plain `.` through a pointer. |
| **Float literal stamping** | `expr.assign` propagates the target type down into float literals on the right-hand side, so overload resolution picks the right one. |
| **Variadic call detection** | `expr.call` looks for a `__va:` marker symbol and stamps the call as variadic. |

<a id="mld-emitters"></a>

### ⚙️ Emitters Block

The `emitters {}` block produces the C++23. Two kinds of handler:

- **Statement emitters** write lines with `emitLine()`.
- **Expression emitters** produce a string fragment with `emit`, which composes recursively through `exprToString()`.

#### Statement Emitters

```mld
emitters {
  on stmt.if {
    let cond = exprToString(getChild(node, 0));
    emitLine("if (" + cond + ") {");
    indentIn();
    emitNode(getChild(node, 1));         // then branch
    indentOut();
    if child_count() > 2 {
      emitLine("} else {");
      indentIn();
      emitNode(getChild(node, 2));       // else branch
      indentOut();
    }
    emitLine("}");
  }

  on stmt.while {
    let cond = exprToString(getChild(node, 0));
    emitLine("while (" + cond + ") {");
    indentIn();
    let wi = 1;
    while wi < child_count() {
      emitNode(getChild(node, wi));
      wi = wi + 1;
    }
    indentOut();
    emitLine("}");
  }

  on stmt.for {
    let varName    = getAttr(node, "for.var");
    let startExpr  = exprToString(getChild(node, 0));
    let finishExpr = exprToString(getChild(node, 1));
    let dir        = getAttr(node, "for.dir");

    if dir == "to" {
      emitLine("for (auto " + varName + " = " + startExpr +
               "; " + varName + " <= " + finishExpr +
               "; ++" + varName + ") {");
    } else {
      emitLine("for (auto " + varName + " = " + startExpr +
               "; " + varName + " >= " + finishExpr +
               "; --" + varName + ") {");
    }
    indentIn();
    // body children
    indentOut();
    emitLine("}");
  }

  on stmt.println {
    // lowers to std::println(...)
    emitLine("std::println(" + args + ");");
  }
}
```

#### Expression Emitters

`emit` hands a fragment back to whoever called `exprToString()`. This is where Myra's operator words become C++ symbols.

```mld
emitters {
  on expr.binary {
    let lhs = exprToString(getChild(node, 0));
    let rhs = exprToString(getChild(node, 1));
    let op  = getAttr(node, "operator");

    if      op == "="   { op = "=="; }
    else if op == "<>"  { op = "!="; }
    else if op == "div" { op = "/";  }
    else if op == "mod" { op = "%";  }
    else if op == "and" { op = "&&"; }
    else if op == "or"  { op = "||"; }
    else if op == "xor" { op = "^";  }

    emit "(" + lhs + " " + op + " " + rhs + ")";
  }

  on expr.assign {
    let lhs = exprToString(getChild(node, 0));
    let rhs = exprToString(getChild(node, 1));
    let op  = getAttr(node, "operator");
    if op == ":=" { op = "="; }
    emit lhs + " " + op + " " + rhs;
  }

  on expr.ident   { emit @name; }
  on expr.integer { emit @value; }
  on expr.nil     { emit "nullptr"; }
  on expr.self    { emit "this"; }
  on expr.parent  { emit "Super"; }
  on expr.cstring { emit "\"" + @value + "\""; }
  on expr.wstring { emit "L\"" + @value + "\""; }

  on expr.bool {
    let val = getAttr(node, "value");
    if val == "true" { emit "true"; } else { emit "false"; }
  }
}
```

Myra's `mod` becomes C++'s `%`, and `nil` becomes `nullptr`, because a line of editable text says so. Nothing is compiled into the compiler.

#### Header vs Source Emission

The emitter keeps two output buffers. Source is the default; pass `"header"` as a second argument to write to the header file instead. This is how `lib` and `dll` modules get a usable `.h`.

```mld
emitters {
  on stmt.module {
    emitLine("#include <cstdint>", "header");
    emitLine("#include <string>",  "header");

    emitLine("#include <cstdint>");
    emitLine("#include <string>");
  }
}
```

#### Directive Emitters

Directive emitters are the bridge from source-level `@directives` to the build pipeline. Each is a one-liner that forwards to a pipeline builtin.

```mld
emitters {
  on stmt.directive_optimize    { setOptimize(getAttr(node, "value")); }
  on stmt.directive_subsystem   { setSubsystem(getAttr(node, "value")); }
  on stmt.directive_exeicon     { setExeIcon(getAttr(node, "value")); }
  on stmt.directive_copydll     { addCopyDLL(getAttr(node, "value")); }
  on stmt.directive_linklibrary { addLinkLibrary(getAttr(node, "value")); }
  on stmt.directive_breakpoint  {
    addBreakpoint(getNodeFile(node), getNodeLine(node));
  }
}
```

`@target` is the interesting one. The six target aliases are **not** defined in the langdef; they live in the Delphi host, and the langdef reaches them through the `setTargetAlias()` builtin, which returns false for a name it does not recognize.

```mld
// myra_utils.mld
routine applyTarget(tr: string) -> bool {
  if not setTargetAlias(tr) {
    return false;      // caller raises a located error
  }
  return true;
}
```

> [!IMPORTANT]
> 🎯 Target resolution lives where the toolchain is driven from, not in the langdef. The alias vocabulary (`win64`, `winarm64`, `linux64`, `linuxarm64`, `macos64`, `wasm32`) is owned by `Myra.Build`. `setTargetAlias` is the only door between them.

#### Node Walking

| Function | Description |
|----------|-------------|
| `emitNode(node)` | Dispatch the emitter handler registered for that node's kind |
| `emitChildren(node)` | Emit every child in sequence |
| `exprToString(node)` | Render an expression subtree to a string |

`exprToString` resolves in three steps: if an emitter handler exists for the node's kind, it runs in **string-capture mode**, intercepting `emit` calls instead of writing them out. Otherwise, if the node has exactly two children and an `@operator` attribute, it produces `left op right`. Failing both, the engine's default takes over.

#### Myra's Emission Order

The module emitter runs a fixed sequence, and the order is load-bearing.

1. **Preprocessor directives and raw C++ statements** first, before any namespace opens.
2. **Import includes** (`#include "module.h"`).
3. For a `lib` module, the **namespace wrapper** opens.
4. **Declarations**: types, constants, variables, routines.
5. **Test block functions**, which must precede `main` so they are forward-declared by the time it calls them.
6. **Module body** (`main`) last.

The `stmt.exported` handler runs alongside this, writing forward declarations into the header: routine signatures, `extern` variable declarations, and type and constant definitions.

<a id="mld-imperative"></a>

### 🔁 The Imperative Language

MLD is **Turing complete**. Handler bodies are not declarations, they are code. Variables, unbounded loops, conditionals, recursion, string operations, and error handling are all first-class, and they mix freely with the declarative forms in the same body.

#### Variables and Assignment

```mld
let x    = 42;
let name = "hello";
let ok   = true;
let n    = createNode("my_node");

x    = x + 1;
name = upper(name);
```

Variables are block-scoped. The interpreter keeps a stack of scope frames.

#### Control Flow

```mld
// if / else if / else
if x > 10 {
  emitLine("big");
} else if x > 5 {
  emitLine("medium");
} else {
  emitLine("small");
}

// while
let i = 0;
while i < child_count() {
  emitNode(getChild(node, i));
  i = i + 1;
}

// for X in N  -- iterates 0 .. N-1; the loop variable is declared for you
for i in child_count() {
  emitNode(getChild(node, i));
}

// match, with multiple patterns per arm
match getAttr(node, "module.kind") {
  "exe" => {
    setBuildMode("exe");
  }
  "dll" | "lib" => {
    setBuildMode(getAttr(node, "module.kind"));
  }
  else => {
    error "unknown module kind";
  }
}

// guard: run the block only if the condition holds
guard getAttr(node, "has_init") == "true" {
  emit " = ";
  emitNode(getChild(node, 0));
}

// return
routine max(a: int, b: int) -> int {
  if a > b { return a; }
  return b;
}
```

#### Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not` (both short-circuit) |
| String concatenation | `+` (overloaded) |

#### Operator Precedence (MLD's Own Expressions)

Not to be confused with the binding powers you *define* for the target language. These govern expressions inside handler bodies.

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (highest) | `not`, unary `-` | Right |
| 2 | `*`, `/`, `%` | Left |
| 3 | `+`, `-` | Left |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=` | Left |
| 5 | `and` | Left (short-circuit) |
| 6 (lowest) | `or` | Left (short-circuit) |

#### Attribute Access

`@name` reads and writes attributes on the **current context node**: the result node in a grammar rule, the visited node in a semantic or emitter handler.

```mld
grammar {
  rule stmt.module {
    expect keyword.module;
    consume identifier -> @name;      // writes @name on the result node
  }
}

emitters {
  on stmt.module {
    emitLine("// Module: " + @name);  // reads @name from the current node
  }
}
```

#### String Interpolation

Inside a double-quoted string:

- `{@attr}` reads an attribute from the current node
- `{expr}` evaluates an expression
- `\{` emits a literal `{`

```mld
error "undefined identifier '{@name}'";
emitLine("// child count: {child_count()}");
```

#### Triple-Quoted Strings

`"""` opens a multi-line literal. Leading whitespace is trimmed to the minimum common indent. No escape processing.

#### Try / Recover

If any statement inside `try` fails, control jumps to `recover`. This is how an emitter degrades gracefully instead of taking the compiler down.

```mld
try {
  let lhs = exprToString(getChild(node, 0));
  emit lhs;
} recover {
  error "malformed expression";
  emit "/* ERROR */";
}
```

#### Implicit Variables

| Variable | Available In | Meaning |
|----------|--------------|---------|
| `node` | Every handler | The current AST node |
| `true`, `false` | Everywhere | Boolean literals |
| `nil` | Everywhere | The null value |

#### Diagnostics

Every diagnostic carries the source location of the current node, and every message supports interpolation.

| Builtin | Severity |
|---------|----------|
| `error(msg)` | Compilation error |
| `errorAt(node, msg)` | Error located at a specific node |
| `warning(msg)` | Warning |
| `hint(msg)` | Suggestion |
| `note(msg)` | Informational |
| `info(msg)` | General information |

Both the call form and the statement form parse:

```mld
error("undefined identifier '" + nm + "'");
error "undefined identifier '{@name}'";
```

<a id="mld-routines"></a>

### 🧩 Routines, Constants, and Enums

#### User-Defined Routines

Routines are declared at the **top level**, outside any block, and are callable from any grammar, semantic, or emitter handler. They recurse. When called from an emitter context, a routine inherits the emitter's output builder, so it can call `emitLine()` and `indentIn()` directly.

**Syntax:** `routine name(p1: type, p2: type) -> returnType { ... }`

**Parameter and return types:** `string`, `int`, `bool`, `node`, `list`.

```mld
routine resolveType(typeText: string) -> string {
  if typeText == "int8"  { return "int8_t";  }
  if typeText == "int32" { return "int32_t"; }

  if startsWith(typeText, "array of ") {
    return "std::vector<" + resolveType(substr(typeText, 9, len(typeText) - 9)) + ">";
  }
  if startsWith(typeText, "pointer to ") {
    return resolveType(substr(typeText, 11, len(typeText) - 11)) + "*";
  }
  if contains(typeText, ".") {
    return replace(typeText, ".", "::");
  }
  return typeText;
}

routine emitBlock(blk: node) {
  let i = 0;
  while i < child_count(blk) {
    emitNode(getChild(blk, i));
    i = i + 1;
  }
}
```

#### Myra's Helper Routines

Defined in `myra_helpers.mld` and `myra_utils.mld`. These are the shared machinery the rest of the definition leans on.

| Routine | Returns | Purpose |
|---------|---------|---------|
| `resolveType(typeText)` | string | Map a Myra type name to a C++ type, including compound types |
| `collectTypeText()` | string | Collect a compound type's text from the token stream |
| `buildRoutineSig(nd, rname, retType)` | string | Build a C++ function signature from a routine declaration |
| `parseCallArgs(nd)` | - | Parse a `( expr, expr, ... )` argument list |
| `isDirectiveToken()` | bool | Is the current token a directive? |
| `emitBlock(blk)` | - | Walk a node's children and emit each |
| `emitArrayVarDecl(name, type)` | - | Emit an array variable declaration |
| `emitPointerVarDecl(name, type)` | - | Emit a pointer variable declaration |
| `emitRoutineForwardDecl(ch)` | - | Emit a routine forward declaration to the header |
| `emitExportedVarForwardDecls(blk)` | - | Emit `extern` declarations to the header |
| `emitExportedTypeToHeader(td)` | - | Emit a type declaration to the header |
| `emitExportedConstToHeader(cd)` | - | Emit a const declaration to the header |
| `stampFloatLiterals(n, targetType)` | - | Recursively stamp float literals with a resolved type |
| `applyTarget(tr)` | bool | Resolve a target alias through `setTargetAlias()` |

#### Constants

Constants must be declared before anything references them.

```mld
const {
  MAX_PARAMS       = 255;
  DEFAULT_ALIGN    = 8;
  ENABLE_OVERLOADS = true;
}
```

#### Enums

Members become global constants with sequential integer values starting at 0.

```mld
enum BuildMode { exe, lib, dll }
```

<a id="mld-fragments"></a>

### 📦 Fragments, Imports, and Guards

#### Fragments

A `fragment` is a named, reusable block of top-level declarations, expanded with `include`. Fragments are an organizational tool *within* a file.

```mld
fragment common_operators {
  token op.plus  = "+";
  token op.minus = "-";
  token op.star  = "*";
  token op.slash = "/";
}

tokens {
  include common_operators;
}
```

#### Imports

`import` loads an external `.mld` file. Paths resolve relative to the importing file, and **each path is processed only once**, so a diamond of imports is safe.

```mld
import "myra_tokens.mld";
import "myra_utils.mld";
import "myra_helpers.mld";
import "myra_grammar.mld";
import "myra_semantics.mld";
import "myra_emitters.mld";
```

#### Top-Level Guards

A `guard` includes or excludes declarations based on a constant. This is how a language feature is switched off at definition time rather than at runtime.

```mld
const {
  FEATURE_GENERICS = false;
}

tokens {
  guard FEATURE_GENERICS {
    token keyword.generic = "generic";
  }
}
```

With `FEATURE_GENERICS = false`, the word `generic` is not a keyword. It lexes as an ordinary identifier.

<a id="mld-builtins"></a>

### 🛠️ Built-in Function Reference

Every builtin the engine exposes, grouped by the context it is available in. Builtins in **Common** work everywhere; the rest are only meaningful in their own phase.

#### Common: Node Operations

| Function | Returns | Description |
|----------|---------|-------------|
| `nodeKind(node)` | string | The node's kind string |
| `getAttr(node, key)` | string | Read an attribute from a node |
| `getAttr(key)` | string | Read an attribute from the current context node |
| `setAttr(node, key, value)` | - | Write an attribute onto a node |
| `setAttr(key, value)` | - | Write an attribute onto the current context node |
| `has_attr(name)` | bool | Does the current node carry this attribute? |
| `getChild(node, index)` | node | Child at a zero-based index |
| `childCount(node)` | int | Number of children of a node |
| `child_count()` | int | Number of children of the current context node |
| `child_count(node)` | int | Number of children of a node |
| `createNode("kind")` | node | Create a new AST node |
| `setKind(node, "kind")` | - | Change a node's kind |
| `cloneNode(node)` | node | Deep-copy a node |
| `addChild(parent, child)` | - | Append a child |
| `setChild(parent, i, child)` | - | Replace the child at index `i` |
| `removeChild(parent, i)` | - | Remove the child at index `i` |
| `getResultNode()` | node | The rule's result node (grammar context) |
| `setShared(key, value)` | - | Write to the cross-handler shared store |
| `getShared(key)` | string | Read from the cross-handler shared store |
| `getNodeFile(node)` | string | Source file a node came from |
| `getNodeLine(node)` | int | Source line a node came from |

#### Common: String Operations

| Function | Returns | Description |
|----------|---------|-------------|
| `concat(a, b, ...)` | string | Concatenate (also spelled `a + b`) |
| `upper(s)` | string | Upper case |
| `lower(s)` | string | Lower case |
| `trim(s)` | string | Strip leading and trailing whitespace |
| `replace(s, find, repl)` | string | Replace every occurrence |
| `len(s)` | int | Length |
| `substr(s, start, count)` | string | Substring, zero-based start |
| `startsWith(s, prefix)` | bool | Prefix test |
| `endsWith(s, suffix)` | bool | Suffix test |
| `contains(s, sub)` | bool | Containment test |
| `intToStr(n)` | string | Integer to string |
| `strToInt(s)` | int | String to integer (0 on failure) |
| `fmtEscape(s)` | string | Escape a string for safe embedding in emitted C++ |

#### Common: Diagnostics

| Function | Description |
|----------|-------------|
| `error(msg)` | Raise a compilation error at the current node |
| `errorAt(node, msg)` | Raise an error located at a specific node |
| `warning(msg)` | Raise a warning |
| `hint(msg)` / `note(msg)` / `info(msg)` | Lower-severity diagnostics |

#### Parse Context

Available inside `grammar { rule ... { } }` bodies.

| Function | Returns | Description |
|----------|---------|-------------|
| `checkToken("kind")` | bool | Is the current token this kind? Does **not** consume. |
| `matchToken("kind")` | bool | If the current token is this kind, consume it and return true |
| `requireToken("kind")` | - | Assert the current token is this kind and consume it; error if not |
| `advance()` | string | Consume the current token, return its text |
| `currentText()` | string | Text of the current token |
| `currentKind()` | string | Kind of the current token |
| `peekKind()` | string | Kind of the next token (one-token lookahead) |
| `peekKindAt(n)` | string | Kind of the token `n` positions ahead |
| `parseExpr(power)` | node | Parse an expression with a minimum binding power |
| `parseExprFrom(node, power)` | node | Continue parsing an expression from an existing left node |
| `parseStmt()` | node | Parse the next statement |
| `collectUntil(kind)` | string | Collect raw text until a token kind is reached |
| `collectRaw()` | string | Collect raw text until delimiters balance |

#### Semantic Context

Available inside `semantics { on ... { } }` handlers, alongside the declarative `declare`, `lookup`, `scope`, and `visit` forms.

| Function | Returns | Description |
|----------|---------|-------------|
| `symbolExistsWithPrefix(prefix)` | bool | Does any symbol start with this prefix? |
| `demoteCLinkageForPrefix(prefix)` | int | Strip `clink` from every matching symbol; returns the count |
| `lookupSymbolType(name)` | string | Look up a symbol's type string |
| `compileModule(name)` | bool | Recursively compile a module |
| `setModuleExtension(ext)` | - | File extension used to resolve modules |
| `addModulePath(path)` | - | Add a module search directory |
| `getModulePaths()` | string | The current module search paths |
| `clearModulePaths()` | - | Clear the module search paths |

#### Emit Context: Low-Level Output

| Function | Description |
|----------|-------------|
| `emitLine(text)` | Write an indented line to the source buffer |
| `emitLine(text, "header")` | Write to the header buffer instead |
| `emit expr;` | Produce an expression fragment (expression emitters) |
| `emit @attr;` | Produce an attribute's value as a fragment |
| `blankLine()` | Write an empty line |
| `indentIn()` | Increase the indent level |
| `indentOut()` | Decrease the indent level |
| `include(path)` | Emit an `#include` |

#### Emit Context: Function Builder

| Function | C++ Produced |
|----------|--------------|
| `func(name, returnType)` | `returnType name(` ... `) {` |
| `param(name, type)` | Adds a parameter to the function being built |
| `endFunc()` | `}` |

#### Emit Context: Declarations and Statements

| Function | C++ Produced |
|----------|--------------|
| `declVar(name, type)` | `type name;` |
| `declVar(name, type, init)` | `type name = init;` |
| `assign(lhs, rhs)` | `lhs = rhs;` |
| `stmt(text)` | `text;` |
| `returnVal(expr)` | `return expr;` |
| `returnVoid()` | `return;` |
| `ifStmt(cond)` | `if (cond) {` |
| `elseIfStmt(cond)` | `} else if (cond) {` |
| `elseStmt()` | `} else {` |
| `endIf()` | `}` |
| `whileStmt(cond)` | `while (cond) {` |
| `endWhile()` | `}` |
| `forStmt(var, init, cond, step)` | `for (auto var = init; cond; step) {` |
| `endFor()` | `}` |
| `breakStmt()` | `break;` |
| `continueStmt()` | `continue;` |

#### Emit Context: Types and Node Walking

| Function | Returns | Description |
|----------|---------|-------------|
| `typeTextToKind(text)` | string | Resolve source type text to an internal type kind |
| `typeToIR(kind)` | string | Resolve an internal type kind to a C++ type |
| `exprToString(node)` | string | Render an expression subtree to a string |
| `emitNode(node)` | - | Dispatch the emitter handler for a node |
| `emitChildren(node)` | - | Emit every child in sequence |

#### Pipeline: Build Configuration

| Function | Accepted Values | Description |
|----------|-----------------|-------------|
| `setBuildMode(m)` | `"exe"`, `"lib"`, `"dll"` | Output kind |
| `setTargetAlias(name)` | `win64`, `winarm64`, `linux64`, `linuxarm64`, `macos64`, `wasm32` | Resolve a target alias in the host. **Returns false** on an unknown name. |
| `setPlatform(p)` | A zig/clang triple, e.g. `"x86_64-windows-gnu"` | Set the target triple directly |
| `getPlatform()` | - | The current triple, e.g. to reject a construct a target cannot support |
| `setOptimize(o)` | `"debug"`, `"releasesafe"`, `"releasefast"`, `"releasesmall"` | Optimization level |
| `getOptimize()` | - | The current optimization level |
| `setSubsystem(s)` | `"console"`, `"gui"` | Windows subsystem |
| `setLineDirectives(b)` | bool | Emit `#line` directives into the generated C++ |

> [!TIP]
> 💡 `getPlatform()` is how the langdef refuses a construct on a target that cannot support it. It is exactly how `guard` / `except` becomes a hard compile error on `wasm32`, where C++ exceptions are impossible.

#### Pipeline: Paths and Libraries

| Function | Description |
|----------|-------------|
| `addIncludePath(path)` | Add a C++ include search path |
| `addLibraryPath(path)` | Add a library search path |
| `addLinkLibrary(name)` | Link against a library |
| `addCopyDLL(path)` | Copy a DLL to the output directory |
| `setModuleExtension(ext)` | File extension used to resolve modules |
| `addModulePath(path)` | Add a module search directory |

#### Pipeline: Build State

Save and restore the whole build configuration. This is what lets an imported module set its own include paths and link libraries without corrupting its parent's.

| Function | Description |
|----------|-------------|
| `pushBuildState()` | Push the current build configuration onto a stack |
| `popBuildState()` | Restore the most recently pushed configuration |

#### Pipeline: Conditional Compilation

These drive the `@ifdef` symbol table, not the C++ preprocessor.

| Function | Returns | Description |
|----------|---------|-------------|
| `setDefine(name)` | - | Define a symbol |
| `setDefine(name, value)` | - | Define a symbol with a value |
| `removeDefine(name)` | - | Remove a defined symbol |
| `hasDefine(name)` | bool | Is this symbol defined? |
| `clearDefines()` | - | Remove every defined symbol |
| `unsetDefine(name)` | - | Explicitly mark a symbol as undefined |
| `removeUndefine(name)` | - | Remove an explicit undefine |
| `hasUndefine(name)` | bool | Is this symbol explicitly undefined? |
| `clearUndefines()` | - | Clear every explicit undefine |

#### Pipeline: Version Info

| Function | Description |
|----------|-------------|
| `setAddVerInfo(v)` | Enable the version resource |
| `setExeIcon(path)` | Embed an icon into the executable |
| `setVersionMajor(v)` / `setVersionMinor(v)` / `setVersionPatch(v)` | Version numbers |
| `setProductName(v)` | Product name |
| `setDescription(v)` / `setFileDescription(v)` | File description |
| `setFilename(v)` / `setVIFilename(v)` | Original filename |
| `setCompanyName(v)` | Company name |
| `setCopyright(v)` / `setLegalCopyright(v)` | Copyright string |

#### Pipeline: Debug

| Function | Description |
|----------|-------------|
| `addBreakpoint(file, line)` | Record a breakpoint entry in the `.mbp` sidecar |

<a id="mld-ebnf"></a>

### 🧾 Formal Grammar (EBNF)

The complete EBNF for the MLD meta-language itself. Brackets `[ ]` denote optionality, braces `{ }` denote zero-or-more repetition, parentheses `( )` group, and `|` separates alternatives.

#### Lexical Elements

```ebnf
letter       = "A" | ... | "Z" | "a" | ... | "z" | "_" .
digit        = "0" | ... | "9" .
ident        = letter { letter | digit } .
integer      = digit { digit } .
string       = '"' { character | escapeSeq } '"' .
tripleString = '"""' { character } '"""' .
escapeSeq    = "\" ( "n" | "t" | "r" | "0" | "\" | '"' ) .
comment      = "//" { character } newline .
blockComment = "/*" { character } "*/" .
```

#### Reserved Words

The meta-language is **case-sensitive** for all keywords and identifiers.

| Category | Words |
|----------|-------|
| Structure | `language`, `version`, `tokens`, `types`, `grammar`, `semantics`, `emitters`, `section` |
| Rules | `rule`, `on`, `token`, `optional`, `expect`, `consume`, `parse`, `many`, `until`, `sync`, `precedence`, `left`, `right` |
| Declarations | `let`, `const`, `enum`, `routine`, `fragment`, `import`, `include` |
| Control flow | `if`, `else`, `while`, `for`, `in`, `break`, `continue`, `return`, `match`, `guard`, `try`, `recover` |
| Semantics | `declare`, `lookup`, `scope`, `visit`, `children`, `child`, `parent`, `as`, `typed`, `where`, `pass` |
| Emission | `emit`, `to`, `indent`, `before`, `after`, `node` |
| Diagnostics | `error`, `warning`, `hint`, `note`, `info` |
| Literals | `true`, `false`, `nil` |
| Logic | `and`, `or`, `not` |

#### Built-in Types

```
string   text values
int      integer values
bool     boolean values
node     AST node reference
list     ordered collection
```

#### Operators and Delimiters

```
+    -    *    /    %
==   !=   <    >    <=   >=
=    ;    ,    .    :    @
(    )    [    ]    {    }
->   =>   |
```

#### Top-Level Structure

```ebnf
SourceFile     = LanguageDecl { TopLevelBlock } .
LanguageDecl   = "language" ident "version" string ";" .
TopLevelBlock  = TokenBlock | TypesBlock | GrammarBlock | SemanticsBlock
               | EmitterBlock | ConstBlock | EnumDecl | RoutineDecl
               | FragmentDecl | ImportStmt | IncludeStmt | GuardBlock .
```

#### Token Declarations

```ebnf
TokenBlock     = "tokens" "{" { TokenDecl | TokenConfig | GuardBlock | IncludeStmt } "}" .
TokenDecl      = "token" TokenKind "=" string [ TokenFlags ] ";" .
TokenKind      = ident "." ident .
TokenFlags     = "[" TokenFlag { "," TokenFlag } "]" .
TokenFlag      = "noescape" | "close" string
               | "define" | "undef" | "ifdef" | "ifndef"
               | "elseif" | "else" | "endif" .
TokenConfig    = CaseSensitiveDecl | IdentStartDecl | IdentPartDecl
               | StructuralDecl | HexPrefixDecl | BinaryPrefixDecl
               | DirectivePrefixDecl .
CaseSensitiveDecl   = "casesensitive" "=" ( "true" | "false" ) ";" .
StructuralDecl      = ( "terminator" | "block_open" | "block_close" ) "=" TokenKind ";" .
HexPrefixDecl       = "hex_prefix" "=" string ";" .
BinaryPrefixDecl    = "binary_prefix" "=" string ";" .
DirectivePrefixDecl = "directive_prefix" "=" string ";" .
```

#### Type Declarations

```ebnf
TypesBlock     = "types" "{" { TypeDecl | IncludeStmt | GuardBlock } "}" .
TypeDecl       = TypeKeywordDecl | TypeMappingDecl | LiteralTypeDecl
               | TypeCompatDecl | DeclKindDecl | CallKindDecl
               | CallNameAttrDecl .
TypeKeywordDecl  = "type" ident "=" string ";" .
TypeMappingDecl  = "map" string "->" string ";" .
LiteralTypeDecl  = "literal" string "=" string ";" .
TypeCompatDecl   = "compatible" string "," string [ "->" string ] ";" .
DeclKindDecl     = "decl_kind" string ";" .
CallKindDecl     = "call_kind" string ";" .
CallNameAttrDecl = "call_name_attr" "=" string ";" .
```

#### Grammar Rule Declarations

```ebnf
GrammarBlock   = "grammar" "{" { RuleDecl } "}" .
RuleDecl       = "rule" NodeKind [ RuleModifiers ] "{" { RuleStmt } "}" .
RuleModifiers  = "precedence" ( "left" | "right" ) integer .
NodeKind       = ident "." ident .
RuleStmt       = ExpectStmt | ConsumeStmt | ParseStmt | SetAttrStmt
               | OptionalBlock | SyncDecl | HandlerStmt .
ExpectStmt     = "expect" TokenRef ";" .
ConsumeStmt    = "consume" TokenRef "->" "@" ident ";" .
ParseStmt      = "parse" ( "expr" | "stmt" ) [ integer ] "->" "@" ident ";"
               | "parse" "many" ( "expr" | "stmt" )
                 [ "until" UntilSpec ] "->" "@" ident ";" .
OptionalBlock  = "optional" "{" { RuleStmt } "}" .
SyncDecl       = "sync" TokenKind ";" .
TokenRef       = TokenKind | "[" TokenKind { "," TokenKind } "]" | "identifier" .
```

#### Semantic Handler Declarations

```ebnf
SemanticsBlock = "semantics" "{" { SemanticDecl | PassBlock } "}" .
PassBlock      = "pass" integer string "{" { SemanticDecl } "}" .
SemanticDecl   = "on" NodeKind "{" { SemanticStmt } "}" .
SemanticStmt   = VisitStmt | DeclareStmt | LookupStmt | ScopeBlock | HandlerStmt .
VisitStmt      = "visit" VisitTarget ";" .
VisitTarget    = "children" | "@" ident | "child" "[" Expression "]" .
DeclareStmt    = "declare" "@" ident "as" SymbolKind
                 [ "typed" Expression ] [ WhereBlock ] ";" .
SymbolKind     = "variable" | "routine" | "type" | "constant" | "parameter" .
LookupStmt     = "lookup" "@" ident
                 ( "->" "let" ident | "or" "{" { SemanticStmt } "}" ) ";" .
ScopeBlock     = "scope" Expression "{" { SemanticStmt } "}" .
```

#### Emitter Handler Declarations

```ebnf
EmitterBlock   = "emitters" "{" { SectionDecl | EmitDecl | BeforeBlock | AfterBlock } "}" .
SectionDecl    = "section" ident [ "indent" string ] ";" .
EmitDecl       = "on" NodeKind "{" { EmitStmt } "}" .
EmitStmt       = EmitToStmt | VisitStmt | IndentBlock | HandlerStmt .
EmitToStmt     = "emit" [ "to" ident ":" ] Expression ";" .
IndentBlock    = "indent" "{" { EmitStmt } "}" .
```

#### Expressions

```ebnf
Expression     = OrExpr .
OrExpr         = AndExpr { "or" AndExpr } .
AndExpr        = NotExpr { "and" NotExpr } .
NotExpr        = [ "not" ] Comparison .
Comparison     = Addition [ ( "==" | "!=" | "<" | ">" | "<=" | ">=" ) Addition ] .
Addition       = Term { ( "+" | "-" ) Term } .
Term           = Factor { ( "*" | "/" | "%" ) Factor } .
Factor         = AttrAccess | Ident | StringLiteral | IntLiteral
               | BoolLiteral | "nil" | "(" Expression ")"
               | FuncCall | InterpolatedString | TripleString .
AttrAccess     = "@" ident .
FuncCall       = ident "(" [ Expression { "," Expression } ] ")" .
InterpolatedString = '"' { character | "{@" ident "}" | "{" Expression "}" } '"' .
```

#### Handler Body Logic

```ebnf
HandlerStmt    = LetStmt | AssignStmt | IfStmt | WhileStmt | ForStmt
               | MatchStmt | GuardStmt | BreakStmt | ContinueStmt
               | ReturnStmt | TryRecover | DiagStmt | FuncCallStmt | SetAttrStmt .
LetStmt        = "let" ident "=" Expression ";" .
AssignStmt     = ident "=" Expression ";" .
IfStmt         = "if" Expression "{" { HandlerStmt } "}"
                 { "else" "if" Expression "{" { HandlerStmt } "}" }
                 [ "else" "{" { HandlerStmt } "}" ] .
WhileStmt      = "while" Expression "{" { HandlerStmt } "}" .
ForStmt        = "for" ident "in" Expression "{" { HandlerStmt } "}" .
MatchStmt      = "match" Expression "{" { MatchArm } [ DefaultArm ] "}" .
MatchArm       = Pattern "=>" "{" { HandlerStmt } "}" .
DefaultArm     = "else" "=>" "{" { HandlerStmt } "}" .
Pattern        = ( StringLiteral | IntLiteral | BoolLiteral )
                 { "|" ( StringLiteral | IntLiteral | BoolLiteral ) } .
GuardStmt      = "guard" Expression "{" { HandlerStmt } "}" .
ReturnStmt     = "return" [ Expression ] ";" .
TryRecover     = "try" "{" { HandlerStmt } "}" "recover" "{" { HandlerStmt } "}" .
DiagStmt       = ( "error" | "warning" | "hint" | "note" | "info" ) Expression ";" .
FuncCallStmt   = ident "(" [ Expression { "," Expression } ] ")" ";" .
```

#### Routines, Constants, Fragments, Imports

```ebnf
RoutineDecl    = "routine" ident "(" [ ParamList ] ")" [ "->" TypeName ]
                 "{" { HandlerStmt } "}" .
ParamList      = Param { "," Param } .
Param          = ident ":" TypeName .
TypeName       = "string" | "int" | "bool" | "node" | "list" .
ConstBlock     = "const" "{" { ConstDecl } "}" .
ConstDecl      = ident "=" Expression ";" .
EnumDecl       = "enum" ident "{" ident { "," ident } "}" .
FragmentDecl   = "fragment" ident "{" { TopLevelBlock } "}" .
ImportStmt     = "import" string ";" .
IncludeStmt    = "include" ident ";" .
GuardBlock     = "guard" Expression "{" { TopLevelBlock | TokenDecl | TypeDecl } "}" .
```

#### Token Kind Naming Conventions

| Category | Examples |
|----------|----------|
| `keyword.*` | `keyword.if`, `keyword.while`, `keyword.var` |
| `op.*` | `op.plus`, `op.assign`, `op.neq` |
| `delimiter.*` | `delimiter.lparen`, `delimiter.semicolon` |
| `literal.*` | `literal.integer`, `literal.float`, `literal.hex` |
| `string.*` | `string.cstring`, `string.wstring` |
| `comment.*` | `comment.line`, `comment.block_open` |
| `directive.*` | `directive.define`, `directive.optimize` |
| `type.*` | `type.int32`, `type.string`, `type.boolean` |
| `identifier` | bare, no dot |
| `eof` | bare, no dot |

#### Node Kind Naming Conventions

| Category | Examples |
|----------|----------|
| `program.*` | `program.root` |
| `stmt.*` | `stmt.if`, `stmt.var_decl`, `stmt.routine_decl`, `stmt.module` |
| `expr.*` | `expr.ident`, `expr.call`, `expr.binary`, `expr.grouped` |

`program.root` is the engine's root node kind. Every other node kind in the tree is one your `.mld` invented.

### 🔨 Hacking Myra

You do not rebuild the compiler to change the language. The `.mld` files are read at startup from `bin/res/language/`. Edit them in place and run the compiler again.

| Goal | What to Change |
|------|----------------|
| **Rename a keyword** | One `token` line in `myra_tokens.mld`. |
| **Add an operator** | Declare the token, add an infix `rule` with a binding power, add an `emitters` handler. |
| **Change what C++ comes out** | Edit the emitter handler. Nothing else moves. |
| **Add a statement** | Declare the keyword, write a `stmt.*` rule, add a semantic handler and an emitter. |
| **Add a type** | A `type` line, a `map` line, and the `compatible` entries that let it coerce. |
| **Switch a feature off** | Wrap its declarations in a top-level `guard` on a `const`. |

> [!TIP]
> 💡 The `.mld` files are the best documentation of Myra that exists, because they are not a description of the compiler. They **are** the compiler. When the prose and the `.mld` disagree, the `.mld` is right.

<a id="tools"></a>

## 🛠️ Tools

Myra ships as **two** executables, both self-contained, both zero-install:

| Binary | What it is | Talks over |
|---|---|---|
| `Myra.exe` | The compiler. Lexes, parses, emits C++23, drives the bundled zig/clang toolchain, runs the program, and hosts the debugger. | The command line |
| `MyraLSP.exe` | The language server. Everything an editor needs to understand a `.myra` file. | JSON-RPC on stdin/stdout |

The zig/clang toolchain is bundled beside them under `res/zig`. There is no external compiler, linker, SDK or runtime to install.

The language definition is **baked into** `Myra.exe`, so you never point the compiler at a grammar to compile a `.myra` file. The same `.mld` files also ship as readable text under `res/language/`, because the compiler is meant to be hackable. `MyraLSP.exe` loads that text copy at startup, resolved relative to its own directory (`res/language/myra.mld`) so it works no matter what directory the editor launches it from.

---

### 🧰 The Compiler CLI

`Myra.exe` compiles one `.myra` source file. That file is the entry module; everything it `import`s is pulled in from there.

#### Flags

| Flag | Long form | Argument | Meaning |
|---|---|---|---|
| `-s` | `--source` | `<file>` | **Required.** The `.myra` source file to compile. |
| `-o` | `--output` | `<path>` | Output directory. Defaults to `output`. Resolved to an absolute path before use. |
| `-r` | `--autorun` | -- | Build, then run the compiled binary. |
| `-d` | `--debug` | -- | Build, then drop into the interactive debug REPL. |
| `-h` | `--help` | -- | Print usage and exit. |

There are no other flags. An unrecognized flag is an error, not a warning.

```
Myra -s hello.myra
Myra -s hello.myra -o build
Myra -s hello.myra -r
Myra -s hello.myra -d
```

> [!NOTE]
> ⚖️ `-r` and `-d` are **mutually exclusive**. Passing both is a usage error. Run `Myra` with no arguments at all and it prints its help.

#### Exit codes

The CLI's exit code is a real signal, and it is worth understanding because it is not always the compiler's own.

| Code | Meaning |
|---|---|
| `0` | Build succeeded. |
| `1` | Build failed (compile or link errors), or an unhandled fatal error, or `-d` could not start a debug session. |
| `2` | Usage error: unknown flag, missing `-s`, a flag missing its argument, or `-r` together with `-d`. |
| *program's own* | With `-r`, a **successful** build hands the exit code straight through from the program you just ran. |

That last row is the one that surprises people. A build that succeeds and then runs a program that returns `3` gives you `3`, not `0`. This is deliberate: the build did not fail, the *program* returned a value, and a shell script that could not see that value would be blind to every failing run.

#### What a build produces

```
<output>/
  generated/            emitted C++23 -- .cpp and .h, one per module
  build.zig             generated build script
  zig-out/
    bin/                the executable (and .pdb on win64 debug builds)
    lib/                the .lib / .dll / .so / .a artifacts
```

`zig-out/lib` and `zig-out/bin` are both registered as implicit library search paths in the generated `build.zig`. That is what makes `external "<some myra dll>"` resolve when one Myra artifact links against another.

The emitted C++ is not a temporary. It stays on disk under `generated/`, and reading it is the fastest way to answer "what did that actually compile to."

---

### 🏗️ The C++ Build Pipeline

```
Lex -> Parse -> ResolveImports -> Semantics -> Emit -> Build
```

Everything the build does is driven by **source directives**, never by CLI flags. A `.myra` file therefore builds the same way no matter who builds it, on what machine, from what directory. The only thing the command line controls is *where the output lands* and *whether to run it afterwards*.

| Capability | Controlled by | Values |
|---|---|---|
| Output kind | the module form itself | `module exe` / `module dll` / `module lib` / `module unit` |
| Target platform | `@target` | one of the six aliases below |
| Optimization | `@optimize` | `debug`, `releasesafe`, `releasefast`, `releasesmall` |
| Subsystem | `@subsystem` | `console`, `gui` |
| Version resource | `@addverinfo`, `@vimajor`, `@viminor`, `@vipatch`, `@viproductname`, `@videscription`, `@vifilename`, `@vicompanyname`, `@vicopyright` | embedded Win32 version info |
| Executable icon | `@exeicon` | path to an icon file |
| Native libraries | `@linklibrary`, `@librarypath` | link against C/C++ libraries |
| DLL staging | `@copydll` | copy a runtime dll beside the exe |
| Headers | `@includepath` | additional C++ include search paths |
| Modules | `@modulepath` | additional `.myra` module search paths |
| Preprocessor | `@define`, `@undef` | C++ preprocessor symbols |
| Debug | `@breakpoint` | a breakpoint, in the source, at that line |
| Diagnostics | `@message` | emit a hint / warn / error / fatal at compile time |

> [!IMPORTANT]
> 🐞 **The default optimize level is `debug`.** That is what emits the PDB the debugger needs. If a source file sets `@optimize releasefast`, it is a release build, and `-d` will not have debug info to work with.

See [Directives](#build-directives) for the full reference on each one.

---

### 🎯 Targets

Myra cross-compiles. Six curated aliases cover every supported platform. There is no way to pass a raw LLVM triple -- the alias vocabulary is the surface, and it is deliberately small.

| Alias | Triple | Run with `-r`? |
|---|---|---|
| `win64` | `x86_64-windows-gnu` | ✅ native |
| `winarm64` | `aarch64-windows-gnu` | ⚠️ build only |
| `linux64` | `x86_64-linux-gnu` | ✅ requires WSL |
| `linuxarm64` | `aarch64-linux-gnu` | ⚠️ build only |
| `macos64` | `aarch64-macos-none` | ⚠️ build only |
| `wasm32` | `wasm32-wasi` | ✅ in the browser |

> [!NOTE]
> 🧱 A target the host cannot execute still **builds**. Asking to run it produces a **warning**, never an error. `macos64` is Apple Silicon only, by design.

> [!IMPORTANT]
> 🚫 `guard` / `except` is a **hard compile error** on `wasm32`. C++ exceptions are impossible on that toolchain, so the build passes `-fno-exceptions`. Structure wasm code to return errors rather than raise them.

> [!TIP]
> 🌐 A `wasm32` build also emits a self-contained `<project>.html` beside the `.wasm`, with the WASI shim **and** the wasm bytes inlined as base64. Double-click it -- no web server. That is why `wasm32` counts as an auto-run target. Because it runs in a browser tab rather than a process, there is no exit code to recover and no stdout to capture.

---

### 🐞 The Debugger

Myra's debugger is a **native source-level debugger**. It does not interpret anything: it launches the real compiled executable, patches `INT3` bytes at breakpoint addresses, and reads back locals from the PDB via `dbghelp`. What you step through is the actual machine code.

> [!IMPORTANT]
> 🪟 **The debugger is `win64` only.** It is built on the Windows debug API and the PDB format (`dbghelp.dll`, `StackWalk64`, x86-64). Asking to debug any other target is refused up front. There is no gdb/lldb bridge.

Two prerequisites, both easy to trip over:

1. The build must be a **debug** build, so a `.pdb` sits next to the `.exe`. This is the default -- you only lose it by asking for it in the source.
2. The target must resolve to `x86_64-windows-gnu`.

#### The debug REPL

`Myra -s file.myra -d` builds the program, starts a debug server, connects a client to it, feeds it any breakpoints it can find, and drops you at the first stop.

| Command | Does |
|---|---|
| `h`, `help` | Show the command list |
| `b <file>:<line>` | Set a breakpoint |
| `bl` | List breakpoints |
| `bd <id>` | Delete breakpoint by ID |
| `bc` | Clear all breakpoints |
| `bt` | Backtrace -- the call stack |
| `locals` | Show local variables in the current frame |
| `p <expr>` | Print / evaluate an expression |
| `c` | Continue |
| `n` | Next -- step over |
| `s` | Step into |
| `finish` | Step out |
| `r` | Restart the program |
| `src` | Show source context around the stop |
| `threads` | List threads |
| `file <path>` | Load a different executable |
| `verbose on` / `verbose off` | Log the raw DAP traffic |
| `quit` | Leave the REPL |

If the program runs to completion without ever stopping, the REPL says so and exits rather than dropping you at a prompt with nothing to inspect.

#### Breakpoints, two ways

**In the source**, with the `@breakpoint` directive. This is the simplest thing that works, and it survives a rebuild:

```myra
module exe test_exe_debug;

var
  LValue: int32;

routine ComputeAnswer(): int32;
var
  LResult: int32;
begin
  LResult := 40;
  @breakpoint;
  LResult := LResult + 2;
  return LResult;
end;

begin
  println("Debug test starting...");
  @breakpoint;
  LValue := ComputeAnswer();
  println("The answer is: {}", LValue);
  println("Debug test complete.");
end.
```

*(This is `bin/res/tests/test_exe_debug.myra`, a passing test.)*

**Out of band**, in a `.mbp` sidecar, so the source stays clean. Every `@breakpoint` the compiler sees is written into `<project>.mbp` beside the executable, and the REPL loads that file automatically at startup if it exists. It is plain text, and you can write it by hand:

```toml
[[breakpoints]]
file = "../../hello.myra"
line = 30

[[breakpoints]]
file = "../../hello.myra"
line = 37
```

Paths are stored **relative to the executable's directory** and forward-slashed, so the sidecar travels with the build. An absolute path is accepted and used as-is.

> [!NOTE]
> 🧭 The compiler only writes a `.mbp` if it actually collected at least one `@breakpoint`. No directives, no sidecar file.

#### The DAP server

Under the hood, the REPL is just a client. The debugger's real interface is a **Debug Adapter Protocol** server speaking JSON over TCP, default port **4711**, so any DAP-aware editor can drive the same debugger with a real UI.

Requests it handles:

| Request | Request |
|---|---|
| `initialize` | `continue` |
| `launch` | `next` |
| `setBreakpoints` | `stepIn` |
| `setExceptionBreakpoints` | `stepOut` |
| `configurationDone` | `pause` |
| `threads` | `evaluate` |
| `stackTrace` | `disconnect` |
| `scopes` | |
| `variables` | |

Events it emits: `initialized`, `stopped`, `exited`, `terminated`.

Capabilities it advertises, verbatim:

| Capability | |
|---|---|
| `supportsConfigurationDoneRequest` | ✅ |
| `supportsConditionalBreakpoints` | ✅ |
| `supportsHitConditionalBreakpoints` | ✅ |
| `supportsEvaluateForHovers` | ✅ |
| `supportsFunctionBreakpoints` | ❌ |
| `supportsStepBack` | ❌ |
| `supportsSetVariable` | ❌ |
| `supportsRestartFrame` | ❌ |
| `supportsModulesRequest` | ❌ |
| `supportsExceptionInfoRequest` | ❌ |

So: **conditional breakpoints and hit-count breakpoints work**. Variables are read-only -- you can inspect them and evaluate expressions against them, but you cannot poke a new value into a live frame. There is no time-travel.

#### Debugging a DLL

A `module dll` is not an entry point -- it has no `main`, so there is nothing to launch. Debugging one therefore works differently: you supply the **DLL to debug** *and* a **host executable that loads it**, and the debugger launches the host under the Windows debug API (`DEBUG_ONLY_THIS_PROCESS`), waits for your DLL to actually load into that process, resolves its real load address, and only then applies your breakpoints.

That last part is the whole reason this is a separate mode. A DLL's breakpoint addresses cannot be computed until the loader has mapped it, and the address it lands at is not the address in the PDB. The debugger handles the DLL-load event internally: on load it resolves the live image base, patches the breakpoints, and resumes the host. From that point on it is the same debugger -- same breakpoints, same stepping, same call stack, same locals, same DAP surface, same port.

What it needs:

| Input | Requirement |
|---|---|
| The DLL | Must exist. Built by Myra as a `module dll`. |
| A `.pdb` beside the DLL | Same debug-build rule as an exe. No PDB, no source-level debugging. |
| A host EXE | **Required.** It is the process that gets launched and debugged. It can be anything that loads your DLL -- a C++ harness, another Myra `module exe`, a test runner. |
| A port | Defaults to 4711, same as exe mode. |

The sequence, and the error code you get if a step fails:

| Step | Failure code |
|---|---|
| DLL exists | `DBG200` |
| Host EXE supplied | `DBG204` |
| Host EXE exists | `DBG205` |
| `.pdb` found beside the DLL | `DBG202` |
| DAP server starts listening | `DBG100` |
| A debug client connects | `DBG101` |
| The host process launches | `DBG102` |
| The PDB loads against the live image base | `DBG103` |

The server blocks waiting for a DAP client **before** it launches the host, so you attach first and the host starts second. That ordering is deliberate: it means you can have breakpoints set before a single instruction of the host runs.

> [!NOTE]
> 🔌 DLL debugging is driven **programmatically**, through `TDebugServer.DebugDll(dll, hostExe, port)`. The `Myra -d` flag builds and debugs an **exe**; there is no CLI flag today that takes a DLL plus a host. Reach for the DLL mode when you are embedding the debugger, or drive it from a DAP-aware editor and point its launch config at the host.

---

### 🧠 The Language Server

`MyraLSP.exe` is a standard LSP server. It reads JSON-RPC from **stdin** and writes it to **stdout**, framed with `Content-Length` headers. It takes **no arguments** -- your editor just spawns it.

Anything it needs to say that is *not* protocol traffic goes to **stderr**, never stdout, because stdout is the wire. If the langdef fails to load, the server prints the reason on stderr and exits, rather than dying silently and leaving the editor staring at a dead pipe.

#### What your editor needs to know

| Setting | Value |
|---|---|
| Command | `bin/MyraLSP.exe` |
| Arguments | none |
| Transport | stdio |
| Language id | `myra` |
| File extension | `.myra` |
| Server name / version | `myra-lsp` / `1.0.0` |
| Document sync | **Full** (the whole document is resent on every change) |
| Completion trigger characters | `.` |
| Signature help trigger characters | `(` and `,` |

#### Methods

| Feature | LSP method |
|---|---|
| Lifecycle | `initialize`, `initialized`, `shutdown`, `exit` |
| Document sync | `textDocument/didOpen`, `textDocument/didChange`, `textDocument/didClose` |
| Diagnostics | `textDocument/publishDiagnostics` *(server -> client notification)* |
| Completion | `textDocument/completion` |
| Hover | `textDocument/hover` |
| Go to definition | `textDocument/definition` |
| Find references | `textDocument/references` |
| Document symbols | `textDocument/documentSymbol` |
| Workspace symbols | `workspace/symbol` |
| Signature help | `textDocument/signatureHelp` |
| Folding ranges | `textDocument/foldingRange` |
| Semantic tokens | `textDocument/semanticTokens/full` |
| Inlay hints | `textDocument/inlayHint` |
| Rename | `textDocument/rename` |
| Code actions | `textDocument/codeAction` |
| Formatting | `textDocument/formatting` |

Anything else gets a proper JSON-RPC `-32601 Method not found` rather than silence.

#### What each feature actually gives you

**Diagnostics** are published on open and on every change. Each carries a severity (1 error, 2 warning, 3 info, 4 hint), Myra's own structured **error code**, and an exact source range, so the editor squiggles the precise span and can surface the code inline.

**Completion** is context-sensitive. In open code it offers what is in scope. After a `.` it switches to **member completion** and offers only the members of the qualifier -- a module's exported routines, or a record's fields.

**Hover** shows the symbol's kind, its signature, and its return type.

**Go to definition** and **find references** work across the whole document, including into imported modules, because the server resolves imports for real rather than parsing a single file in isolation.

**Rename** returns a workspace edit covering every occurrence.

**Document symbols** gives the outline pane. **Workspace symbols** searches by name across the workspace.

**Folding ranges** fold the block structure. **Inlay hints** annotate inferred types and parameter names.

**Semantic tokens** drive the real highlighting. The legend, in order (the index is the token type):

| # | Type | # | Type | # | Type |
|---|---|---|---|---|---|
| 0 | `namespace` | 5 | `method` | 10 | `keyword` |
| 1 | `type` | 6 | `property` | 11 | `operator` |
| 2 | `class` | 7 | `variable` | 12 | `number` |
| 3 | `enum` | 8 | `parameter` | 13 | `string` |
| 4 | `function` | 9 | `enumMember` | 14 | `comment` |

Modifiers: `declaration`, `definition`, `readonly`.

#### Formatting, and what it deliberately will not do

The formatter does exactly two things: **strip trailing whitespace from every line**, and **guarantee a final newline**. It preserves the file's existing line endings -- an LF file stays an LF file.

That is the whole feature, and the restraint is the point. Myra passes unrecognized tokens through to C++ verbatim, so a structural re-indenter would have to understand C++ as well as Myra. A formatter that guesses is a formatter that corrupts source. This pass provably cannot change a single token.

The one **code action** follows from that: `Clean up whitespace` (kind `source.fixAll`). It is offered **only when there is actually something to clean**, because a lightbulb that does nothing when you click it is worse than no lightbulb.

#### One thing worth knowing about names

Internally, the compiler keys routines by their **mangled signature** -- `add` with two `int32` parameters is stored as `add(int32,int32)` -- and synthesizes a hidden `__rettype:add` symbol to carry the return type. Both are load-bearing for overload resolution.

Neither ever reaches your editor. Translating between the compiler's names and the names you actually typed is the language server's job. An outline pane shows `add`; go-to-definition looks up `add` and finds it; the return type surfaces as `: int32` in hover and signature help. You should never see a mangled name.

<a id="api-reference"></a>

## 🔌 Embedding and Scripting

Myra compiles ahead of time to C++23, and the bundled zig/clang toolchain builds that
C++ into a native artifact. A component built from Myra is an ordinary native library
with an ordinary symbol table.

This page documents the boundary: what `module lib` and `module dll` emit, what lands in
the generated header, which symbol names survive, and how each is consumed.

### 🧭 Two Artifacts, Two Mechanisms

`lib` and `dll` are not variants of one idea. They differ in the emitted C++, in how a
caller names a routine, and in what the build must be told.

| | `module lib` | `module dll` |
|---|---|---|
| Emitted C++ | Wrapped in `namespace <modname> { }` | No namespace, flat symbols |
| `MYR_EXPORT` expands to | Nothing | `__declspec(dllexport)` on Windows, `__attribute__((visibility("default")))` elsewhere |
| Consumed from Myra by | `import <modname>;` | `external "<libname>"` declarations |
| Call syntax | Qualified: `test_lib_mathlib.Add(3, 4)` | Bare: `add(3, 5)` |
| Requires `@linklibrary` | No | Yes |
| Requires `@librarypath` | No | Yes |

> [!IMPORTANT]
> 🔗 A `lib` is consumed through `import`. It does not use `external`, `@linklibrary` or
> `@librarypath`. Its routines are not flat symbols: they live inside a C++ namespace.

---

### 📦 1. The `lib` Artifact

A `lib` module is emitted inside a C++ namespace named after the module, in both the
header and the source.

#### Producing a lib

From `test_lib_mathlib.myra`:

```myra
module lib test_lib_mathlib;

// Private. Emits: static int32_t Helper(...)
routine Helper(const A: int32; const B: int32): int32;
begin
  return A + B;
end;

// Exported, C++ linkage. Definition in the source, forward declaration in the header.
exported routine Add(const A: int32; const B: int32): int32;
begin
  return Helper(A, B);
end;

// Second overload, different parameter types.
exported routine Add(const A: float32; const B: float32): float32;
begin
  return A + B;
end;

// Exported with C linkage. Emits: extern "C" { int32_t Multiply(...) }
exported routine clink Multiply(const A: int32; const B: int32): int32;
begin
  return A * B;
end;

end.
```

#### Consuming a lib from Myra

`import <modname>;` emits `#include "<modname>.h"` into the consumer's source. The call
site qualifies the routine with the module name, and the dot becomes `::` in the emitted
C++.

From `test_exe_uselib.myra`:

```myra
module exe test_exe_uselib;

import test_lib_mathlib;

var
  LIntResult: int32;
  LFloatResult: float32;

begin
  // int32 overload
  LIntResult := test_lib_mathlib.Add(3, 4);
  println("Add(3, 4) = {}", LIntResult);

  // float32 overload, selected by the type of the assignment target
  LFloatResult := test_lib_mathlib.Add(1.5, 2.3);
  println("Add(1.5, 2.3) = {}", LFloatResult);

  // clink routine, still qualified
  LIntResult := test_lib_mathlib.Multiply(5, 6);
  println("Multiply(5, 6) = {}", LIntResult);
end.
```

`Helper` is not `exported`, is emitted `static`, and is not callable from here.

> [!NOTE]
> 📎 `clink` controls the emitted symbol, not the Myra call syntax. A Myra consumer
> writes `modname.Routine(...)` either way.

---

### 🔗 2. The `dll` Artifact

A `dll` module is not wrapped in a namespace. Exported entities are prefixed with
`MYR_EXPORT`, which the emitter defines as:

```cpp
#ifdef _WIN32
#define MYR_EXPORT __declspec(dllexport)
#else
#define MYR_EXPORT __attribute__((visibility("default")))
#endif
```

#### Producing a dll

From `test_dll_exports.myra`:

```myra
module dll test_dll_exports;

// Private helper. Emits: static int32_t helper(...)
routine helper(const x: int32): int32;
begin
  return x * 2;
end;

exported routine clink add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

exported routine clink add(const a: float32; const b: float32): float32;
begin
  return a + b;
end;

exported routine clink quadruple(const x: int32): int32;
begin
  return helper(helper(x));
end;

// An exported variable may carry an initializer.
exported var version: int32 = 1;

end.
```

#### Consuming a dll from Myra

The consumer declares each imported entity with `external "<libname>"` and points the
build at the artifact.

From `test_exe_usedll.myra`:

```myra
module exe test_exe_usedll;

@ifdef TARGET_LINUX64
@copydll "output/zig-out/lib/libtest_dll_exports.so";
@librarypath "output/zig-out/lib";
@elseif TARGET_WIN64
@librarypath "output/zig-out/bin";
@endif

@linklibrary "test_dll_exports";

routine clink add(const a: int32; const b: int32): int32; external "test_dll_exports";
routine clink add(const a: float32; const b: float32): float32; external "test_dll_exports";
routine clink quadruple(const x: int32): int32; external "test_dll_exports";

// Variables cross the boundary too.
var version: int32; external "test_dll_exports";

var
  LIntResult: int32;
  LFloatResult: float32;

begin
  LIntResult := add(3, 5);
  println("{}", LIntResult);
  LFloatResult := add(3.0, 4.5);
  println("{:.1f}", LFloatResult);
  LIntResult := quadruple(4);
  println("{}", LIntResult);
  println("{}", version);
end.
```

> [!WARNING]
> 🚫 There is no `name` clause. The Myra identifier is the symbol name. To bind a
> differently named symbol, name the routine accordingly.

#### The link directives

| Directive | Effect |
|---|---|
| `@linklibrary "name"` | Adds `name` to the link line. No prefix, no extension. |
| `@librarypath "dir"` | Adds a directory to the library search path. |
| `@copydll "path"` | Copies the named shared library into the executable's output directory after the build. |

The artifact layout differs by platform, which is why the two paths above are guarded.
On `win64` the built `.dll` lands in `zig-out/bin`, alongside the consuming executable.
On `linux64` the `.so` lands in `zig-out/lib` while the executable lands in `zig-out/bin`,
so `@copydll` places it next to the executable.

> [!TIP]
> 💡 `@ifdef TARGET_WIN64` is resolved by the Myra lexer against the compiler's own symbol
> table, before clang runs. That is why it can select build configuration such as a
> library path. A C++ `#if defined(...)` cannot: by then the build is already assembled.
> The two conditional systems are separate and cannot see each other.

---

### 🎭 Visibility and Linkage

`exported` controls visibility. `clink` / `cpplink` controls linkage. They are
independent, and all four combinations are legal. `cpplink` is the default and need not
be written.

| Myra | Emitted C++ | In the header |
|---|---|---|
| `routine Foo()` | `static void Foo()` | No |
| `routine clink Foo()` | `extern "C" { static void Foo() }` | No |
| `exported routine Foo()` | `void Foo()` | Yes |
| `exported routine clink Foo()` | `extern "C" { void Foo() }` | Yes |

Anything not marked `exported` is emitted `static`.

---

### ⚠️ Overloads and C Linkage

C has no name mangling and cannot express two routines with the same name. When a second
overload of a name is declared, semantic analysis demotes every already declared overload
of that name from `clink` to `cpplink`, and demotes the incoming one as well. Each
demotion emits a warning carrying code `MI013`.

From `test_lib_mathlib.myra`:

```myra
// First: clink. Retroactively demoted when the second overload arrives.
exported routine clink Max(const A: int32; const B: int32): int32;
begin
  if A > B then
    return A;
  end;
  return B;
end;

// Second overload. Demotes both to cpplink, and warns.
exported routine Max(const A: float32; const B: float32): float32;
begin
  if A > B then
    return A;
  end;
  return B;
end;
```

The demotion is retroactive: `Max` was written `clink` and is not emitted `clink`. Both
`test_lib_mathlib.myra` and `test_dll_exports.myra` carry `/* ALLOW_WARNINGS */` for this
reason.

Two Myra modules still interoperate across a demoted overload, as `test_exe_usedll`
demonstrates: it declares the same two `add` overloads the dll declares, both sides are
demoted identically, and the call resolves.

---

### 📄 The Emitted Header

Every module emits a `.cpp` and a `.h` of the same name.

#### Header prologue

```cpp
#include <cstdint>
#include <string>
#include <array>
#include <vector>
#include <set>
#include <bitset>
#include <limits>
#define MYR_EXPORT
```

The header carries the standard includes and the `MYR_EXPORT` definition. `<print>` and
`myr_runtime.h` are emitted to the source only.

#### What reaches the header

| Declaration | Header | Source |
|---|---|---|
| `exported routine` | Forward declaration prefixed `MYR_EXPORT` | Full definition |
| `exported var` | `MYR_EXPORT extern <type> <name>;` | The definition |
| `exported type` | Full type | Header only |
| `exported const` | Full constant | Header only |
| Not `exported` | Nothing | `static` definition |

A `clink` forward declaration is wrapped:

```cpp
extern "C" {
MYR_EXPORT int32_t add(int32_t a, int32_t b);
}
```

For a `lib`, all of these sit inside `namespace <modname> { }`.

---

### 🔤 Type Mapping

The compiler maps Myra types to C++ types by a fixed table.

| Myra | C++ |
|---|---|
| `int8` / `int16` / `int32` / `int64` | `int8_t` / `int16_t` / `int32_t` / `int64_t` |
| `uint8` / `uint16` / `uint32` / `uint64` | `uint8_t` / `uint16_t` / `uint32_t` / `uint64_t` |
| `float32` | `float` |
| `float64` | `double` |
| `boolean` | `bool` |
| `char` | `char` |
| `wchar` | `wchar_t` |
| `pointer` | `void*` |
| `pointer to T` | `T*` |
| `string` | `std::string` |
| `wstring` | `std::wstring` |
| `array of T` | `std::vector<T>` |
| `set` | `MyrSet` |

`clink` places a routine in `extern "C"`. It does not change its parameter types: the
mapping above still applies.

---

### 🎯 Targets

Myra has six target aliases.

| Alias | Triple | Auto-run |
|---|---|---|
| `win64` | `x86_64-windows-gnu` | Yes, native |
| `winarm64` | `aarch64-windows-gnu` | No, warns |
| `linux64` | `x86_64-linux-gnu` | Yes, requires WSL |
| `linuxarm64` | `aarch64-linux-gnu` | No, warns |
| `macos64` | `aarch64-macos-none` | No, warns |
| `wasm32` | `wasm32-wasi` | Yes, in a browser |

A target that cannot auto-run warns; it never errors. The artifact is still built.

> [!NOTE]
> 📎 Myra-to-Myra linking is currently verified on `win64` only. `test_exe_usedll` and
> `test_exe_uselib` are green there. Artifact layout and import-library conventions
> differ per target, and those cases are not yet confirmed.

> [!CAUTION]
> 💥 `wasm32` builds with `-fno-exceptions`. `guard` / `except` is a hard compile error on
> this target.

<a id="how-to-guide"></a>

## 🧪 How-To Guide

Task-oriented recipes. Every program on this page is complete: copy it into a `.myra`
file, build it, run it. Nothing is elided.

### 📐 How to Read These Recipes

Every code sample below is lifted from a **passing test** in `bin/res/tests/`. The test
is named under each recipe. Where a construct has no test covering it, that is stated
plainly and the source of the claim is named instead. Nothing here is composed from the
grammar alone.

Run any recipe straight from source:

```
Myra -s program.myra -r
```

`-s` selects the source file, `-r` runs it after building. Use `-d` in place of `-r` to
build and step through it in the debugger. See [Tools](#tools) for the full flag list.

> [!NOTE]
> 📄 A module's declared name must match its filename. `module exe Hello;` must live in
> `Hello.myra`. Every recipe below is shown with the module name it was tested under.

### 🗺️ Recipe Map

| Need | Recipe |
|------|--------|
| 🖨️ Print something | [Hello World](#-hello-world), [Formatted Output](#-formatted-output) |
| 📦 Store a value | [Variables and Constants](#-variables-and-constants) |
| 🏷️ Name a type | [Type Aliases](#-type-aliases) |
| 🔄 Convert between types | [Type Casts](#-type-casts) |
| 🔤 Work with text | [Strings](#-strings), [Wide Strings](#-wide-strings) |
| 🚦 Branch | [If / Else](#-if--else), [Match](#-match) |
| 🔁 Loop | [Loops](#-loops) |
| 🔧 Reuse logic | [Routines](#-routines), [Overloading](#-overloading), [Recursion](#-recursion) |
| 🔀 Accept any number of arguments | [Variadic Routines](#-variadic-routines) |
| 🎣 Pass behavior as a value | [Routine Types](#-routine-types) |
| 📋 Model data | [Records](#-records), [Packed Records and Bitfields](#-packed-records-and-bitfields), [Record Inheritance](#-record-inheritance), [Overlays](#-overlays) |
| 🎛️ Enumerate | [Choices](#-choices) |
| 🧮 Work with sets | [Sets](#-sets) |
| 🗃️ Hold many values | [Static Arrays](#-static-arrays), [Dynamic Arrays](#-dynamic-arrays) |
| 📍 Work close to memory | [Pointers](#-pointers), [Heap Allocation](#-heap-allocation), [Raw Memory](#-raw-memory) |
| 🏛️ Model behavior | [Objects](#-objects), [Object Inheritance](#-object-inheritance), [Linked Structures](#-linked-structures) |
| 🛡️ Recover from failure | [Exceptions](#-exceptions) |
| 📥 Split code across files | [Modules and Imports](#-modules-and-imports) |
| 📚 Use what ships in the box | [The Standard Library](#-the-standard-library) |
| 🔗 Build and consume a DLL | [Shared Libraries](#-shared-libraries) |
| 🧰 Use raylib, SDL3, or any C library | [Vendor Libraries](#-vendor-libraries) |
| 🌉 Call C++ directly | [C++ Interop](#-c-interop) |
| 🔀 Compile differently per target | [Conditional Compilation](#-conditional-compilation) |
| ⚙️ Control the build | [Build Directives](#-build-directives) |
| 🧪 Test your code | [Unit Testing](#-unit-testing) |
| 💻 Read command-line arguments | [Command-Line Arguments](#-command-line-arguments) |
| 📏 Ask about a type | [Intrinsics](#-intrinsics) |

---

### 👋 Hello World

```myra
module exe test_exe_hello;

begin
  println("Hello from Myra!");
end.
```

Output:

```
Hello from Myra!
```

A module needs no imports to print. `println` is built in.

> Traced to `test_exe_hello.myra`.

### 🖨️ Formatted Output

`println` writes a line; `print` writes without the newline. Both take a format string
where `{}` is a placeholder, filled left to right from the arguments.

```myra
module exe Output;

var
  name: string;
  count: int32;
  ratio: float64;

begin
  name := "Myra";
  count := 3;
  ratio := 3.14159;

  println("plain line, no arguments");
  println("{}", name);
  println("{} and {} and {}", "one", "two", "three");
  println("name={} count={}", name, count);

  print("no newline: ");
  print("{} ", count);
  println("done");

  // A placeholder may carry a C++ format spec.
  println("{:.2f}", ratio);
end.
```

Output:

```
plain line, no arguments
Myra
one and two and three
name=Myra count=3
no newline: 3 done
3.14
```

The same argument may be used more than once, and a format string with no placeholders
is legal.

| Form | Meaning |
|---|---|
| `{}` | Next argument, default formatting |
| `{:.2f}` | Next argument, fixed to 2 decimal places |
| `{:.1f}` | Next argument, fixed to 1 decimal place |

> [!TIP]
> 💡 A `boolean` prints directly as `true` or `false`. Cast it with `int32(...)` if you
> want `1` / `0` instead.

> Traced to `test_exe_strings.myra`, `test_exe_control_flow.myra`, `test_exe_records.myra`.

### 📦 Variables and Constants

Variables are declared in a `var` section, constants in a `const` section. Both may
appear at module level or inside a routine.

```myra
module exe test_exe_consts;

const
  MaxItems: int32 = 100;
  AppName = "Myra Test";
  Version = 1;

begin
  println("{}", AppName);
  println("{}", MaxItems);
  println("{}", Version);
end.
```

Output:

```
Myra Test
100
1
```

A constant may carry an explicit type (`MaxItems: int32 = 100`) or let the literal decide
(`AppName = "Myra Test"`).

Variables are declared with a type and assigned with `:=`:

```myra
module exe test_exe_vars;

var
  x: int32;
  y: int32;
  name: string;
  pi: float64;

begin
  x := 10;
  y := 20;
  name := "Myra";
  pi := 3.14159;
  println("{}", x + y);
  println("{}", name);
  println("{}", pi);
end.
```

Output:

```
30
Myra
3.14159
```

> Traced to `test_exe_consts.myra`, `test_exe_vars.myra`.

### 🏷️ Type Aliases

A `type` section names a type. An alias of a builtin type is a first-class type name.

```myra
module exe Aliases;

type
  Counter = int32;
  Offset = float64;

var
  count: Counter;
  off: Offset;

begin
  count := 99;
  println("count = {}", count);

  off := 3.14;
  println("offset = {}", off);
end.
```

Output:

```
count = 99
offset = 3.14
```

> Traced to `test_exe_types.myra`.

### 🔄 Type Casts

A builtin type name, applied like a call, converts a value.

```myra
module exe Casts;

var
  d: float64;
  n: int32;

begin
  d := 3.7;

  n := int32(d);
  println("int32(3.7)   = {}", n);
  println("int64(n)     = {}", int64(n));
  println("float64(n)   = {}", float64(n));
  println("float32(n)   = {}", float32(n));
  println("uint8(255)   = {}", int32(uint8(255)));
end.
```

Output:

```
int32(3.7)   = 3
int64(n)     = 3
float64(n)   = 3
float32(n)   = 3
uint8(255)   = 255
```

Casts are also how you print a value that has no format of its own:

| Value | Print it with |
|---|---|
| A `choices` value | `int32(c)` |
| A `set` | `int64(s)` |
| A narrow integer (`int8`, `uint8`, `uint16`) | `int32(v)` |
| A `boolean`, if you want `1` / `0` | `int32(b)` |
| A `wstring` | `utf8(w)` |

A cast is also used to reinterpret a pointer, which is what makes pointer arithmetic
possible. See [Raw Memory](#-raw-memory).

> Traced to `test_exe_types.myra`, `test_exe_new_dispose.myra`, `test_exe_sets.myra`.

### 🔤 Strings

A `string` is UTF-8. Literals use double quotes and support C-style escapes.

```myra
module exe Strings;

var
  s: string;
  empty: string;

begin
  s := "Hello";
  println("{}, World!", s);

  // Escape sequences
  println("tab:\there");
  println("newline:\nhere");
  println("backslash: \\");
  println("quote: \"quoted\"");
  println("hex escape: \x41\x42\x43");

  // Empty string
  empty := "";
  println("empty=[{}]", empty);

  // len() is a BYTE count, not a character count
  println("len of Hello = {}", len(s));
  println("len of café  = {}", len("café"));

  // UTF-8 goes straight through
  println("emoji: 🔥🚀💡🎉");
  println("japanese: こんにちは世界");
  println("arabic: مرحبا");
end.
```

Output:

```
Hello, World!
tab:	here
newline:
here
backslash: \
quote: "quoted"
hex escape: ABC
empty=[]
len of Hello = 5
len of café  = 5
emoji: 🔥🚀💡🎉
japanese: こんにちは世界
arabic: مرحبا
```

> [!IMPORTANT]
> 📏 `len()` on a string returns the number of **bytes**, not characters. `"café"` is 4
> characters but 5 bytes, because `é` is two bytes in UTF-8. This is a deliberate
> systems-language choice: no hidden decoding pass.

| Escape | Meaning |
|---|---|
| `\t` | Tab |
| `\n` | Newline |
| `\r` | Carriage return |
| `\\` | Backslash |
| `\"` | Double quote |
| `\0` | NUL byte |
| `\xNN` | Byte with hex value NN |

> Traced to `test_exe_strings.myra`.

### 🈯 Wide Strings

A `wstring` is a UTF-16 string. Its literals carry a `w` prefix. Convert to `string`
with `utf8()` to print it.

```myra
module exe WideStrings;

var
  wide: wstring;

begin
  wide := w"Hello, Wide World!";
  println("{}", utf8(wide));

  wide := w"tab:\there";
  println("{}", utf8(wide));

  wide := w"🔥🚀💡";
  println("{}", utf8(wide));

  wide := w"ABCDE";
  println("wlen of ABCDE = {}", len(wide));
end.
```

Output:

```
Hello, Wide World!
tab:	here
🔥🚀💡
wlen of ABCDE = 5
```

`len()` on a `wstring` counts UTF-16 code units, not bytes.

> Traced to `test_exe_strings.myra`.

### 🚦 If / Else

Control-flow constructs carry their own terminating `end` and take no `begin`.

```myra
module exe Branch;

var
  x: int32;

begin
  x := 42;

  if x > 0 then
    println("positive");
  else
    println("non-positive");
  end;

  // else-if chains
  if x < 0 then
    println("negative");
  else
    if x = 0 then
      println("zero");
    else
      println("positive");
    end;
  end;
end.
```

Output:

```
positive
positive
```

Boolean operators are `and`, `or`, `not`:

```myra
  if (x > 0) and (x < 100) then
    println("in range");
  end;

  if not (x = 0) then
    println("not zero");
  end;
```

> Traced to `test_exe_ifelse.myra`, `test_exe_classes.myra`.

### 🔁 Loops

Four loop forms. Each terminates with `end`.

```myra
module exe test_exe_loops;

var
  i: int32;
  sum: int32;

begin
  // for .. to
  for i := 1 to 5 do
    println("{}", i);
  end;

  // for .. downto
  for i := 5 downto 1 do
    println("{}", i);
  end;

  // while
  sum := 0;
  i := 1;
  while i <= 10 do
    sum := sum + i;
    i := i + 1;
  end;
  println("{}", sum);

  // repeat .. until  (body runs at least once)
  i := 0;
  repeat
    i := i + 1;
  until i = 5;
  println("{}", i);
end.
```

Output:

```
1
2
3
4
5
5
4
3
2
1
55
5
```

Note the shape difference: `while` and `for` close with `end`, while `repeat` closes with
`until <condition>` and takes no `end`.

#### Breaking Out of a Loop

`leave` exits the innermost loop. `skip` advances to the next iteration.

> [!NOTE]
> 🔍 **No test in the repository uses `leave` or `skip`.** They are documented here from
> the emitter, which is the authority: `myra_emitters.mld:803-809` maps `stmt.leave` to
> C++ `break;` and `stmt.skip` to C++ `continue;`. The semantics are therefore exactly
> C's `break` and `continue`.

> Traced to `test_exe_loops.myra`, `test_exe_control_flow.myra`. `leave` / `skip` sourced
> from `myra_emitters.mld`.

### 🎯 Match

`match` selects on a value. An arm takes one or more labels, and a label may be a range.
An `else` arm is optional.

```myra
module exe Matching;

var
  x: int32;
  ch: char;
  result: int32;

begin
  // Single values
  x := 2;
  match x of
    1: println("one");
    2: println("two");
    3: println("three");
  else
    println("other");
  end;

  // Ranges
  x := 5;
  match x of
    1..3: println("one to three");
    4..6: println("four to six");
    7..9: println("seven to nine");
  else
    println("else");
  end;

  // Characters, including character ranges
  ch := 'm';
  match ch of
    'a'..'z': println("lowercase");
    'A'..'Z': println("uppercase");
    '0'..'9': println("digit");
  else
    println("other");
  end;

  // Negative ranges
  x := -5;
  match x of
    -10..-6: result := 1;
    -5..-1:  result := 2;
    0..5:    result := 3;
  else
    result := 0;
  end;
  println("negative -5 -> {}", result);

  // No else arm: nothing matches, nothing runs
  result := 999;
  x := 50;
  match x of
    1..10:  result := 1;
    20..30: result := 2;
  end;
  println("no else, 50 -> {}", result);
end.
```

Output:

```
two
four to six
lowercase
negative -5 -> 2
no else, 50 -> 999
```

Multiple labels on one arm are comma-separated:

```myra
  match day of
    1..5: println("weekday");
    6, 7: println("weekend");
  end;
```

> [!TIP]
> 💡 With no `else` arm and no matching label, the `match` simply does nothing. The
> `result := 999` above survives untouched, which is what the last line proves.

> Traced to `test_exe_control_flow.myra`, `test_exe_match.myra`.

### 🔧 Routines

A routine declares parameters and an optional return type. `return` exits with a value.

```myra
module exe Routines;

// Value parameters. const is the normal case.
routine add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

// var parameters pass by reference.
routine inc(var x: int32);
begin
  x := x + 1;
end;

// A routine with no return type returns nothing.
routine greet(const who: string);
begin
  println("hello, {}", who);
end;

// Local variables get their own var section.
routine factorial(const n: int32): int32;
var
  result: int32;
  i: int32;
begin
  result := 1;
  for i := 1 to n do
    result := result * i;
  end;
  return result;
end;

var
  x: int32;

begin
  println("add(3, 4) = {}", add(3, 4));

  x := 10;
  inc(x);
  println("after inc: x = {}", x);

  greet("Myra");

  println("factorial(5) = {}", factorial(5));

  // Calls nest freely.
  println("add(add(1, 2), 3) = {}", add(add(1, 2), 3));
end.
```

Output:

```
add(3, 4) = 7
after inc: x = 11
hello, Myra
factorial(5) = 120
add(add(1, 2), 3) = 6
```

| Modifier | Meaning |
|---|---|
| `const` | Pass by value. The routine cannot change the caller's variable. |
| `var` | Pass by reference. Assignments inside the routine are visible to the caller. |

> Traced to `test_exe_routines.myra`.

### 🎭 Overloading

Two routines may share a name if their parameter types differ. The call site picks the
match.

```myra
module exe Overloads;

routine max(const a: int32; const b: int32): int32;
begin
  if a > b then
    return a;
  end;
  return b;
end;

routine max(const a: float64; const b: float64): float64;
begin
  if a > b then
    return a;
  end;
  return b;
end;

begin
  println("max(3, 7)       = {}", max(3, 7));
  println("max(3.5, 2.8)   = {}", max(3.5, 2.8));
end.
```

Output:

```
max(3, 7)       = 7
max(3.5, 2.8)   = 3.5
```

An unsuffixed float literal resolves from context. Assigning `max(1.5, 2.3)` into a
`float32` picks the `float32` overload; assigning it into a `float64` picks the `float64`
one.

> [!WARNING]
> 🔗 **Overloading forces C++ linkage.** A routine marked `clink` that is then overloaded
> gets demoted to `cpplink`, because C has no name mangling and cannot express two
> functions with one name. The compiler emits a warning when it does this. See
> [Shared Libraries](#-shared-libraries) for why that matters at an FFI boundary.

> Traced to `test_exe_routines.myra`, `test_lib_mathlib.myra`, `test_exe_uselib.myra`.

### 🔄 Recursion

A routine may call itself. No special marker is needed.

```myra
module exe Recursion;

routine fib(const n: int32): int32;
begin
  if n <= 1 then
    return n;
  end;
  return fib(n - 1) + fib(n - 2);
end;

begin
  println("fib(0)  = {}", fib(0));
  println("fib(1)  = {}", fib(1));
  println("fib(10) = {}", fib(10));
end.
```

Output:

```
fib(0)  = 0
fib(1)  = 1
fib(10) = 55
```

> Traced to `test_exe_routines.myra`.

### 🔀 Variadic Routines

A parameter list of `...` makes a routine variadic. `varargs.count` gives the number of
arguments passed; `varargs.next(type)` reads the next one.

```myra
module exe test_exe_variadic_routines;

routine sumInts(...): int32;
var
  i: int32;
  sum: int32;
  arg: int32;
begin
  sum := 0;
  for i := 0 to varargs.count - 1 do
    arg := varargs.next(int32);
    sum := sum + arg;
  end;
  return sum;
end;

routine sumFloats(...): float64;
var
  i: int32;
  sum: float64;
  arg: float64;
begin
  sum := 0.0;
  for i := 0 to varargs.count - 1 do
    arg := varargs.next(float64);
    sum := sum + arg;
  end;
  return sum;
end;

begin
  println("sumInts(10, 20, 30)     = {}", sumInts(10, 20, 30));
  println("sumInts(1, 2, 3, 4, 5)  = {}", sumInts(1, 2, 3, 4, 5));
  println("sumInts()               = {}", sumInts());
  println("sumFloats(1.5, 2.5, 3.0) = {}", sumFloats(1.5, 2.5, 3.0));
end.
```

Output:

```
sumInts(10, 20, 30)     = 60
sumInts(1, 2, 3, 4, 5)  = 15
sumInts()               = 0
sumFloats(1.5, 2.5, 3.0) = 7
```

Calling with zero arguments is legal: `varargs.count` is `0` and the loop body never runs.

> [!IMPORTANT]
> ➡️ **`varargs.next` is a one-way cursor.** It reads arguments strictly in the order
> they were passed, once each. There is no random access and no rewind. `varargs.next(T)`
> is a **claim** about the next argument's type, not a query: name the wrong type and you
> get garbage, and every later read is misaligned too. Nothing checks this. Read them in
> the order you passed them.

> Traced to `test_exe_variadic_routines.myra`.

### 🎣 Routine Types

A routine type is a callable value. It is how you pass behavior around.

```myra
module exe test_exe_routine_type_linkage;

type
  // C++ linkage (the default)
  TIntFunc = routine(const a: int32; const b: int32): int32;

  // C linkage, for C library callbacks
  TCCallback = routine clink (const x: int32): int32;
  TEventHandler = routine clink (const code: int32; const data: pointer): int32;

var
  mathOp: TIntFunc;
  cCallback: TCCallback;
  eventHandler: TEventHandler;

routine Add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

routine clink DoubleValue(const x: int32): int32;
begin
  return x * 2;
end;

routine clink HandleEvent(const code: int32; const data: pointer): int32;
begin
  return code;
end;

begin
  mathOp := Add;
  println("TIntFunc callback: {}", mathOp(10, 20));

  cCallback := DoubleValue;
  println("TCCallback result: {}", cCallback(100));

  eventHandler := HandleEvent;
  println("TEventHandler result: {}", eventHandler(42, nil));
end.
```

Output:

```
TIntFunc callback: 30
TCCallback result: 200
TEventHandler result: 42
```

Assign a routine to a variable of matching type by naming it without parentheses
(`mathOp := Add`), then call the variable as if it were the routine.

> [!TIP]
> 🔌 A callback you hand to a **C library** must be declared `routine clink (...)`. The
> linkage is part of the type, and it has to match what the C side expects.

> Traced to `test_exe_routine_type_linkage.myra`.

### 📋 Records

A record groups named fields.

```myra
module exe Records;

type
  Point = record
    x: int32;
    y: int32;
  end;

  // Fields may be any type.
  MixedRec = record
    b: int8;
    i: int32;
    l: int64;
    f: float64;
    flag: boolean;
    ch: char;
  end;

  // Records nest.
  Line = record
    start: Point;
    finish: Point;
  end;

var
  p: Point;
  m: MixedRec;
  line: Line;
  litPoint: Point;

begin
  p.x := 10;
  p.y := 20;
  println("Basic: {}, {}", p.x, p.y);

  m.b := 1;
  m.i := 1000;
  m.l := 100000;
  m.f := 3.14;
  m.flag := true;
  m.ch := 'A';
  println("Types: {}, {}, {}, {:.2f}, {}, {}", m.b, m.i, m.l, m.f, m.flag, m.ch);

  // Nested field access chains with dots.
  line.start.x := 5;
  line.start.y := 10;
  println("Nested: {}, {}", line.start.x, line.start.y);

  // A record literal constructs from positional values.
  litPoint := Point(77, 88);
  println("Literal: {}, {}", litPoint.x, litPoint.y);
end.
```

Output:

```
Basic: 10, 20
Types: 1, 1000, 100000, 3.14, true, A
Nested: 5, 10
Literal: 77, 88
```

Note that `m.flag` prints as `true` with no cast: a `boolean` has its own format.

#### Controlling Layout

A record may declare an alignment, and `align` accepts 1, 2, 4, 8 and 16.

```myra
type
  Align16Rec = record align(16)
    a: int8;
    b: int8;
  end;
```

> Traced to `test_exe_records.myra`.

### 🗜️ Packed Records and Bitfields

`record packed` removes padding. Inside a packed record, a trailing `: N` on a field is a
bitfield width in bits.

```myra
module exe Packing;

type
  PackedRec = record packed
    a: int8;
    b: int8;
    c: int8;
  end;

  BitRec = record packed
    a: uint8 : 3;
    b: uint8 : 2;
    c: uint8 : 1;
  end;

var
  pk: PackedRec;
  bits: BitRec;

begin
  pk.a := 1;
  pk.b := 2;
  pk.c := 3;
  println("Packed: {}, {}, {}", pk.a, pk.b, pk.c);
  println("PackedSize: {}", size(PackedRec));

  bits.a := 7;   // 3 bits: max 7
  bits.b := 3;   // 2 bits: max 3
  bits.c := 1;   // 1 bit:  max 1
  println("Bits: {}, {}, {}",
    static_cast<int>(bits.a),
    static_cast<int>(bits.b),
    static_cast<int>(bits.c));
end.
```

Output:

```
Packed: 1, 2, 3
PackedSize: 3
Bits: 7, 3, 1
```

> [!NOTE]
> 🌉 The `static_cast<int>` above is not Myra syntax. It is **C++ passing straight
> through**, which is how the test prints a bitfield. This is the passthrough pillar in
> action: an unrecognized token goes to the C++ compiler verbatim. See
> [C++ Interop](#-c-interop).

> Traced to `test_exe_records.myra`.

### 🧬 Record Inheritance

A record may name a parent record in parentheses. It inherits the parent's fields.

```myra
module exe RecInherit;

type
  Point = record
    x: int32;
    y: int32;
  end;

  Point3D = record(Point)
    z: int32;
  end;

var
  p3d: Point3D;

begin
  p3d.x := 100;   // inherited
  p3d.y := 200;   // inherited
  p3d.z := 300;   // its own
  println("Inherit: {}, {}, {}", p3d.x, p3d.y, p3d.z);
end.
```

Output:

```
Inherit: 100, 200, 300
```

> Traced to `test_exe_records.myra`, `test_exe_new_dispose.myra`.

### 🧊 Overlays

An `overlay` lays every field at the same address. It is the classic union: writing one
field overwrites the others.

```myra
module exe Overlays;

type
  IntOrFloat = overlay
    i: int32;
    f: float32;
  end;

  // A record may contain an anonymous overlay.
  RecWithAnonOverlay = record
    tag: int32;
    overlay
      asInt: int32;
      asFloat: float32;
    end;
  end;

  // An overlay may contain an anonymous record. This is how you split a
  // 64-bit value into two 32-bit halves.
  OverlayWithAnonRec = overlay
    single: int64;
    record
      lo: int32;
      hi: int32;
    end;
  end;

var
  u: IntOrFloat;
  rau: RecWithAnonOverlay;
  uwar: OverlayWithAnonRec;

begin
  u.i := 42;
  println("Union: {}", u.i);
  u.f := 3.14;                    // this overwrites u.i
  println("UnionFloat: {:.2f}", u.f);

  rau.asInt := 99;
  println("AnonUnion: {}", rau.asInt);

  uwar.lo := 11;
  uwar.hi := 22;
  println("AnonRecord: {}, {}", uwar.lo, uwar.hi);
end.
```

Output:

```
Union: 42
UnionFloat: 3.14
AnonUnion: 99
AnonRecord: 11, 22
```

Fields of an anonymous member are reached directly, with no intermediate name.

> Traced to `test_exe_records.myra`.

### 🎛️ Choices

`choices` declares an enumeration. Values may be given explicitly, and may have gaps.

```myra
module exe test_exe_types;

type
  Color = choices(Red, Green, Blue);
  ErrorCode = choices(None = 0, NotFound = 404, Internal = 500);

var
  c: Color;
  ec: ErrorCode;

begin
  c := Green;                              // unqualified: not Color.Green
  println("Color Green = {}", int32(c));

  ec := NotFound;
  println("ErrorCode NotFound = {}", int32(ec));

  ec := Internal;
  println("ErrorCode Internal = {}", int32(ec));
end.
```

Output:

```
Color Green = 1
ErrorCode NotFound = 404
ErrorCode Internal = 500
```

> [!IMPORTANT]
> 🎛️ Two things trip people up. **Choice values are used bare** (`Green`), never qualified
> with the type name. And **a choice value has no print format of its own**, so cast it
> with `int32(...)` to print it.

Without explicit values, numbering starts at 0 and increments: `Red` is 0, `Green` is 1,
`Blue` is 2.

> Traced to `test_exe_types.myra`.

### 🧮 Sets

A `set` holds members from an ordinal range. Membership is tested with `in`. A set literal
uses brackets and may contain ranges.

```myra
module exe test_exe_sets;

var
  s1: set;
  s2: set;
  s3: set;

begin
  s1 := [];               // empty
  s1 := [1, 3, 5];        // explicit members
  s1 := [1..5];           // a range
  s1 := [1, 5, 6, 10];    // mixed

  s1 := [1, 3, 5];
  s2 := [3, 5, 10];

  s3 := s1 + s2;          // union        -> [1, 3, 5, 10]
  s3 := s1 * s2;          // intersection -> [3, 5]
  s3 := s1 - s2;          // difference   -> [1]

  // Membership
  s1 := [1, 3, 5, 10];
  if 5 in s1 then
    println("5 in s1: true");
  else
    println("5 in s1: false");
  end;

  if 2 in s1 then
    println("2 in s1: true");
  else
    println("2 in s1: false");
  end;

  // Sets compare with = and <>
  s1 := [1, 2, 3];
  s2 := [1, 2, 4];
  if s1 <> s2 then
    println("Sets not equal: true");
  end;

  // A set has no format of its own. Cast to see the bits.
  println("Difference bits = {}", int64([1, 3, 5] - [3, 5, 10]));
end.
```

Output:

```
5 in s1: true
2 in s1: false
Sets not equal: true
Difference bits = 2
```

The operators carry their classic Pascal set meanings:

| Operator | Meaning |
|---|---|
| `+` | Union |
| `*` | Intersection |
| `-` | Difference |
| `in` | Membership test |
| `=` / `<>` | Equality / inequality |

#### Set of Choices

A set may be typed over a `choices` enumeration, which is the common case.

```myra
module exe test_exe_sets_enum;

type
  Color = choices(Red, Green, Blue, Yellow);
  SparseEnum = choices(A = 0, B = 5, C = 10);

var
  colors: set of Color;
  colors2: set of Color;
  sparse: set of SparseEnum;

begin
  colors := [Red, Blue];

  if Red in colors then
    println("Red in colors: true");
  end;

  if Green in colors then
    println("Green in colors: true");
  else
    println("Green in colors: false");
  end;

  // Add a member by union
  colors := colors + [Green];
  if Green in colors then
    println("After adding Green: true");
  end;

  // Enumerations with gaps work
  sparse := [A, C];
  if C in sparse then
    println("C in sparse: true");
  end;
  if B in sparse then
    println("B in sparse: true");
  else
    println("B in sparse: false");
  end;
end.
```

Output:

```
Red in colors: true
Green in colors: false
After adding Green: true
C in sparse: true
B in sparse: false
```

A set may also be constrained to a numeric subrange: `s: set of 1..9;`

> Traced to `test_exe_sets.myra`, `test_exe_sets_enum.myra`.

### 🗃️ Static Arrays

A static array has a fixed index range, known at compile time.

```myra
module exe StaticArrays;

type
  IntArray = array[0..9] of int32;
  SmallBuf = array[0..2] of float64;

var
  nums: IntArray;
  buf: SmallBuf;
  i: int32;

begin
  for i := 0 to 4 do
    nums[i] := i * i;
  end;

  for i := 0 to 4 do
    println("nums[{}] = {}", i, nums[i]);
  end;

  buf[0] := 1.5;
  buf[1] := 2.7;
  buf[2] := 3.9;
  println("buf: {}, {}, {}", buf[0], buf[1], buf[2]);

  // len() gives the element count.
  println("IntArray len = {}", len(nums));
  println("SmallBuf len = {}", len(buf));
end.
```

Output:

```
nums[0] = 0
nums[1] = 1
nums[2] = 4
nums[3] = 9
nums[4] = 16
buf: 1.5, 2.7, 3.9
IntArray len = 10
SmallBuf len = 3
```

> Traced to `test_exe_types.myra`.

### 📈 Dynamic Arrays

A dynamic array is declared `array of T` with no bounds. `setlength` sizes it; `len`
reports its length.

```myra
module exe test_exe_dynamic_arrays;

type
  Point = record
    x: int32;
    y: int32;
  end;

  Person = record
    personName: string;
    age: int32;
  end;

var
  arr: array of int32;
  points: array of Point;
  names: array of string;
  people: array of Person;

begin
  // Size it, then use it.
  setlength(arr, 3);
  arr[0] := 10;
  arr[1] := 20;
  arr[2] := 30;
  println("Basic: {} {} {}", arr[0], arr[1], arr[2]);
  println("Len: {}", len(arr));

  // Growing preserves existing elements and zeroes the new ones.
  setlength(arr, 5);
  println("Grow: {} {} {} {} {}", arr[0], arr[1], arr[2], arr[3], arr[4]);

  // Shrinking keeps the first N elements.
  setlength(arr, 2);
  println("Shrink: {} {}", arr[0], arr[1]);

  // Arrays of records.
  setlength(points, 2);
  points[0].x := 10;
  points[0].y := 20;
  points[1].x := 30;
  points[1].y := 40;
  println("Records: {} {} {} {}",
    points[0].x, points[0].y, points[1].x, points[1].y);

  // Arrays of strings. Managed: assigning frees the old value.
  setlength(names, 3);
  names[0] := "Alice";
  names[1] := "Bob";
  names[2] := "Charlie";
  println("Strings: {} {} {}", names[0], names[1], names[2]);
  names[0] := "NewAlice";
  println("Reassign: {}", names[0]);

  // Arrays of records containing managed fields.
  setlength(people, 2);
  people[0].personName := "John";
  people[0].age := 25;
  people[1].personName := "Jane";
  people[1].age := 30;
  println("People: {} {} {} {}",
    people[0].personName, people[0].age,
    people[1].personName, people[1].age);
end.
```

Output:

```
Basic: 10 20 30
Len: 3
Grow: 10 20 30 0 0
Shrink: 10 20
Records: 10 20 30 40
Strings: Alice Bob Charlie
Reassign: NewAlice
People: John 25 Jane 30
```

> [!TIP]
> 🧹 **Cleanup is automatic.** A dynamic array and its managed elements (strings,
> wstrings, records containing them) are released when they go out of scope. There is
> nothing to free by hand.

An `array[] of T` is an **open array** and behaves identically to `array of T`: declare
it, `setlength` it, index it, `len` it.

> Traced to `test_exe_dynamic_arrays.myra`, `test_exe_types.myra`.

### 📍 Pointers

`pointer to T` is a typed pointer. `address of` takes an address. A postfix `^`
dereferences.

```myra
module exe test_exe_pointers;

var
  x: int32;
  p: pointer to int32;

begin
  x := 42;
  println("x = {}", x);

  p := address of x;
  println("Value via pointer: {}", p^);

  p^ := 100;
  println("x is now: {}", x);
end.
```

Output:

```
x = 42
Value via pointer: 42
x is now: 100
```

A bare `pointer` is untyped, the equivalent of C's `void*`. `nil` is the null pointer.

#### Reaching a Field Through a Pointer

Use a **plain `.`**. Myra knows the operand is a pointer and emits the C++ arrow for you:

```myra
  create(p);
  p.value := 99;        // no ^ needed
  println("{}", p.value);
```

The explicit form also works. `p^` dereferences to a value, and `.` then selects a field
on it, so `p^.value` is equivalent:

```myra
  create(pPoint);
  pPoint^.X := 10;
  pPoint^.Y := 20;
  println("Point: {}, {}", pPoint^.X, pPoint^.Y);
```

Both compile. **Prefer the plain `.`** -- it is the idiomatic form, and it is what the
object recipes below use throughout.

> Traced to `test_exe_pointers.myra` (`^` read and write), `test_exe_classes.myra`
> (plain `.`), `test_exe_new_dispose.myra` (`^.`).

### 🧠 Heap Allocation

`create` allocates and constructs. `destroy` destructs and frees. They work on a pointer
to anything: a builtin type, a record, or an object.

```myra
module exe test_exe_new_dispose;

type
  TPoint = record
    X: int32;
    Y: int32;
  end;

  TRect = record
    TopLeft: TPoint;
    BottomRight: TPoint;
  end;

var
  pInt: pointer to int32;
  pPoint: pointer to TPoint;
  pRect: pointer to TRect;

begin
  // A builtin type
  create(pInt);
  pInt^ := 42;
  println("int: {}", pInt^);
  destroy(pInt);

  // A record
  create(pPoint);
  pPoint^.X := 10;
  pPoint^.Y := 20;
  println("Point: {}, {}", pPoint^.X, pPoint^.Y);
  destroy(pPoint);

  // A nested record
  create(pRect);
  pRect^.TopLeft.X := 0;
  pRect^.TopLeft.Y := 0;
  pRect^.BottomRight.X := 100;
  pRect^.BottomRight.Y := 200;
  println("Rect: {}, {} to {}, {}",
    pRect^.TopLeft.X, pRect^.TopLeft.Y,
    pRect^.BottomRight.X, pRect^.BottomRight.Y);
  destroy(pRect);
end.
```

Output:

```
int: 42
Point: 10, 20
Rect: 0, 0 to 100, 200
```

> [!IMPORTANT]
> 🚫 It is `create` / `destroy`. Not `new` / `dispose`.

Every builtin type works: `int8` through `int64`, `uint8` through `uint32`, `float32`,
`float64`, `boolean`, `char`. So do records with inheritance and packed records.

> Traced to `test_exe_new_dispose.myra`.

### 🧱 Raw Memory

`getmem` allocates a block of bytes, `resizemem` grows or shrinks it preserving contents,
`freemem` releases it. Cast the block to a typed pointer to reach into it, and add an
integer to that pointer to move through it.

```myra
module exe test_exe_memory;

var
  p: pointer;
  pb: pointer to int8;

begin
  p := getmem(100);
  println("Allocated 100 bytes");

  // Write at offset 0
  pb := pointer to int8(p);
  pb^ := 42;
  println("Value at offset 0: {}", pb^);

  // Pointer arithmetic: advance 50 elements
  pb := pointer to int8(p) + 50;
  pb^ := 99;
  println("Value at offset 50: {}", pb^);

  // Resize preserves the contents
  p := resizemem(p, 200);
  println("Resized to 200 bytes");

  pb := pointer to int8(p);
  println("Value preserved: {}", pb^);

  pb := pointer to int8(p) + 50;
  println("Offset 50 preserved: {}", pb^);

  freemem(p);
  println("Memory freed");
end.
```

Output:

```
Allocated 100 bytes
Value at offset 0: 42
Value at offset 50: 99
Resized to 200 bytes
Value preserved: 42
Offset 50 preserved: 99
Memory freed
```

> [!NOTE]
> ➕ **Pointer arithmetic counts elements, not bytes**, exactly as in C. On a
> `pointer to int8` those happen to coincide. On a `pointer to int32`, `+ 1` advances 4
> bytes.

`resizemem` returns the block, which may have moved. Always assign its result back:
`p := resizemem(p, 200);`

| Routine | Purpose |
|---|---|
| `getmem(n)` | Allocate `n` bytes, returns `pointer` |
| `resizemem(p, n)` | Resize to `n` bytes preserving contents, returns the block |
| `freemem(p)` | Release the block |
| `create(p)` | Allocate and construct one `T` for a `pointer to T` |
| `destroy(p)` | Destruct and free |

> Traced to `test_exe_memory.myra`.

### 🏛️ Objects

An `object` carries fields and methods. Instances live on the heap: allocate with
`create`, release with `destroy`. Inside a method, `self` is the instance.

```myra
module exe Objects;

type
  TCounter = object
    Count: int32;
    Name_: string;

    method Reset();
    begin
      self.Count := 0;
    end;

    method SetCount(AValue: int32);
    begin
      self.Count := AValue;
    end;

    method GetCount(): int32;
    begin
      return self.Count;
    end;

    method SetName(AName: string);
    begin
      self.Name_ := AName;
    end;

    method GetName(): string;
    begin
      return self.Name_;
    end;

    // Methods take var parameters too.
    method GetCountByRef(var AOut: int32);
    begin
      AOut := self.Count;
    end;
  end;

var
  c1: pointer to TCounter;
  c2: pointer to TCounter;
  tempVal: int32;

// An object instance is passed as a pointer.
routine PrintCounter(ACounter: pointer to TCounter);
begin
  println("Counter \"{}\" = {}", ACounter.GetName(), ACounter.GetCount());
end;

routine DoubleCounter(ACounter: pointer to TCounter);
begin
  ACounter.SetCount(ACounter.GetCount() * 2);
end;

begin
  create(c1);
  create(c2);

  c1.SetCount(100);
  c1.SetName("First");
  c2.SetCount(200);
  c2.SetName("Second");

  // Instances are independent.
  PrintCounter(c1);
  PrintCounter(c2);

  // A routine can modify an instance through its pointer.
  c1.SetCount(50);
  DoubleCounter(c1);
  println("After doubling: {}", c1.GetCount());

  // var parameter on a method
  c2.GetCountByRef(tempVal);
  println("By ref: {}", tempVal);

  destroy(c1);
  destroy(c2);
end.
```

Output:

```
Counter "First" = 100
Counter "Second" = 200
After doubling: 100
By ref: 200
```

> [!IMPORTANT]
> 🏛️ It is `object`, not `class`. Method parameters are declared without a `const`
> prefix in the tested code (`method SetCount(AValue: int32)`), and members are reached
> with a plain `.` even though the variable is a pointer.

Methods may be overloaded, exactly like routines:

```myra
  TCalculator = object
    LastResult: int32;

    method Add(A: int32; B: int32): int32;
    begin
      self.LastResult := A + B;
      return self.LastResult;
    end;

    method Add(A: int32; B: int32; C: int32): int32;
    begin
      self.LastResult := A + B + C;
      return self.LastResult;
    end;
  end;
```

A method may return an object pointer, and a routine may create and return one:

```myra
routine CreatePoint(AX: int32; AY: int32): pointer to TPoint;
var
  p: pointer to TPoint;
begin
  create(p);
  p.SetXY(AX, AY);
  return p;
end;
```

> Traced to `test_exe_classes.myra`.

### 🧬 Object Inheritance

An object may name a parent in parentheses. It inherits the parent's fields and methods.
A method redeclared in the child **overrides** the parent's, and `parent` reaches the base
implementation.

```myra
module exe ObjInherit;

type
  TAnimal = object
    Name_: string;
    Age: int32;

    method Init(AName: string; AAge: int32);
    begin
      self.Name_ := AName;
      self.Age := AAge;
    end;

    method Speak();
    begin
      println("Animal {} says: ...", self.Name_);
    end;

    method Describe();
    begin
      println("I am {}, age {}", self.Name_, self.Age);
    end;
  end;

  TDog = object(TAnimal)
    Breed: string;

    method Init(AName: string; AAge: int32; ABreed: string);
    begin
      self.Name_ := AName;
      self.Age := AAge;
      self.Breed := ABreed;
    end;

    // Override
    method Speak();
    begin
      println("Dog {} says: Woof!", self.Name_);
    end;

    // Override that calls up to the base implementation
    method Describe();
    begin
      parent.Describe();
      println("I am a {} breed", self.Breed);
    end;
  end;

var
  dog: pointer to TDog;
  polyAnimal: pointer to TAnimal;

begin
  create(dog);
  dog.Init("Buddy", 3, "Golden Retriever");

  dog.Speak();
  dog.Describe();

  // Inherited fields are reachable directly.
  println("Name (inherited): {}", dog.Name_);
  println("Breed (own):      {}", dog.Breed);

  // Virtual dispatch: cast to the base pointer, still calls TDog.Speak.
  polyAnimal := pointer to TAnimal(dog);
  polyAnimal.Speak();

  destroy(dog);
end.
```

Output:

```
Dog Buddy says: Woof!
I am Buddy, age 3
I am a Golden Retriever breed
Name (inherited): Buddy
Breed (own):      Golden Retriever
Dog Buddy says: Woof!
```

The last line is the point: `polyAnimal` is declared `pointer to TAnimal`, but calling
`Speak()` through it runs **TDog's** override. **Method dispatch is virtual.**

> Traced to `test_exe_classes.myra`.

### 🔗 Linked Structures

An object may point at its own type. Declare the pointer type first, then the object.

```myra
module exe LinkedList;

type
  PNode = pointer to TNode;

  TNode = object
    Value: int32;
    Next: PNode;

    method SetValue(AValue: int32);
    begin
      self.Value := AValue;
    end;

    method GetValue(): int32;
    begin
      return self.Value;
    end;

    method SetNext(ANext: PNode);
    begin
      self.Next := ANext;
    end;

    method GetNext(): PNode;
    begin
      return self.Next;
    end;
  end;

var
  node1: PNode;
  node2: PNode;
  node3: PNode;

begin
  create(node1);
  create(node2);
  create(node3);

  node1.SetValue(1);
  node2.SetValue(2);
  node3.SetValue(3);

  node1.SetNext(node2);
  node2.SetNext(node3);
  node3.SetNext(nil);

  // Calls chain.
  println("{} -> {} -> {}",
    node1.GetValue(),
    node1.GetNext().GetValue(),
    node1.GetNext().GetNext().GetValue());

  destroy(node1);
  destroy(node2);
  destroy(node3);
end.
```

Output:

```
1 -> 2 -> 3
```

`PNode = pointer to TNode;` is declared **before** `TNode` exists. That forward reference
is what makes the self-referential type possible.

Compare pointers against `nil` with `=` and `<>`:

```myra
    method Equals(AOther: pointer to TPoint): boolean;
    begin
      if AOther = nil then
        return false;
      end;
      return (self.X = AOther.X) and (self.Y = AOther.Y);
    end;
```

> Traced to `test_exe_classes.myra`.

### 🛡️ Exceptions

`guard` opens a protected block. It requires at least one of `except` or `finally`.

```myra
module exe test_exe_exceptions;

routine getZero(): int32;
begin
  return 0;
end;

var
  x: int32;

begin
  // Catch a raised exception.
  guard
    raiseexception("Test error");
    println("Should not print");
  except
    println("Caught: code={}, msg={}",
      getexceptioncode(), getexceptionmessage());
  end;

  // finally always runs, exception or not.
  guard
    println("In guard block");
  finally
    println("In finally block");
  end;

  // All three together.
  guard
    println("In guard block");
    raiseexception("Error!");
  except
    println("In except block: code={}", getexceptioncode());
  finally
    println("In finally block");
  end;

  // Raise with an explicit code.
  guard
    raiseexceptioncode(42, "Custom error");
  except
    println("Custom code: {}, msg={}",
      getexceptioncode(), getexceptionmessage());
  end;

  // Hardware faults are catchable too.
  guard
    x := 10 div getZero();
    println("Should not print: {}", x);
  except
    println("Hardware: code={}, msg={}",
      getexceptioncode(), getexceptionmessage());
  end;

  // guard blocks nest.
  guard
    guard
      raiseexception("Inner error");
    except
      println("Inner exception caught");
    end;
  finally
    println("Outer finally");
  end;
end.
```

Output:

```
Caught: code=1, msg=Test error
In guard block
In finally block
In guard block
In except block: code=1
In finally block
Custom code: 42, msg=Custom error
Hardware: code=2, msg=Divide by zero
Inner exception caught
Outer finally
```

| Builtin | Purpose |
|---|---|
| `raiseexception(msg)` | Raise with message, code 1 |
| `raiseexceptioncode(n, msg)` | Raise with an explicit code |
| `getexceptioncode()` | The code, inside an `except` block |
| `getexceptionmessage()` | The message, inside an `except` block |

Exceptions **propagate out of routines**. A routine that raises and does not catch will
unwind into its caller's `guard`:

```myra
routine throwingRoutine();
begin
  raiseexception("Propagated error");
end;

routine testPropagation();
begin
  guard
    throwingRoutine();
  except
    println("Caught propagated: code={}", getexceptioncode());
  end;
end;
```

Locals, parameters and globals are all readable and writable inside a `guard`, and
changes made there survive the block.

> [!WARNING]
> 🚫 **`guard` / `except` is a hard compile error on the `wasm32` target.** C++ exceptions
> are impossible on that toolchain, so wasm builds pass `-fno-exceptions`. If you intend
> to ship to wasm, return error values instead of raising them.

> Traced to `test_exe_exceptions.myra`.

### 📥 Modules and Imports

Split code across files by building a `lib` module. Only routines marked `exported` are
visible to importers. A module's name must match its filename.

**`test_lib_math.myra`** -- the library:

```myra
module lib test_lib_math;

// Private. Not visible outside this module.
routine dbl(const x: int32): int32;
begin
  return x + x;
end;

// Public. Visible to importers.
exported routine clink add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

// Public, and calls the private helper internally.
exported routine clink quadruple(const x: int32): int32;
begin
  return dbl(dbl(x));
end;

end.
```

**`test_exe_import.myra`** -- the consumer:

```myra
module exe test_exe_import;

import test_lib_math;

begin
  println("{}", test_lib_math.add(3, 5));
  println("{}", test_lib_math.quadruple(5));
end.
```

Output:

```
8
20
```

Imported names are **qualified with the module name**: `test_lib_math.add(3, 5)`.

Import several modules in one clause:

```myra
import
  Maths,
  StrUtils,
  Convert;
```

> [!IMPORTANT]
> 🔒 **`exported` is the whole visibility system.** A routine without it is private to its
> module. A `lib` whose routines all lack `exported` exports nothing at all and cannot be
> used by anyone. There is no third visibility level.

Visibility is independent of linkage, and all four combinations are legal:

| Declaration | Result |
|---|---|
| `routine Foo()` | Private, C++ linkage |
| `routine clink Foo()` | Private, C linkage |
| `exported routine Foo()` | Public, C++ linkage |
| `exported routine clink Foo()` | Public, C linkage, unmangled name |

> Traced to `test_lib_math.myra`, `test_exe_import.myra`, `test_lib_mathlib.myra`,
> `test_exe_uselib.myra`.

### 📚 The Standard Library

Nine modules ship with the compiler and are always on the module search path. Nothing to
install, nothing to configure. Just `import`.

```myra
module exe test_exe_std;

import
  Maths,
  StrUtils,
  Console,
  Convert,
  Paths,
  DateTime,
  Files,
  Assertions,
  Geometry;

var
  LRect: Geometry.TRect;

begin
  println("Sqrt(4.0)            = {}", Maths.Sqrt(4.0));
  println("Abs(-5)              = {}", Maths.Abs(-5));
  println("Min(3, 7)            = {}", Maths.Min(3, 7));

  println("UpperCase(\"hello\")   = {}", StrUtils.UpperCase("hello"));
  println("Trim(\"  x  \")        = {}", StrUtils.Trim("  x  "));
  println("Length(\"test\")       = {}", StrUtils.Length("test"));

  println("{}Console test (green){}", Console.clGreen, Console.clReset);

  println("IntToStr(42)         = {}", Convert.IntToStr(42));
  println("StrToInt(\"123\")      = {}", Convert.StrToInt("123"));
  println("BoolToStr(true)      = {}", Convert.BoolToStr(true));

  println("ExtractFileExt       = {}", Paths.ExtractFileExt("test.txt"));
  println("HasExtension         = {}", int32(Paths.HasExtension("test.txt")));

  println("IsLeapYear(2024)     = {}", int32(DateTime.IsLeapYear(2024)));
  println("DaysInMonth(2024, 2) = {}", DateTime.DaysInMonth(2024, 2));

  println("FileExists           = {}", int32(Files.FileExists("nonexistent.xyz")));

  LRect := Geometry.Rect(0, 0, 100, 50);
  println("RectWidth            = {}", Geometry.RectWidth(LRect));
  println("IsRectEmpty          = {}", int32(Geometry.IsRectEmpty(LRect)));

  Assertions.AssertTrue(true, "test");
  Assertions.AssertEqual(int64(1), int64(1), "test");
end.
```

Output:

```
Sqrt(4.0)            = 2
Abs(-5)              = 5
Min(3, 7)            = 3
UpperCase("hello")   = HELLO
Trim("  x  ")        = x
Length("test")       = 4
Console test (green)
IntToStr(42)         = 42
StrToInt("123")      = 123
BoolToStr(true)      = True
ExtractFileExt       = .txt
HasExtension         = 1
IsLeapYear(2024)     = 1
DaysInMonth(2024, 2) = 29
FileExists           = 0
RectWidth            = 100
IsRectEmpty          = 0
```

| Module | Provides |
|---|---|
| `Maths` | `Sqrt`, `Abs`, `Min`, and friends |
| `StrUtils` | `UpperCase`, `Trim`, `Length`, and friends |
| `Console` | Colour constants such as `clGreen`, `clReset` |
| `Convert` | `IntToStr`, `StrToInt`, `BoolToStr` |
| `Paths` | `ExtractFileExt`, `HasExtension` |
| `Files` | `FileExists` |
| `DateTime` | `IsLeapYear`, `DaysInMonth` |
| `Geometry` | `TRect`, `Rect`, `RectWidth`, `IsRectEmpty` |
| `Assertions` | `AssertTrue`, `AssertEqual` |

A module may export a **type** as well as routines: `Geometry.TRect` above is used as a
variable's type.

> [!NOTE]
> 📦 The standard library lives at `res/libs/std` and the compiler knows that path. This
> is the only library path the language definition knows about. Everything else, including
> every vendor library, describes its own paths. See [Vendor Libraries](#-vendor-libraries).

> Traced to `test_exe_std.myra`.

### 🔗 Shared Libraries

Build a `dll` module, then link against it from another module, or from any language with
an FFI.

**`test_dll_exports.myra`** -- the DLL:

```myra
module dll test_dll_exports;

// Private helper. Not exported.
routine helper(const x: int32): int32;
begin
  return x * 2;
end;

exported routine clink add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

exported routine clink add(const a: float32; const b: float32): float32;
begin
  return a + b;
end;

exported routine clink quadruple(const x: int32): int32;
begin
  return helper(helper(x));
end;

// A variable can be exported too.
exported var version: int32 = 1;

end.
```

**`test_exe_usedll.myra`** -- the consumer:

```myra
module exe test_exe_usedll;

@ifdef TARGET_LINUX64
@copydll "output/zig-out/lib/libtest_dll_exports.so";
@librarypath "output/zig-out/lib";
@elseif TARGET_WIN64
@librarypath "output/zig-out/bin";
@endif

@linklibrary "test_dll_exports";

// Declare what you are importing. The string is the LIBRARY NAME.
routine clink add(const a: int32; const b: int32): int32; external "test_dll_exports";
routine clink add(const a: float32; const b: float32): float32; external "test_dll_exports";
routine clink quadruple(const x: int32): int32; external "test_dll_exports";

// An exported variable is imported the same way.
var version: int32; external "test_dll_exports";

var
  LIntResult: int32;
  LFloatResult: float32;

begin
  LIntResult := add(3, 5);
  println("{}", LIntResult);

  LFloatResult := add(3.0, 4.5);
  println("{:.1f}", LFloatResult);

  LIntResult := quadruple(4);
  println("{}", LIntResult);

  println("{}", version);
end.
```

Output:

```
8
7.5
16
1
```

Three directives do the work:

| Directive | Purpose |
|---|---|
| `@linklibrary "name"` | Link against library `name` |
| `@librarypath "dir"` | Add `dir` to the library search path |
| `@copydll "path"` | Copy a shared object next to the built executable |

> [!IMPORTANT]
> 📛 The string after `external` is the **library name**, not a symbol name and not a
> filename. There is no `name "..."` clause: the routine's own name is the symbol it binds
> to. To bind a differently-named symbol, name your routine after it.

The `@ifdef TARGET_*` block is doing real work here: Windows puts import libraries beside
the `.exe` in `zig-out/bin`, Linux puts the shared object in `zig-out/lib` and needs it
copied next to the binary. See [Conditional Compilation](#-conditional-compilation).

#### A Static Library Instead

`module lib` builds a static library. The consumer just `import`s it and needs no
`@linklibrary` at all, because the code is linked in directly. That is the
[Modules and Imports](#-modules-and-imports) recipe above.

> Traced to `test_dll_exports.myra`, `test_exe_usedll.myra`.

### 🧰 Vendor Libraries

A third-party library is a **self-describing module**. It declares every path it needs,
gated per target. The compiler knows nothing about it.

Here is the entire raylib binding module, `res/libs/vendor/raylib/raylib_import.myra`:

```myra
module lib raylib_import;

// Self-describing vendor module: it owns every path it needs. The langdef
// knows nothing about raylib.
@includepath "res/libs/vendor/raylib/include";

@ifdef STATIC

  @ifdef TARGET_WIN64
    @librarypath "res/libs/vendor/raylib/win64/lib";
    @linklibrary "opengl32";
    @linklibrary "gdi32";
    @linklibrary "winmm";
  @elseif TARGET_LINUX64
    @librarypath "res/libs/vendor/linux64";
    @librarypath "res/libs/vendor/raylib/linux64/lib";
    @linklibrary "GL";
    @linklibrary "X11";
    @linklibrary "m";
    @linklibrary "pthread";
    @linklibrary "dl";
    @linklibrary "rt";
  @endif

@else

  @ifdef TARGET_WIN64
    @librarypath "res/libs/vendor/raylib/win64/bin";
    @copydll "res/libs/vendor/raylib/win64/bin/raylib.dll";
  @elseif TARGET_LINUX64
    @librarypath "res/libs/vendor/linux64";
    @librarypath "res/libs/vendor/raylib/linux64/bin";
    @copydll "res/libs/vendor/raylib/linux64/bin/libraylib.so.550";
  @endif

@endif

@linklibrary "raylib";

#include "raylib.h"

end.
```

That is the whole binding. `#include "raylib.h"` brings in every raylib declaration
through C++ passthrough. No wrapper is written by hand.

The consumer names the folder and imports it. That is all:

```myra
module exe test_exe_raylib;

@modulepath "res/libs/vendor/raylib";

import
  raylib_import;

const
  CScreenWidth  = 800;
  CScreenHeight = 450;

begin
  InitWindow(CScreenWidth, CScreenHeight, "Raylib Window");
  SetTargetFPS(60);

  while not WindowShouldClose() do
    BeginDrawing();
      ClearBackground(RAYWHITE);
      DrawText("Congrats! You created your first window!", 190, 200, 20, LIGHTGRAY);
    EndDrawing();
  end;

  CloseWindow();
end.
```

Note that raylib's own functions (`InitWindow`, `DrawText`) and constants (`RAYWHITE`,
`LIGHTGRAY`) are called **unqualified**. They came from a C header via `#include`, so they
are C++ names, not Myra module members.

| Directive | Who writes it | Purpose |
|---|---|---|
| `@modulepath "dir"` | The **consumer** | Where to find the vendor module |
| `@includepath "dir"` | The **vendor module** | Where its C headers live |
| `@librarypath "dir"` | The **vendor module** | Where its link libraries live |
| `@linklibrary "name"` | The **vendor module** | What to link against |
| `@copydll "path"` | The **vendor module** | What to copy beside the output |

> [!TIP]
> 🧩 **This is the whole extensibility story.** Dropping a new C library into the tree
> needs no compiler change, no language-definition change, and no rebuild of Myra. Write a
> `module lib` that declares its own paths and `#include`s its header. Ship it. The
> consumer adds one `@modulepath` and one `import`.

The `@ifdef STATIC` gate above lets one binding serve both a static and a dynamic build.
Define `STATIC` and you get the static link lines; leave it undefined and you get the DLL
plus a `@copydll`.

The SDL3 binding at `res/libs/vendor/sdl3` follows exactly the same shape, and the SDL3
demo consumes it with `@modulepath "res/libs/vendor/sdl3"; import sdl3_import;`. It uses
C types (`SDL_Window`, `SDL_FRect`, `SDL_Event`) directly as Myra variable types.

> Traced to `raylib_import.myra`, `test_exe_raylib.myra`, `test_exe_sdl3.myra`.

### 🌉 C++ Interop

There is no escape-hatch syntax and no FFI declaration to write. **Any token Myra does not
recognize is emitted verbatim to the generated C++.** That is the second pillar.

```myra
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

module exe test_exe_mixedmode;

var
  LX: int32;
  LD: float64;
  LS: std::string;              // a C++ type as a Myra variable
  LPos: size_t;
  LPCppVec: std::vector<int32_t>*;

begin
  // Call C++ standard library functions directly.
  LX := std::abs(-42);
  println("std::abs(-42) = {}", LX);

  LX := std::max(10, 20);
  println("std::max(10, 20) = {}", LX);

  LX := int32(strlen("hello"));
  println("strlen(\"hello\") = {}", LX);

  // A C++ object as a Myra variable, with C++ methods called on it.
  LS := "hello world";
  println("s.length() = {}", LS.length());
  println("Substring: {}", LS.substr(1, 3));

  // C++ expressions inside Myra control flow.
  if not (LS.empty()) then
    println("String is not empty");
  end;

  LPos := LS.find("world");
  if LPos <> std::string::npos then
    println("Found 'world' at position {}", LPos);
  end;

  // Mixed arithmetic: Myra operators over C++ results.
  LD := std::sqrt(16.0) * 2.0;
  println("sqrt(16) * 2 = {}", int32(LD));

  // C++ new / delete pass straight through.
  LPCppVec := new std::vector<int32_t>();
  LPCppVec->push_back(1);
  LPCppVec->push_back(2);
  println("vector size = {}", LPCppVec->size());
  delete LPCppVec;

  // C++ casts pass through.
  LD := 42.7;
  LX := static_cast<int32_t>(LD);
  println("static_cast: {}", LX);
end.
```

Output (excerpt):

```
std::abs(-42) = 42
std::max(10, 20) = 20
strlen("hello") = 5
s.length() = 11
Substring: ell
String is not empty
Found 'world' at position 6
sqrt(16) * 2 = 8
vector size = 2
static_cast: 42
```

What this buys you, all without a single declaration:

| You write | What happens |
|---|---|
| `#include <string>` | Hoisted into the generated header |
| `LS: std::string;` | A C++ type as a Myra variable |
| `LS.length()` | A C++ method call inside a Myra expression |
| `std::abs(-42)` | A C++ function call, result assigned to a Myra `int32` |
| `new` / `delete` | C++ memory management, alongside Myra's `create` / `destroy` |
| `static_cast<T>(x)` | A C++ cast |
| `LPCppVec->size()` | C++ arrow notation on a C++ pointer |

#### Where the Keywords Meet

Myra keywords keep working right up against C++ tokens. `end` is a Myra keyword but
`std::ios::end` is a C++ name, and both resolve correctly. `in` is Myra's set-membership
operator but `std::ios::in` is C++. `then`, `do`, `to`, `downto` and `of` all follow C++
expressions cleanly:

```myra
  // 'then' directly after a C++ method call
  if LS.length() > 0 then
    println("passed");
  end;

  // 'do' after a C++ expression
  while std::abs(LX) < 1 do
    LX := 1;
  end;

  // 'downto' with a C++ bound
  for LI := std::abs(-3) downto 0 do
    print("{} ", LI);
  end;
```

#### Where Preprocessor Lines Land

A `#include` or other preprocessor line **at module level** is hoisted into the generated
header. Inside a body, it stays in the generated source. Both work.

> [!NOTE]
> 📌 In every green test, `#include` appears **after** the `module` line, except in
> `test_exe_mixedmode`, where the includes sit after the module line and its directives.
> Follow that ordering.

> Traced to `test_exe_mixedmode.myra`, `test_exe_records.myra`.

### 🔀 Conditional Compilation

Myra has **two** conditional systems, with **separate symbol tables**. They cannot see
each other.

| System | Resolved by | Reads |
|---|---|---|
| `@ifdef` | The Myra lexer, **before** the compiler runs | Myra's own define table |
| `#if defined(...)` | The C++ preprocessor, **after** the compiler runs | The toolchain's macros for the selected target |

#### `@ifdef` -- Myra's Own Table

```myra
module exe test_exe_conditional;

@define STATIC_BUILD
@define FEATURE_A

@ifdef FEATURE_A
const
  FeatureAEnabled = "yes";
@else
const
  FeatureAEnabled = "no";
@endif

@ifdef FEATURE_B
const
  FeatureBEnabled = "yes";
@else
const
  FeatureBEnabled = "no";
@endif

// Conditionals nest.
@define OUTER
@define INNER

@ifdef OUTER
  @ifdef INNER
const
    NestedResult = "inner_true";
  @else
const
    NestedResult = "inner_false";
  @endif
@else
const
  NestedResult = "outer_false";
@endif

// @ifndef tests for absence.
@ifndef UNDEFINED_SYMBOL
const
  IfndefResult = "undefined_symbol";
@else
const
  IfndefResult = "was_defined";
@endif

// @undef removes a symbol.
@define TEMP_SYMBOL
@undef TEMP_SYMBOL

@ifdef TEMP_SYMBOL
const
  UndefResult = "still_defined";
@else
const
  UndefResult = "was_undefined";
@endif

begin
  println("FEATURE_A={}", FeatureAEnabled);
  println("FEATURE_B={}", FeatureBEnabled);
  println("NESTED={}", NestedResult);
  println("IFNDEF_TEST={}", IfndefResult);
  println("UNDEF_TEST={}", UndefResult);
end.
```

Output:

```
FEATURE_A=yes
FEATURE_B=no
NESTED=inner_true
IFNDEF_TEST=undefined_symbol
UNDEF_TEST=was_undefined
```

| Directive | Purpose |
|---|---|
| `@define SYM` | Define a Myra symbol |
| `@undef SYM` | Remove one |
| `@ifdef SYM` | If defined |
| `@ifndef SYM` | If not defined |
| `@elseif SYM` | Else if defined |
| `@else` | Otherwise |
| `@endif` | Close the block |

#### The Target Symbols

Exactly one `TARGET_*` symbol is defined, matching the selected target. `MYRA` is always
defined.

`TARGET_WIN64`, `TARGET_WINARM64`, `TARGET_LINUX64`, `TARGET_LINUXARM64`,
`TARGET_MACOS64`, `TARGET_WASM32`.

Because `@ifdef` is resolved before the compiler runs, it can gate a **directive**. This
is exactly how the DLL recipe above configures its linking per platform, and how every
vendor module configures itself:

```myra
@ifdef TARGET_LINUX64
@copydll "output/zig-out/lib/libtest_dll_exports.so";
@librarypath "output/zig-out/lib";
@elseif TARGET_WIN64
@librarypath "output/zig-out/bin";
@endif
```

> [!IMPORTANT]
> ⏱️ **A C++ `#if` cannot gate a `@librarypath`.** By the time the C++ preprocessor runs,
> the build is already configured and the link line is already decided. Build configuration
> is `@ifdef` territory, always.

#### `#if` -- The Toolchain's Macros

For **platform detection inside code**, use `#if`. The toolchain defines the real platform
macros for whichever target Zig was pointed at, so this is hard evidence of what the binary
actually is:

```myra
module exe test_exe_target;

@target "win64";

begin
// Myra-level define, from Myra's table.
@ifdef MYRA
  println("MYRA defined: yes");
@else
  println("MYRA defined: no");
@endif

// C++ passthrough. The toolchain defines these for the selected target.
#if defined(_WIN32)
  println("_WIN32 defined: yes");
#else
  println("_WIN32 defined: no");
#endif

#if defined(__x86_64__)
  println("__x86_64__ defined: yes");
#else
  println("__x86_64__ defined: no");
#endif

#if defined(__linux__)
  println("__linux__ defined: yes");
#else
  println("__linux__ defined: no");
#endif
end.
```

Output on `win64`:

```
MYRA defined: yes
_WIN32 defined: yes
__x86_64__ defined: yes
__linux__ defined: no
```

`#elif` chains work as they do in C:

```myra
  print("arch : ");
#if defined(__x86_64__)
  println("x86_64");
#elif defined(__aarch64__)
  println("aarch64");
#elif defined(__wasm32__)
  println("wasm32");
#else
  println("unknown");
#endif
```

> [!TIP]
> 🎯 **Rule of thumb.** Configuring the build (paths, libraries, what to link)? `@ifdef`.
> Detecting the platform inside your code? `#if defined(...)`. Myra deliberately does not
> maintain a hand-written platform define list: with dozens of architectures and operating
> systems, that would be a lie waiting to happen.

> Traced to `test_exe_conditional.myra`, `test_exe_target.myra`, `target_win64.myra`,
> `test_exe_usedll.myra`.

### ⚙️ Build Directives

Build settings are directives written after the module declaration.

```myra
module exe target_win64;

@target win64;
@optimize releasesmall;

var
  i: int32;
  sum: int32;

begin
  sum := 0;
  for i := 1 to 10 do
    sum := sum + i;
  end;
  println("sum 1..10 = {}", sum);
end.
```

`@target` takes any of the six aliases. Both a bare name (`@target win64;`) and a quoted
string (`@target "win64";`) are accepted.

| Alias | Triple | Auto-run |
|---|---|---|
| `win64` | x86_64-windows-gnu | Yes, native |
| `winarm64` | aarch64-windows-gnu | No, warns |
| `linux64` | x86_64-linux-gnu | Yes, via WSL |
| `linuxarm64` | aarch64-linux-gnu | No, warns |
| `macos64` | aarch64-macos-none | No, warns |
| `wasm32` | wasm32-wasi | Yes, in a browser |

A target that cannot auto-run **warns**. It never errors: the build still succeeds and the
binary is still produced.

| Directive | Values |
|---|---|
| `@target` | `win64`, `winarm64`, `linux64`, `linuxarm64`, `macos64`, `wasm32` |
| `@optimize` | `releasesafe`, `releasefast`, `releasesmall` |
| `@subsystem` | `console`, `gui` |

#### Windows Version Info and Icon

```myra
@addverinfo on;
@vimajor 0;
@viminor 1;
@vipatch 0;
@viproductname "Myra Demo";
@videscription "Myra Demo";
@vifilename "test_exe_mixedmode.exe";
@vicompanyname "tinyBigGAMES LLC";
@vicopyright "Copyright (c) 2026, tinyBigGAMES LLC";

@exeicon "res/assets/icons/myra.ico";
```

| Directive | Purpose |
|---|---|
| `@addverinfo on\|off` | Enable version information embedding |
| `@vimajor`, `@viminor`, `@vipatch` | Version numbers |
| `@viproductname "..."` | Product name |
| `@videscription "..."` | File description |
| `@vifilename "..."` | Original filename |
| `@vicompanyname "..."` | Company name |
| `@vicopyright "..."` | Copyright string |
| `@exeicon "path"` | Icon to embed in the executable |

> Traced to `target_win64.myra`, `test_exe_target.myra`, `test_exe_mixedmode.myra`,
> `test_exe_sdl3.myra`.

### 🧪 Unit Testing

Turn on test mode with `@unitTestMode on;`. Test blocks follow the module's terminating
`end.`

```myra
module exe test_exe_unittest;

@unitTestMode on;

routine add(const A: int32; const B: int32): int32;
begin
  return A + B;
end;

routine multiply(const A: int32; const B: int32): int32;
begin
  return A * B;
end;

routine isPositive(const A: int32): boolean;
begin
  return A > 0;
end;

begin
  println("Hello from test_exe_unittest!");
end.

test "Addition works correctly"
begin
  testAssertEqualInt(5, add(2, 3));
  testAssertEqualInt(0, add(-1, 1));
  testAssertEqualInt(0, add(0, 0));
end;

test "Multiplication works correctly"
begin
  testAssertEqualInt(12, multiply(3, 4));
  testAssertEqualInt(-6, multiply(-2, 3));
end;

test "Boolean assertions"
begin
  testAssertTrue(isPositive(5));
  testAssertFalse(isPositive(-5));
  testAssertEqualBool(true, isPositive(1));
end;

// A test block may declare its own locals.
test "Pointer assertions"
var
  p: pointer;
begin
  p := nil;
  testAssertNil(p);
end;

test "Deliberate failure"
begin
  testAssertEqualInt(1, 2);
end;
```

Output:

```
╔══════════════════════════════════════════════════════════════╗
║                     Unit Test Runner                         ║
╚══════════════════════════════════════════════════════════════╝

Running 5 test(s)...

✅ PASS: Addition works correctly
✅ PASS: Multiplication works correctly
✅ PASS: Boolean assertions
✅ PASS: Pointer assertions
❌ FAIL: Deliberate failure
  🔴 TestAssertEqualInt failed at test_exe_unittest.myra:86: expected 1, got 2
════════════════════════════════════════════════════════════════
Results: 4 passed, 1 failed, 5 total
════════════════════════════════════════════════════════════════
```

The module's own `begin ... end.` body still runs. The test runner takes over afterwards,
and the process exits with a **non-zero exit code** if any test failed.

A failing assertion reports the **file and line** it failed on, plus expected and actual.

The assertion set:

| Arity | Assertions |
|---|---|
| One argument | `testAssert`, `testAssertTrue`, `testAssertFalse`, `testAssertNil`, `testAssertNotNil`, `testFail` |
| Two arguments | `testAssertEqualInt`, `testAssertEqualUInt`, `testAssertEqualFloat`, `testAssertEqualStr`, `testAssertEqualBool`, `testAssertEqualPtr` |

A `test` block may carry its own `var` section, exactly like a routine.

> Traced to `test_exe_unittest.myra`.

### 💻 Command-Line Arguments

`paramcount()` returns the number of user arguments. `paramstr(i)` returns argument `i`.

```myra
module exe Args;

var
  i: int32;
  n: int32;

begin
  n := paramcount();
  println("paramcount = {}", n);

  // paramstr(0) is the full path to the executable.
  // User arguments run from 1 to paramcount().
  i := 1;
  while i <= n do
    println("paramstr({}) = {}", i, paramstr(i));
    i := i + 1;
  end;
end.
```

Run with no arguments:

```
paramcount = 0
```

> [!IMPORTANT]
> 0️⃣ **`paramstr(0)` is the executable path, and `paramcount()` does not include it.**
> User arguments are `1` through `paramcount()`. Starting a loop at `0` will print the
> exe path.

> Traced to `test_exe_intrinsics.myra`.

### 📏 Intrinsics

`size` and `len` are built in and need no import.

```myra
module exe test_exe_intrinsics;

var
  x: int32;
  y: float64;

begin
  // size(type) gives the size in bytes.
  println("size(int8)    = {}", size(int8));
  println("size(int16)   = {}", size(int16));
  println("size(int32)   = {}", size(int32));
  println("size(int64)   = {}", size(int64));
  println("size(uint8)   = {}", size(uint8));
  println("size(uint64)  = {}", size(uint64));
  println("size(float32) = {}", size(float32));
  println("size(float64) = {}", size(float64));
  println("size(boolean) = {}", size(boolean));
  println("size(char)    = {}", size(char));
  println("size(wchar)   = {}", size(wchar));

  // size(expr) works on a variable too.
  x := 42;
  y := 3.14;
  println("size(x) = {}", size(x));
  println("size(y) = {}", size(y));
end.
```

Output:

```
size(int8)    = 1
size(int16)   = 2
size(int32)   = 4
size(int64)   = 8
size(uint8)   = 1
size(uint64)  = 8
size(float32) = 4
size(float64) = 8
size(boolean) = 1
size(char)    = 1
size(wchar)   = 2
size(x) = 4
size(y) = 8
```

`size` also works on a user type: `size(PackedRec)`, `size(Value)`.

| Intrinsic | Applied to | Returns |
|---|---|---|
| `size(T)` | A type name | Its size in bytes |
| `size(expr)` | A variable | Its type's size in bytes |
| `len(arr)` | A static or dynamic array | Element count |
| `len(s)` | A `string` | **Byte** count |
| `len(w)` | A `wstring` | UTF-16 code-unit count |
| `paramcount()` | -- | Number of user arguments |
| `paramstr(i)` | An index | Argument `i` |
| `utf8(w)` | A `wstring` | The same text as a `string` |

> Traced to `test_exe_intrinsics.myra`, `test_exe_types.myra`, `test_exe_strings.myra`,
> `test_exe_records.myra`.

<a id="contributing"></a>

## 🤝 Contributing

Myra is developed by tinyBigGAMES. Whether you are fixing a bug, improving documentation, sharpening examples, or proposing a feature, contributions are welcome.

| Contribution | Best Way to Help |
|--------------|------------------|
| 🐞 Bug report | Open an issue with a minimal reproduction and the exact command used |
| 💡 Feature idea | Describe the real use case first, then the proposed syntax or behavior |
| 🧾 Documentation fix | Point to the section and explain what was unclear or missing |
| 🧪 Test case | Include the smallest `.myra` file that proves the behavior |
| 🔧 Pull request | Keep the change focused and explain the before/after behavior |

> [!TIP]
> 🚀 Small, focused contributions are the easiest to review and the fastest to land.

> [!NOTE]
> 🧬 Because the language is defined by the [`.mld` files](#langdef-system), a grammar or emitter change is a text edit, not a compiler fork. That makes language proposals unusually easy to prototype and share.

## 💖 Support the Project

If Myra saves you time, helps you learn, or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community, or share a screenshot
- 💬 **Join the community**: show what you are building and help shape what comes next
- 🧪 **Try examples**: real usage finds issues that synthetic tests miss
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds development, examples, and documentation

## 📜 License

Myra is licensed under the **Apache License, Version 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Myra?tab=License-1-ov-file#) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Myra freely in both open source and commercial projects. You are not required to release your own source code. Attribution is required: keep the copyright notice and license file in place.

## 🔗 Links

- 🌐 [myralang.org](https://myralang.org)
- 🧑‍💻 [GitHub](https://github.com/tinyBigGAMES/Myra)
- 💬 [Discord](https://discord.gg/Wb6z8Wam7p)
- 🦋 [Bluesky](https://bsky.app/profile/tinybiggames.com)
- 🎮 [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**🚀 Myra&trade;** - Pascal. Refined.

Copyright &copy; 2026-present tinyBigGAMES&trade; LLC<br/>All Rights Reserved.

</div>