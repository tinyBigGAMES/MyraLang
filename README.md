<div align="center">

![Myra](media/myra.png)

[![Discord](https://img.shields.io/discord/1457450179254026250?style=for-the-badge&logo=discord&label=Discord)](https://discord.gg/Wb6z8Wam7p) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com)

</div>

## What is Myra?

**A minimal systems programming language where C++ is always one line away.**

Under the hood, Myra compiles to C++ 23 and uses [Zig](https://ziglang.org/) as the build system. That means you get everything C++ 23 gives you: the full standard library, every platform target Zig/Clang supports, every optimization the compiler can produce -- without writing a line of C++. You write clean, structured Pascal-style code. Myra handles the rest.

```myra
module exe hello;

begin
  writeln("Hello from Myra!");
end.
```

When you need C++, you just write it. `#include` a header, declare a C++ variable, call a C++ function, use `new`/`delete`, `static_cast`, `std::vector`, whatever you need. Myra and C++ coexist in the same source file with no wrappers, no bindings, no escape hatches. If the compiler does not recognise a token as Myra, it treats it as C++ and passes it through verbatim. The standard library itself is written this way.

Myra takes its syntax philosophy from Oberon: start with Pascal and remove everything that is not essential. What remains is clean, readable, and unambiguous. `begin..end` blocks, `:=` assignment, strong static typing, and a module system that replaces header files entirely. No cruft, no legacy baggage. Just the parts of Pascal that were always right.

**Myra is hackable.** The entire language definition ships as human-readable `.mld` files alongside the compiler. These are not opaque binaries -- they are structured text files that define every token, every grammar rule, every semantic check, and every line of code generation. You can read them to understand exactly how a language feature works, modify them to change behavior, or extend them to add new features. The compiler is not a black box. It is a transparent pipeline you can inspect, patch, and evolve.

The entire toolchain ships in the box. Zig, Clang, the C++ runtime, the standard library, the debugger adapter -- everything needed to go from source to native binary is included in the release. There is nothing to install, configure, or set up. You unzip, add `bin\` to your PATH, and write code.


## 🎯 Who is Myra For?

Myra is for developers who want native performance and low-level control without fighting the language:

- **Systems software**: Full pointer arithmetic, packed structs, overlay types, and direct memory management. Myra does not hide the machine from you.
- **Game engines and tools**: Call C libraries (SDL3, raylib, etc.) directly via FFI with no boilerplate. Target Windows and Linux from the same codebase. Shared library interop is a first-class feature.
- **DLL / shared library development**: Export clean C-linkage APIs from a Myra `dll` or `lib` module and consume them from any language that speaks C ABI.
- **Cross-platform CLI tools**: Compile once, run on Windows and Linux64. WSL2 integration means you can build and test Linux binaries without leaving Windows.
- **Embedded tooling**: Small, predictable binaries with configurable optimization levels (`releasesmall`, `releasefast`, `releasesafe`). Zig produces tight output.
- **Learning systems programming**: Pascal-family syntax is famously readable and explicit. Myra adds modern ideas while keeping the code approachable.
- **Language hackers**: The `.mld` definition files are included. Read how the parser works. Change how code is generated. Add a keyword. Fix a bug in the emitter. The language is yours to shape.


## ✨ Key Features

Myra is a complete language for systems-level development. These are the capabilities that ship today:

- **Minimal by design**: Oberon-inspired -- only the constructs that earn their place. No feature bloat, no second way to do the same thing. The entire language fits in your head.
- **Case-sensitive syntax**: Clean, readable Pascal-family style. `begin..end` blocks, `:=` assignment, strong typing throughout. Familiar to Pascal and Delphi developers; readable to everyone.
- **Native binaries**: Compiles to real x86-64 executables, DLLs, and static libraries. No VM, no bytecode, no interpreter. The output runs bare metal.
- **Cross-platform**: Target Windows (Win64) or Linux (Linux64) from the same source. Cross-compile from Windows via WSL2 with no additional configuration.
- **FFI / C interop**: Call any C library with `external` declarations and `"C"` linkage. Full varargs support for `printf`-style APIs. Perfect ABI compatibility -- structs, overlays, anonymous overlays, and bit fields map directly to their C equivalents.
- **Seamless C++ interop**: Every Myra source file can freely use C++ `#include` directives, C++ types (`std::string`, `std::vector`), C++ function calls, C++ casts, and C++ `new`/`delete` alongside Myra code. No bindings, no importer, no boilerplate. If the compiler does not recognise it as Myra, it is C++.
- **Module system**: Three module kinds: `exe` (executable), `dll` (shared library), `lib` (static library). A clean `import` mechanism wires them together without header files.
- **Rich type system**: Records with inheritance and field alignment, objects with methods and virtual dispatch, overlays, choices, sets, fixed and dynamic arrays, typed and untyped pointers, routine types, and bit fields.
- **Structured exception handling**: `guard/except/finally` with full hardware exception support for divide-by-zero, access violations, and other CPU-level faults.
- **Routine overloading**: Multiple routines with the same name resolved by parameter signature. The C++ backend handles name mangling transparently.
- **Sets**: Pascal-style bit-set types backed by a 64-bit integer. Full set arithmetic: membership (`in`), union (`+`), intersection (`*`), and difference (`-`).
- **Managed strings**: Reference-counted UTF-8 `string` and UTF-16 `wstring` types with automatic lifecycle management. Emoji, CJK, and accented characters work without any special handling.
- **Full memory control**: `create`/`destroy` for object instances, `getMem`/`freeMem` for raw allocation, `resizeMem` for reallocation. You decide what lives where.
- **Variadic routines**: Define your own variadic routines with `...`. Access argument count and values via `varargs.count` and `varargs.next(T)`.
- **Version info and icons**: Embed metadata and application icons into Windows executables via directives. No post-build steps or resource compilers required.
- **Conditional compilation**: `@ifdef`/`@ifndef`/`@elseif`/`@else`/`@endif` with predefined platform symbols. Write platform-specific code in the same file cleanly.
- **Integrated debugger**: DAP-compatible debugger integration via LLDB with the `-d` flag. The `@breakpoint` directive marks source locations automatically.
- **Built-in test blocks**: `test "name" begin ... end;` blocks for inline unit tests with typed assertions and colour-coded pass/fail output.
- **Hackable compiler**: The `.mld` language definition files ship with the compiler. Every token, grammar rule, semantic check, and code generation handler is readable and modifiable. Fix a compiler bug without waiting for a release. Add a language feature without forking the engine.


## 🚀 Getting Started

Every Myra program is a **module**. The module kind (`exe`, `dll`, or `lib`) is declared at the top of the file and determines what artifact gets built. An executable module has a `begin..end.` body that serves as the program entry point.

```myra
module exe hello;

@target win64

begin
  @ifdef TARGET_WIN64
  writeln("Hello from Myra, running on WIN64");
  @elseif TARGET_LINUX64
  writeln("Hello from Myra, running on LINUX64");
  @else
  writeln("Hello from Myra, running on UNKNOWN");
  @endif

  writeln("Name: {}, Age: {}", "Jarrod", 42);
  writeln("Pi is approximately {:.4f}", 3.14159);
  writeln("Hex: 0x{:X}, Octal: {:o}", 255, 255);
end.
```

Compile and run:

```bash
myra -s hello.myra -r
```

The `writeln` statement accepts a format string with `{}` placeholders matched left-to-right. Standard format specifiers are supported: `{:.4f}` for fixed-point precision, `{:X}` for uppercase hex, `{:o}` for octal.


## 📖 Documentation

The full language reference and compiler internals documentation live in the `docs/` folder:

| Document | Description |
|----------|-------------|
| **[Myra Language Reference](docs/MYRA.md)** | Complete language tour with examples: routines, records, objects, choices, arrays, sets, strings, control flow, exceptions, memory management, pointers, overlays, variadics, modules, FFI, C++ interop, directives, intrinsics, test blocks, and the full BNF grammar. |
| **[MLD Reference Manual](docs/MLD.md)** | The `.mld` meta-language that defines Myra. Covers tokens, types, grammar rules, semantics, emitters, the imperative language, built-in functions, and the formal EBNF grammar. Read this to understand how the compiler works and how to hack it. |


## 🔨 Getting Myra

### Download the Latest Release

**The release is the only way to use Myra.** The release package contains everything required to compile and run Myra programs: the compiler, the Zig build backend, the C++ runtime, the standard library, and the debugger adapter. None of these components are built from source; they ship pre-compiled and ready to use.

**[Download the latest release](https://github.com/tinyBigGAMES/MyraLang/releases/latest)**

Unzip the release to a directory of your choice. Add `bin\` to your `PATH` so that `myra` is available from any terminal. That is the complete installation.

```
MyraLang/
  bin/
    myra.exe              <- compiler
    res/
      language/           <- .mld language definition files (hackable!)
      runtime/            <- Myra C++ runtime
      libs/std/           <- standard library modules
      libs/vendor/        <- vendor library bindings (raylib, SDL3, etc.)
      tests/              <- test suite (.myra files)
      zig/                <- bundled Zig/Clang toolchain
```

### CLI Reference

```bash
myra -s <source.myra> [options]
```

| Flag | Description |
|------|-------------|
| `-s <file>` | Source file to compile |
| `-o <dir>` | Output directory (default: current directory) |
| `-r` | Compile and run the resulting executable |
| `-d` | Compile and launch the debugger |
| `-h` | Show help |

```bash
myra -s hello.myra              # compile
myra -s hello.myra -o build     # compile to specific output directory
myra -s hello.myra -r           # compile and run
myra -s hello.myra -d           # compile and launch debugger
```

### System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Linux target** | WSL2 + Ubuntu (`wsl --install -d Ubuntu`) |

### Target Platforms

| Target | Status |
|--------|--------|
| Windows x64 (`win64`) | Supported |
| Linux x64 (`linux64`) | Supported (native; via WSL on Windows) |


## 🔧 Building the Compiler from Source

This section is for contributors who want to modify the Myra compiler itself. If you just want to write Myra programs, use the release download above.

### Prerequisites

| | Minimum | Tested |
|---|---------|--------|
| **Host OS** | Windows 10 x64 | Windows 11 x64 |
| **Compiler** | Delphi 11 (Alexandria) | Delphi 12 (Athens) |

### Get the Source

```bash
git clone https://github.com/tinyBigGAMES/MyraLang.git
```

### Compile

1. Open `src\Myra - Pascal. Refined..groupproj` in Delphi
2. Build all projects in the group
3. The Testbed project compiles and executes every test in `bin\res\tests\` and reports colour-coded results


## 🤝 Contributing

Myra is an open project and contributions are welcome at every level:

- **Report bugs**: Open an issue on GitHub with a minimal reproduction case.
- **Suggest features**: Describe the use case first, then the syntax you have in mind.
- **Submit pull requests**: Bug fixes, documentation improvements, new test cases, and well-scoped features.
- **Review and discuss**: Reviewing open pull requests and issues helps move the project forward.

Join our [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, or share what you are building with Myra.


## 💙 Support the Project

If Myra saves you time, sparks an idea, or becomes part of something you ship:

- **Star the repo** -- helps others find the project
- **Spread the word** -- write a post, mention it on social media
- **Join us on [Discord](https://discord.gg/Wb6z8Wam7p)** -- share what you are building
- **Become a sponsor** via [GitHub Sponsors](https://github.com/sponsors/tinyBigGAMES) -- directly funds development


## 📄 License

Myra is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/MyraLang?tab=readme-ov-file#Apache-2.0-1-ov-file) for details.


## 🔗 Links

- [Website](https://myralang.org)
- [Discord](https://discord.gg/Wb6z8Wam7p)
- [Bluesky](https://bsky.app/profile/tinybiggames.com)
- [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Myra**&#8482; Programming Language.

Copyright &copy; 2025-present tinyBigGAMES&#8482; LLC
All Rights Reserved.

</div>
