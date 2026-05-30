<div align="center">

![Myra](../media/myra.png)

</div>

## What is Myra?

**A minimal systems programming language where C++ is always one line away.**

Myra takes its syntax philosophy from Oberon: start with Pascal, remove everything that is not essential. What remains is clean, readable, and unambiguous. `begin..end` blocks, `:=` assignment, strong static typing, and a module system that replaces header files entirely. No cruft, no legacy baggage. Just the parts of Pascal that were always right.

Under the hood, Myra compiles to C++23 and uses [Zig](https://ziglang.org/) as the build system. That means you get everything C++23 gives you -- the full standard library, every platform target Zig/Clang supports, every optimization the compiler can produce -- without writing a line of C++. You write clean, structured Pascal-style code. Myra handles the rest.

```myra
module exe hello;

begin
  writeln("Hello from Myra!");
end.
```

When you need C++, you just write it. `#include` a header, declare a C++ variable, call a C++ function, use `new`/`delete`, `static_cast`, `std::vector`, whatever you need. Myra and C++ coexist in the same source file with no wrappers, no bindings, no escape hatches. If the compiler does not recognise a token as Myra, it treats it as C++ and passes it through verbatim. The standard library itself is written this way.

**Myra is hackable.** The entire language definition ships as human-readable `.mld` files alongside the compiler. These are not opaque binaries or compiled grammars -- they are structured text files that define every token, every grammar rule, every semantic check, and every line of code generation. You can read them to understand exactly how a language feature works, modify them to change behavior, or extend them to add new features. The compiler is not a black box. It is a transparent pipeline you can inspect, patch, and evolve.

The entire toolchain ships in the box. Zig, Clang, the C++ runtime, the standard library, the debugger adapter -- everything needed to go from source to native binary is included in the release. There is nothing to install, configure, or set up. You unzip, add `bin\` to your PATH, and write code.


## Who is Myra For?

Myra is for developers who want native performance and low-level control without fighting the language:

- **Systems software**: Full pointer arithmetic, packed structs, overlay types, and direct memory management. Myra does not hide the machine from you.
- **Game engines and tools**: Call C libraries (SDL3, raylib, etc.) directly via FFI with no boilerplate. Target Windows and Linux from the same codebase. Shared library interop is a first-class feature.
- **DLL / shared library development**: Export clean C-linkage APIs from a Myra `dll` or `lib` module and consume them from any language that speaks C ABI.
- **Cross-platform CLI tools**: Compile once, run on Windows and Linux64. WSL2 integration means you can build and test Linux binaries without leaving Windows.
- **Embedded tooling**: Small, predictable binaries with configurable optimization levels (`releasesmall`, `releasefast`, `releasesafe`). Zig produces tight output.
- **Learning systems programming**: Pascal-family syntax is famously readable and explicit. Myra adds modern ideas while keeping the code approachable.
- **Language hackers**: The `.mld` definition files are included. Read how the parser works. Change how code is generated. Add a keyword. Fix a bug in the emitter. The language is yours to shape.


## Key Features

- **Minimal by design**: Oberon-inspired -- only the constructs that earn their place. No feature bloat, no second way to do the same thing. The entire language fits in your head.
- **Case-sensitive syntax**: Clean, readable Pascal-family style. `begin..end` blocks, `:=` assignment, strong typing throughout. Familiar to Pascal and Delphi developers; readable to everyone.
- **Native binaries**: Compiles to real x86-64 executables, DLLs, and static libraries. No VM, no bytecode, no interpreter.
- **Cross-platform**: Target Windows (Win64) or Linux (Linux64) from the same source. Cross-compile from Windows via WSL2.
- **FFI / C interop**: Call any C library with `external` declarations and `"C"` linkage. Full varargs support. Structs, unions, anonymous overlays, and bit fields map directly to C equivalents.
- **Seamless C++ passthrough**: Every Myra source file can freely use C++ `#include` directives, C++ types, C++ function calls, C++ casts, and C++ `new`/`delete` alongside Myra code. No bindings, no importer, no boilerplate. If the compiler does not recognise it as Myra, it is C++.
- **Module system**: Three module kinds (`exe`, `dll`, `lib`) with a clean `import` mechanism. No header files.
- **Rich type system**: Records with inheritance and field alignment, objects with methods and virtual dispatch, overlays, choices, sets, fixed and dynamic arrays, typed and untyped pointers, routine types, and bit fields.
- **Structured exception handling**: `guard/except/finally` with full hardware exception support for divide-by-zero, access violations, and other CPU-level faults.
- **Routine overloading**: Multiple routines with the same name resolved by parameter signature.
- **Sets**: Pascal-style bit-set types backed by a 64-bit integer. Membership (`in`), union (`+`), intersection (`*`), difference (`-`).
- **Managed strings**: Reference-counted UTF-8 `string` and UTF-16 `wstring` with automatic lifecycle management.
- **Full memory control**: `create`/`destroy` for objects, `getMem`/`freeMem`/`resizeMem` for raw allocation.
- **Variadic routines**: Define your own variadic routines with `...`. Access arguments via `varargs.count` and `varargs.next(T)`.
- **Version info and icons**: Embed metadata and application icons into Windows executables via directives.
- **Conditional compilation**: `@ifdef`/`@ifndef`/`@elseif`/`@else`/`@endif` with predefined platform symbols.
- **Integrated debugger**: DAP-compatible debugger integration via LLDB. The `@breakpoint` directive marks source locations automatically.
- **Built-in test blocks**: `test "name" begin ... end;` blocks for inline unit tests with colour-coded pass/fail output.
- **Hackable compiler**: The `.mld` language definition files ship with the compiler. Every token, grammar rule, semantic check, and code generation handler is readable and modifiable. Fix a compiler bug without waiting for a release. Add a language feature without forking the engine.


## Getting Started

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

The `writeln` statement accepts a format string with `{}` placeholders matched left-to-right to the arguments. Standard format specifiers are supported: `{:.4f}` for fixed-point precision, `{:X}` for uppercase hex, `{:o}` for octal. The `write` statement works identically but does not append a newline.

The `@target` directive locks a source file to a specific platform. `TARGET_WIN64` and `TARGET_LINUX64` symbols are injected automatically based on the active target.


## Language Tour

### Routines

Routines are declared with the `routine` keyword and can return a value using `return`. Parameters are passed by value by default. Use `var` to pass by reference. Routines can be overloaded by parameter signature.

Local `type`, `const`, and `var` sections can appear inside a routine body before the `begin` block.

```myra
module exe routines;

routine add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

// Routine overloading - same name, different types
routine max(const a: int32; const b: int32): int32;
begin
  if a > b then return a; end;
  return b;
end;

routine max(const a: float64; const b: float64): float64;
begin
  if a > b then return a; end;
  return b;
end;

// Recursion
routine fib(const n: int32): int32;
begin
  if n <= 1 then return n; end;
  return fib(n - 1) + fib(n - 2);
end;

// var parameter - modified in place
routine inc(var x: int32);
begin
  x := x + 1;
end;

var
  x: int32;

begin
  writeln("add(3, 4) = {}", add(3, 4));
  writeln("max int = {}", max(3, 7));
  writeln("max float = {}", max(3.5, 2.8));
  writeln("fib(10) = {}", fib(10));

  x := 10;
  inc(x);
  writeln("after inc: x = {}", x);
end.
```

### Records

Records are value types. They live on the stack and are copied on assignment. You can pack a record to remove padding, specify explicit alignment, define bit fields with `: width`, and derive one record from another to inherit its fields.

```myra
module exe records;

type
  Point = record
    x: int32;
    y: int32;
  end;

  PackedRec = record packed
    a: int8;
    b: int8;
    c: int8;
  end;

  Align16Rec = record align(16)
    a: int8;
    b: int8;
  end;

  Point3D = record(Point)
    z: int32;
  end;

  Flags = record
    active: int32 : 1;
    mode:   int32 : 3;
    level:  int32 : 4;
  end;

var
  p: Point;
  p3: Point3D;
  f: Flags;

begin
  p := Point{ x: 10, y: 20 };
  writeln("Point: {}, {}", p.x, p.y);

  p3.x := 100;
  p3.y := 200;
  p3.z := 300;
  writeln("Point3D: {}, {}, {}", p3.x, p3.y, p3.z);

  f.active := 1;
  f.mode   := 7;
  f.level  := 1;
  writeln("Bits: {}, {}, {}", f.mode, f.level, f.active);
end.
```

### Objects

Objects are reference types: heap-allocated, accessed through pointers. They support fields, methods, single-level inheritance, virtual dispatch, and `parent` calls. Objects are allocated with `create` and released with `destroy`. No garbage collector -- you manage lifetime explicitly.

```myra
module exe classes;

type
  TAnimal = object
    Name_: string;
    Age: int32;

    method Init(AName: string; AAge: int32);
    begin
      Self.Name_ := AName;
      Self.Age   := AAge;
    end;

    method Speak();
    begin
      writeln("Animal {} says: ...", Self.Name_);
    end;

    method Describe();
    begin
      writeln("I am {}, age {}", Self.Name_, Self.Age);
    end;
  end;

  TDog = object(TAnimal)
    Breed: string;

    method Init(AName: string; AAge: int32; ABreed: string);
    begin
      Self.Name_ := AName;
      Self.Age   := AAge;
      Self.Breed := ABreed;
    end;

    method Speak();
    begin
      writeln("Dog {} says: Woof!", Self.Name_);
    end;

    method Describe();
    begin
      parent.Describe();
      writeln("I am a {} breed", Self.Breed);
    end;
  end;

var
  animal: pointer to TAnimal;
  dog: pointer to TDog;
  base: pointer to TAnimal;

begin
  create(animal);
  animal^.Init("Generic", 5);
  animal^.Speak();

  create(dog);
  dog^.Init("Buddy", 3, "Golden Retriever");
  dog^.Speak();
  dog^.Describe();

  // Virtual dispatch through base pointer
  base := pointer to TAnimal(dog);
  base^.Speak(); // calls TDog.Speak()

  destroy(animal);
  destroy(dog);
end.
```

### Choices and Constants

Constants are typed and can be formed from constant expressions. Choices define an ordered set of named values with optional explicit ordinal assignments.

```myra
module exe enums_consts;

const
  MAX_SIZE   = 100;
  PI         = 3.14159;
  APP_NAME   = "MyApp";
  EXPR_CONST = 10 + 5;

type
  Color    = choices(Red, Green, Blue, Yellow);
  Priority = choices(Low = 0, Medium = 5, High = 10, Critical = 20);

var
  c: Color;
  p: Priority;

begin
  writeln("MAX_SIZE = {}", MAX_SIZE);
  writeln("PI = {}", PI);

  c := Green;
  writeln("c = Green: {}", c = Green);
  writeln("Green > Red: {}", Green > Red);

  p := Medium;
  writeln("Medium = {}", int32(p));
  writeln("Medium < Critical: {}", p < Critical);
end.
```

### Arrays

Fixed-size arrays have compile-time bounds and live on the stack. Dynamic arrays are heap-allocated and resized with `setLength`. Both are zero-indexed by default, but fixed arrays can declare any integer range.

```myra
module exe arrays;

type
  IntArr5 = array[0..4] of int32;

var
  nums: IntArr5;
  dyn: array of int32;
  i: int32;

begin
  nums[0] := 10; nums[1] := 20; nums[2] := 30;
  nums[3] := 40; nums[4] := 50;
  writeln("Fixed len: {}", len(nums));

  setLength(dyn, 3);
  dyn[0] := 10; dyn[1] := 20; dyn[2] := 30;
  writeln("Dyn len: {}", len(dyn));

  setLength(dyn, 5);
  writeln("After grow: {} {} {} {} {}", dyn[0], dyn[1], dyn[2], dyn[3], dyn[4]);

  setLength(dyn, 2);
  writeln("After shrink: {} {}", dyn[0], dyn[1]);
end.
```

### Sets

Pascal-style bit-set types backed by a 64-bit integer. Full set algebra: membership (`in`), union (`+`), intersection (`*`), difference (`-`). More readable than hand-rolled bitmask operations, compiles to the same bitwise instructions.

```myra
module exe sets;

var
  s1: set;
  s2: set;
  s3: set;

begin
  s1 := [1, 3, 5];
  s2 := [3, 5, 10];

  s3 := s1 + s2;   // union: [1, 3, 5, 10]
  s3 := s1 * s2;   // intersection: [3, 5]
  s3 := s1 - s2;   // difference: [1]

  if 1 in s1 then
    writeln("1 in s1: true");
  end;
  if not (2 in s1) then
    writeln("2 not in s1: true");
  end;
end.
```

### Strings

`string` stores UTF-8. `wstring` stores UTF-16 for Windows API interop. Both are reference-counted and freed automatically. `utf8()` converts `wstring` to `string`.

```myra
module exe strings;

var
  s:  string;
  ws: wstring;

begin
  s := "Hello, Myra!";
  writeln("Basic: {}", s);

  s := "Hallo Welt! Ni hao!";
  writeln("UTF-8: {}", s);

  ws := w"Wide Hello!";
  writeln("WString: {}", utf8(ws));
end.
```

### Control Flow

`for..to` and `for..downto` for counted iteration. `while..do` tests before the body. `repeat..until` tests after. `match` dispatches on ordinal values with single values, comma-separated lists, and inclusive ranges. Every block closes with `end`.

```myra
module exe control;

var
  i: int32;
  x: int32;

begin
  for i := 0 to 4 do
    write(" {}", i);
  end;
  writeln("");

  for i := 5 downto 1 do
    write(" {}", i);
  end;
  writeln("");

  i := 0;
  repeat
    i := i + 1;
  until i = 5;
  writeln("repeat ended at: {}", i);

  i := 10;
  while i > 0 do
    i := i - 3;
  end;
  writeln("while ended at: {}", i);

  x := 5;
  match x of
    1:       writeln("one");
    2, 3:    writeln("two or three");
    4..6:    writeln("four to six");
  else
    writeln("other");
  end;
end.
```

### Exceptions

`guard/except/finally` for structured error handling. Hardware exceptions (divide-by-zero, access violations) are caught by the same mechanism. `getExceptionCode()` and `getExceptionMessage()` retrieve details. `raiseException()` and `raiseExceptionCode()` raise software exceptions.

```myra
module exe exceptions;

routine getZero(): int32;
begin
  return 0;
end;

begin
  guard
    raiseException("Test error");
  except
    writeln("Caught: code={}, msg={}", getExceptionCode(), getExceptionMessage());
  end;

  guard
    raiseExceptionCode(42, "Custom error");
  except
    writeln("Except: code={}", getExceptionCode());
  finally
    writeln("Finally always runs");
  end;

  guard
    writeln("Result: {}", 10 div getZero());
  except
    writeln("Hardware exception caught: {}", getExceptionMessage());
  end;
end.
```

### Memory Management

Two levels: `create`/`destroy` for object instances, `getMem`/`freeMem`/`resizeMem` for raw allocation. Typed pointers support `address of`, dereference (`^`), and pointer arithmetic.

```myra
module exe memory;

var
  p:  pointer;
  pb: pointer to int8;
  x:  int32;
  px: pointer to int32;

begin
  p := getMem(100);
  pb := pointer to int8(p);
  pb^ := 42;
  writeln("Value at offset 0: {}", pb^);

  p := resizeMem(p, 200);
  pb := pointer to int8(p);
  writeln("Preserved offset 0: {}", pb^);
  freeMem(p);

  x := 42;
  px := address of x;
  writeln("Via pointer: {}", px^);
  px^ := 100;
  writeln("x is now: {}", x);
end.
```

### Pointers and Overlays

Named pointer types give typed pointers an alias. Overlays share the same memory region across fields, matching C union semantics. Anonymous overlays can be embedded inside records for tagged variant types.

```myra
module exe pointers_unions;

type
  PInt32 = pointer to int32;

  IntOrFloat = overlay
    i: int32;
    f: float32;
  end;

  Variant = record
    tag: int32;
    overlay
      asInt:   int32;
      asFloat: float32;
    end;
  end;

var
  p: PInt32;
  x: int32;
  u: IntOrFloat;
  v: Variant;

begin
  x := 12345;
  p := address of x;
  writeln("Via PInt32: {}", p^);

  u.i := 0x3F800000;  // IEEE 754 for 1.0
  writeln("Union float: {}", u.f);

  v.tag := 1;
  v.asInt := 99;
  writeln("Variant int: {}", v.asInt);
end.
```

### Variadic Routines

Declare with `...`. Use `varargs.count` for the argument count and `varargs.next(T)` to retrieve each argument.

```myra
module exe variadic;

routine sumInts(...): int32;
var
  i:   int32;
  sum: int32;
begin
  sum := 0;
  for i := 0 to varargs.count - 1 do
    sum := sum + varargs.next(int32);
  end;
  return sum;
end;

routine printAll(const prefix: string; ...);
var
  i: int32;
begin
  for i := 0 to varargs.count - 1 do
    writeln("{}: {}", prefix, varargs.next(int32));
  end;
end;

begin
  writeln("sumInts(10, 20, 30) = {}", sumInts(10, 20, 30));
  writeln("sumInts(1, 2, 3, 4, 5) = {}", sumInts(1, 2, 3, 4, 5));
  printAll("item", 100, 200, 300);
end.
```

### Module System

One source file, one output artifact. The module kind is declared on the first line. Symbols are module-private by default; use `exported` to make them visible.

#### Executable (`exe`)

```myra
module exe myprogram;

begin
  writeln("Hello!");
end.
```

#### Static Library (`lib`)

Compiled to `.lib` on Windows, `.a` on Linux. Import with `import`. Only `exported` symbols are visible.

```myra
module lib math;

routine dbl(const x: int32): int32;
begin
  return x + x;
end;

exported routine "C" add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

exported routine "C" quadruple(const x: int32): int32;
begin
  return dbl(dbl(x));
end;

end.
```

#### Shared Library (`dll`)

Compiled to `.dll` on Windows, `.so` on Linux.

```myra
module dll mylib;

exported routine "C" add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

exported var version: int32 = 1;

end.
```

#### Importing Modules

```myra
module exe myapp;

import math;

begin
  writeln("{}", math.add(3, 5));
  writeln("{}", math.quadruple(5));
end.
```

### FFI: Calling C Libraries

Declare the function signature, name the library, and call it. Use `external` for C functions in a DLL. Use `"C"` linkage for unmangled symbols. Varargs (`...`) are fully supported.

```myra
module exe ffi_demo;

routine "C" printf(const fmt: pointer to char; ...): int32;
external "msvcrt.dll";

routine "C" myFunc(): int32;
external "mylib.dll" name "my_actual_export";
```

Use `@linkLibrary` and `@libraryPath` to control linking. Use `@copyDll` to copy shared libraries to the output directory.

```myra
@linkLibrary "mylib.lib"
@libraryPath "libs/"
@copyDll "libs/mylib.dll"
```

### Seamless C++ Interop

Every Myra source file can freely intermix Myra code and C++ code. The rule is simple: if the compiler does not recognise a token as Myra, it treats it as C++ and passes it through verbatim. No special syntax, no bindings, no import tooling.

This works because Myra deliberately avoids colliding with any C++ keyword. Where C++ has `class`, Myra uses `object`. Where C++ has `enum`, Myra uses `choices`. Where C++ has `union`, Myra uses `overlay`. Where C++ has `try`, Myra uses `guard`. The lexer can unambiguously assign every token to either the Myra or C++ family with zero context needed.

#### Including C++ Headers

```myra
module exe mixedmode;

#include <cmath>
#include <cstring>

begin
  writeln("abs(-42) = {}", std::abs(-42));
  writeln("strlen = {}", int32(strlen("hello")));
end.
```

#### C++ Types as Myra Variables

```myra
var
  LS: std::string;

begin
  LS := "hello world";
  writeln("length = {}", LS.length());
  writeln("substr = {}", LS.substr(0, 5));
  LS.clear();
end.
```

#### C++ `new`/`delete` Alongside Myra `create`/`destroy`

```myra
var
  LPStr: std::string*;

begin
  LPStr := new std::string("hello from C++");
  writeln("{}", *LPStr);
  delete LPStr;
end.
```

#### C++ Casts and Namespaces

```myra
var
  LD: float64;
  LX: int32;

begin
  LD := 42.7;
  LX := static_cast<int32_t>(LD);
end.
```

C++ scope resolution (`::`) and arrow access (`->`) work naturally. Myra keywords inside C++ qualified names (like `std::ios::end`) are handled correctly -- the `::` operator signals C++ context.

### Directives and Conditional Compilation

Directives begin with `@` and are processed at compile time.

```myra
module exe conditional;

@define DEBUG

@ifdef DEBUG
  @message hint "Debug build active"
@endif

@ifdef TARGET_WIN64
routine "C" Sleep(const ms: uint32);
external "kernel32.dll";
@endif

begin
  @ifdef DEBUG
  writeln("Running in DEBUG mode");
  @endif
end.
```

**Predefined symbols:**

| Symbol | When defined |
|--------|--------------|
| `MYRA` | Always |
| `TARGET_WIN64`, `WIN64`, `MSWINDOWS`, `WINDOWS` | `@target win64` |
| `TARGET_LINUX64`, `LINUX`, `POSIX`, `UNIX` | `@target linux64` |
| `CPUX64` | `win64` or `linux64` |
| `CONSOLE_APP` | `@subsystem console` (default) |
| `GUI_APP` | `@subsystem gui` |

**Directive reference:**

| Directive | Description |
|-----------|-------------|
| `@subsystem type` | `console` or `gui` |
| `@target platform` | `win64`, `linux64` |
| `@optimize level` | `debug`, `releasesafe`, `releasefast`, `releasesmall` |
| `@define name` | Define a conditional symbol |
| `@undef name` | Undefine a symbol |
| `@ifdef`/`@ifndef`/`@elseif`/`@else`/`@endif` | Conditional compilation |
| `@message level "text"` | Compiler diagnostic at parse time |
| `@breakpoint` | Record debugger breakpoint location |
| `@linkLibrary "path"` | Link a library |
| `@libraryPath "path"` | Linker search path |
| `@modulePath "path"` | Module search path |
| `@copyDll "path"` | Copy DLL to output |
| `@exeIcon "path"` | Embed icon in EXE |
| `@addVerInfo` | Enable version info |
| `@viMajor`/`@viMinor`/`@viPatch` | Version numbers |
| `@viProductName`/`@viDescription`/`@viFilename`/`@viCompanyName`/`@viCopyright` | Version info strings |
| `@unitTestMode on` | Enable unit test framework |

### Intrinsics

| Intrinsic | Description |
|-----------|-------------|
| `len(expr)` | Elements in array or characters in string |
| `size(T)` | Size in bytes of a type |
| `utf8(wstr)` | Convert `wstring` to `string` |
| `getMem(size)` | Allocate heap memory |
| `resizeMem(ptr, size)` | Resize heap allocation |
| `paramCount()` | Number of command-line arguments |
| `paramStr(n)` | Nth command-line argument |
| `getExceptionCode()` | Active exception code (inside `except`) |
| `getExceptionMessage()` | Active exception message (inside `except`) |

### Built-in Test Blocks

`test` blocks appear after the module's closing `end.` and are compiled only in test mode. Each block has a name string for reporting.

| Assertion | Description |
|-----------|-------------|
| `testAssertEqualInt(expected, actual)` | Fail if integers differ |
| `testAssertEqualUInt(expected, actual)` | Fail if unsigned integers differ |
| `testAssertEqualFloat(expected, actual)` | Fail if floats differ |
| `testAssertEqualStr(expected, actual)` | Fail if strings differ |
| `testAssertEqualBool(expected, actual)` | Fail if booleans differ |
| `testAssertEqualPtr(expected, actual)` | Fail if pointers differ |
| `testAssertTrue(expr)` | Fail if not true |
| `testAssertFalse(expr)` | Fail if not false |
| `testAssertNil(ptr)` | Fail if not nil |
| `testAssertNotNil(ptr)` | Fail if nil |
| `testAssert(expr)` | Fail if false |
| `testFail("message")` | Unconditional failure |

```myra
module exe math_module;

@unitTestMode on

routine add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

begin
end.

test "addition"
begin
  testAssertEqualInt(5, add(2, 3));
  testAssertEqualInt(0, add(-1, 1));
end;

test "boolean checks"
begin
  testAssertTrue(add(1, 1) = 2);
  testAssertFalse(add(1, 1) = 3);
end;
```



## The `myra` CLI

The `myra` command is a standalone compiler that compiles Myra source files to native binaries.

### Usage

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

### Examples

```bash
myra -s hello.myra              # compile
myra -s hello.myra -o build     # compile to specific output directory
myra -s hello.myra -r           # compile and run
myra -s hello.myra -d           # compile and launch debugger
```

The compiler reads the `.mld` language definition files from `res/language/`, compiles the source through the pipeline (lex, parse, semantic analysis, C++23 code generation), and invokes Zig/Clang to produce a native binary. The Zig toolchain is bundled in `res/zig/`.


## Debugger

Myra includes DAP-compatible debugger integration via LLDB. Use `-d` to compile and launch an interactive debug REPL:

```bash
myra -s myprogram.myra -d
```

The `@breakpoint` directive in your source marks debugger stop locations. After compiling, a `.breakpoints` file is generated that the debugger loads automatically.

**Debug REPL commands:**

| Command | Description |
|---------|-------------|
| `b <file>:<line>` | Set a breakpoint |
| `bl` | List all breakpoints |
| `bd <id>` | Delete a breakpoint |
| `bc` | Clear all breakpoints |
| `c` | Continue execution |
| `n` | Step over |
| `s` | Step into |
| `finish` | Step out |
| `bt` | Show call stack |
| `threads` | List all threads |
| `locals` | Show local variables |
| `p <expr>` | Evaluate and print |
| `r` | Restart (preserves breakpoints) |
| `quit` | Exit |


## Cross-Platform Development

Myra supports Windows (Win64) and Linux (Linux64) from a single codebase. Only external library names differ between platforms. Cross-compilation from Windows to Linux64 uses Zig as the backend to produce ELF binaries. If WSL2 is installed, Myra automatically runs the result through WSL.

### Setting the Target

```myra
@target win64
// or
@target linux64
```

### WSL Setup (One Time)

```powershell
wsl --install -d Ubuntu
```

Then inside WSL:

```bash
sudo apt update && sudo apt install build-essential
```

| Target | Status |
|--------|--------|
| Windows x64 (`win64`) | Supported |
| Linux x64 (`linux64`) | Supported (native; via WSL on Windows) |


## Hacking the Language

Myra is not a closed system. The entire language definition ships as `.mld` files in `res/language/`:

| File | Lines | What it defines |
|------|-------|-----------------|
| `myra.mld` | 49 | Root: language declaration, imports, module paths |
| `myra_tokens.mld` | 340 | Every keyword, operator, delimiter, string style, directive |
| `myra_helpers.mld` | 610 | Shared routines: type resolution, signature building, type collection |
| `myra_grammar.mld` | 1448 | Every grammar rule: how source is parsed into the AST |
| `myra_semantics.mld` | 332 | Semantic analysis: scopes, symbol declaration, overload detection |
| `myra_emitters.mld` | 1230 | Code generation: how AST nodes become C++23 output |

These are human-readable text files in the MLD meta-language. They are not compiled artifacts or serialized data -- they are the actual source of truth for how Myra works.

### What You Can Do

**Read the implementation.** Want to know exactly how `match` statements are parsed? Open `myra_grammar.mld`, find `rule stmt.match`, and read the parsing logic. Want to see how `for` loops become C++ `for` statements? Open `myra_emitters.mld`, find `on stmt.for`, and see the code generation.

**Fix a compiler bug.** If the emitter generates wrong C++ for a construct, you can fix `myra_emitters.mld` directly and recompile. No waiting for a release, no building from Delphi source.

**Add a keyword.** Register it in `myra_tokens.mld`, add a grammar rule in `myra_grammar.mld`, add a semantic handler in `myra_semantics.mld`, and add an emitter in `myra_emitters.mld`. The compiler picks up the change immediately.

**Understand the type system.** The type mappings, compatibility rules, and widening matrix are all declared in `myra_tokens.mld`. It is a flat, readable table -- not buried in compiler source code.

**Change code generation.** Currently targeting C++23? The emitters can be modified to generate different output. The grammar and semantics are independent of the code generation target.

For the full MLD format reference, see [MLD.md](MLD.md).


## Formal Grammar (BNF)

### Syntax Notation

EBNF notation. Brackets `[` `]` denote optionality. Braces `{` `}` denote repetition. Parentheses `(` `)` group alternatives. `|` separates alternatives.

> **Design Principle:** Myra is a Pascal/Oberon-inspired systems programming language
> that compiles to C++23. To enable seamless C++ interop, **no Myra keyword
> collides with any C++ keyword.** Where C++ has a keyword, Myra uses an alternative:
> `object` instead of `class`, `choices` instead of `enum`, `overlay` instead of
> `union`, `match` instead of `switch`, `size` instead of `sizeof`.


### 1. Lexical Elements

```
letter     = "A" | ... | "Z" | "a" | ... | "z" | "_" .
digit      = "0" | ... | "9" .
hexDigit   = digit | "A" | ... | "F" | "a" | ... | "f" .

ident      = letter { letter | digit } .
integer    = digit { digit } | "0" ( "x" | "X" ) hexDigit { hexDigit } .
float_literal = digit { digit } "." { digit } [ exponent ] [ "f" | "F" ] .
exponent      = ( "e" | "E" ) [ "+" | "-" ] digit { digit } .
cstring    = '"' { character | escapeSeq } '"' .
wstring    = "w" '"' { character | escapeSeq } '"' .
escapeSeq  = "\" ( "n" | "t" | "r" | "0" | "\" | "'" | '"' | "x" hexDigit hexDigit ) .
```

#### Numeric Literal Type Rules

| Literal | Type | C++ Emit | Example |
|---------|------|----------|---------|
| `42` | `int32` | `42` | integer |
| `1.5` | contextual | see below | float |
| `1.5f` | `float32` | `1.5f` | explicit float32 |

Float literals without suffix resolve to `float32` or `float64` based on the assignment target. Default is `float64`.


### 2. Reserved Words

The language is **case-sensitive**.

```
address    align      and        array      begin      choices
const      create     destroy    div        do         downto
else       end        except     exported   external   false
finally    for        freeMem    getExceptionCode
getExceptionMessage   getMem     guard      if         import
in         is         leave      len        match      method     mod        module
nil        not        object     of         or         overlay
packed     paramCount paramStr   parent     pointer
raiseException        raiseExceptionCode    record     repeat
resizeMem  return     routine    self       set        setLength
shl        shr        size       skip       test       then       to         true
testAssert            testAssertTrue        testAssertFalse
testAssertEqualInt    testAssertEqualUInt   testAssertEqualFloat
testAssertEqualStr    testAssertEqualBool   testAssertEqualPtr
testAssertNil         testAssertNotNil      testFail
type       until      utf8       var        varargs    while
write      writeln    xor
```

> `exe`, `dll`, and `lib` are contextual -- special only in `ModuleKind` position.


### 3. Built-in Types

| Myra Type | C++ Type |
|-----------|----------|
| `int8` | `int8_t` |
| `int16` | `int16_t` |
| `int32` | `int32_t` |
| `int64` | `int64_t` |
| `uint8` | `uint8_t` |
| `uint16` | `uint16_t` |
| `uint32` | `uint32_t` |
| `uint64` | `uint64_t` |
| `float32` | `float` |
| `float64` | `double` |
| `boolean` | `bool` |
| `char` | `char` |
| `wchar` | `wchar_t` |
| `string` | `std::string` |
| `wstring` | `std::wstring` |
| `pointer` | `void*` |

Unknown type names pass through to C++ output (e.g., `std::vector<int32>` reaches Clang unmodified).


### 4. Operators and Delimiters

```
+    -    *    /    =    <>   <    >    <=   >=
:=   +=   -=   *=   /=
:    ;    ,    .    ..   ...  ^    |    &
(    )    [    ]
```

- `:=` -- Assignment (emits `=`)
- `=` -- Comparison (emits `==`)
- `<>` -- Not equal (emits `!=`)
- `^` -- Postfix pointer dereference


### 5. Comments

```
Comment = "//" { character } newline
        | "/*" { character | Comment } "*/" .
```


### 6. Module Structure

```
ModuleFile    = Module { TestBlock } .
Module        = "module" ModuleKind ident ";" [ Directives ] [ ImportClause ]
                { Declaration } [ "begin" StatementSeq ] "end" "." .
TestBlock     = "test" cstring [ VarBlock ] "begin" StatementSeq "end" ";" .
ModuleKind    = "exe" | "dll" | "lib" .
ImportClause  = "import" ident { "," ident } ";" .
```


### 7. Conditional Compilation

```
DefineDir   = "@define" ident .
UndefDir    = "@undef" ident .
IfdefDir    = "@ifdef" ident .
IfndefDir   = "@ifndef" ident .
ElseIfDir   = "@elseif" ident .
ElseDir     = "@else" .
EndifDir    = "@endif" .
```


### 8. Declarations

```
Declaration     = [ "exported" ] ( ConstSection | TypeSection | VarSection | RoutineDecl ) .
ConstSection    = "const" { ConstDecl } .
ConstDecl       = ident [ ":" TypeExpr ] "=" Expression ";" .
TypeSection     = "type" { TypeDecl } .
TypeDecl        = ident "=" TypeDef ";" .
VarSection      = "var" { VarDecl } .
VarDecl         = ident ":" TypeExpr [ "=" Expression ] ";" [ ExternalVarClause ] .
ExternalVarClause = "external" [ cstring | ident ] ";" .
```


### 9. Routine Declarations

```
RoutineDecl     = "routine" [ LinkageSpec ] ident [ FormalParams ] [ ":" TypeExpr ] ";"
                  ( ExternalClause | RoutineBody ) .
LinkageSpec     = '"C"' .
FormalParams    = "(" [ ParamList ] ")" .
ParamList       = ParamDecl { ";" ParamDecl } [ ";" "..." ] | "..." .
ParamDecl       = [ "var" | "const" ] ident ":" TypeExpr .
ExternalClause  = "external" [ cstring | ident ] ";" .
RoutineBody     = [ "type" { TypeDecl } ] [ "const" { ConstDecl } ]
                  [ "var" { VarDecl } ] "begin" StatementSeq "end" ";" .
```


### 10. Type Definitions

```
TypeDef         = RecordType | ObjectType | OverlayType | ArrayType
                | PointerType | SetType | ChoicesType | RoutineType | TypeExpr .
RecordType      = "record" [ "(" TypeExpr ")" ] [ "packed" ] [ "align" "(" integer ")" ]
                  { FieldDecl | AnonOverlay } "end" .
ObjectType      = "object" [ "(" TypeExpr ")" ] { FieldDecl | MethodDecl } "end" .
OverlayType     = "overlay" { FieldDecl | AnonRecord } "end" .
AnonRecord      = "record" [ "packed" ] { FieldDecl | AnonOverlay } "end" ";" .
AnonOverlay     = "overlay" { FieldDecl | AnonRecord } "end" ";" .
FieldDecl       = ident ":" TypeExpr [ ":" integer ] ";" .
MethodDecl      = "method" ident [ FormalParams ] [ ":" TypeExpr ] ";"
                  [ "var" { VarDecl } ] "begin" StatementSeq "end" ";" .
ArrayType       = "array" [ "[" [ ArrayBounds ] "]" ] "of" TypeExpr .
ArrayBounds     = integer ".." integer .
PointerType     = "pointer" [ "to" [ "const" ] TypeExpr ] .
SetType         = "set" [ "of" ( integer ".." integer | TypeExpr ) ] .
ChoicesType     = "choices" "(" ChoicesValue { "," ChoicesValue } ")" .
ChoicesValue    = ident [ "=" Expression ] .
RoutineType     = "routine" [ LinkageSpec ] "(" [ ParamList ] ")" [ ":" TypeExpr ] .
TypeExpr        = QualIdent | PointerType | ArrayType | SetType .
QualIdent       = ident { "." ident } .
```


### 11. Statements

```
StatementSeq    = { Statement } .
Statement       = Assignment | CallStmt | IfStmt | WhileStmt | ForStmt
                | RepeatStmt | LeaveStmt | SkipStmt
                | MatchStmt | ReturnStmt | GuardStmt | RaiseStmt
                | CreateStmt | DestroyStmt
                | GetMemStmt | FreeMemStmt | ResizeMemStmt | SetLengthStmt
                | WriteStmt | TestAssertStmt | Directive | ";" .

Assignment      = Designator ( ":=" | "+=" | "-=" | "*=" | "/=" ) Expression [ ";" ] .
CallStmt        = Designator [ ";" ] .
IfStmt          = "if" Expression "then" StatementSeq [ "else" StatementSeq ] "end" [ ";" ] .
WhileStmt       = "while" Expression "do" StatementSeq "end" [ ";" ] .
ForStmt         = "for" ident ":=" Expression ( "to" | "downto" ) Expression
                  "do" StatementSeq "end" [ ";" ] .
RepeatStmt      = "repeat" StatementSeq "until" Expression [ ";" ] .
LeaveStmt       = "leave" [ ";" ] .
SkipStmt        = "skip" [ ";" ] .
MatchStmt       = "match" Expression "of" { MatchArm } [ "else" StatementSeq ] "end" [ ";" ] .
MatchArm        = MatchLabel { "," MatchLabel } ":" StatementSeq .
MatchLabel      = Expression [ ".." Expression ] .
ReturnStmt      = "return" [ Expression ] [ ";" ] .
GuardStmt       = "guard" StatementSeq
                  ( "except" StatementSeq [ "finally" StatementSeq ]
                  | "finally" StatementSeq ) "end" [ ";" ] .
RaiseStmt       = ( "raiseException" "(" Expression ")"
                  | "raiseExceptionCode" "(" Expression "," Expression ")" ) [ ";" ] .
CreateStmt      = "create" "(" Expression ")" [ ";" ] .
DestroyStmt     = "destroy" "(" Expression ")" [ ";" ] .
GetMemStmt      = "getMem" "(" Expression ")" [ ";" ] .
FreeMemStmt     = "freeMem" "(" Expression ")" [ ";" ] .
ResizeMemStmt   = "resizeMem" "(" Expression "," Expression ")" [ ";" ] .
SetLengthStmt   = "setLength" "(" Expression "," Expression ")" [ ";" ] .
WriteStmt       = ( "write" | "writeln" ) "(" [ ArgList ] ")" [ ";" ] .
TestAssertStmt  = ( "testAssert" | "testAssertTrue" | "testAssertFalse"
                | "testAssertNil" | "testAssertNotNil" ) "(" Expression ")" [ ";" ]
                | ( "testAssertEqualInt" | "testAssertEqualUInt"
                | "testAssertEqualFloat" | "testAssertEqualStr"
                | "testAssertEqualBool" | "testAssertEqualPtr" )
                  "(" Expression "," Expression ")" [ ";" ]
                | "testFail" "(" Expression ")" [ ";" ] .
```

> C++ statements (`#include`, `using namespace`, etc.) are handled by the
> compiler's C++ passthrough layer and pass through to the C++ output verbatim.


### 12. Expressions

```
Expression      = OrExpr .
OrExpr          = AndExpr { "or" AndExpr } .
AndExpr         = CompExpr { ( "and" | "xor" ) CompExpr } .
CompExpr        = SimpleExpr [ RelOp SimpleExpr ] .
RelOp           = "=" | "<>" | "<" | ">" | "<=" | ">=" | "in" .
SimpleExpr      = [ "+" | "-" ] ShiftExpr { AddOp ShiftExpr } .
AddOp           = "+" | "-" .
ShiftExpr       = Term { ShiftOp Term } .
ShiftOp         = "shl" | "shr" .
Term            = Factor { MulOp Factor } .
MulOp           = "*" | "/" | "div" | "mod" .
Factor          = "not" Factor | "-" Factor | "+" Factor
                | "address" "of" Factor | Primary .
Primary         = integer | float_literal | cstring | wstring
                | "true" | "false" | "nil"
                | SetLiteral | "(" Expression ")" | Designator | Intrinsic | TypeCast .
Designator      = ( ident | "self" | "parent" | "varargs" ) { Selector } .
Selector        = "." ident | "[" Expression "]" | "^" | "(" [ ArgList ] ")" .
ArgList         = Expression { "," Expression } .
SetLiteral      = "[" [ SetElement { "," SetElement } ] "]" .
SetElement      = Expression [ ".." Expression ] .
TypeCast        = TypeExpr "(" Expression ")" .
```


### 13. Intrinsics

```
LenExpr                  = "len" "(" Expression ")" .
SizeExpr                 = "size" "(" ( TypeExpr | Expression ) ")" .
Utf8Expr                 = "utf8" "(" Expression ")" .
ParamCountExpr           = "paramCount" "(" ")" .
ParamStrExpr             = "paramStr" "(" Expression ")" .
GetExceptionCodeExpr     = "getExceptionCode" "(" ")" .
GetExceptionMessageExpr  = "getExceptionMessage" "(" ")" .
```


### 14. Variadic Arguments

```
ParamList       = ParamDecl { ";" ParamDecl } [ ";" "..." ] | "..." .
VarArgsAccess   = "varargs" "." "next" "(" TypeExpr ")"
                | "varargs" "." "copy" "(" ")"
                | "varargs" "." "count" .
```


### 15. Operator Precedence (Highest to Lowest)

| Precedence | Operators |
|------------|-----------|
| 1 (highest) | `not` `-` `+` (unary) `address of` |
| 2 | `*` `/` `div` `mod` |
| 3 | `shl` `shr` |
| 4 | `+` `-` |
| 5 | `=` `<>` `<` `>` `<=` `>=` `in` |
| 6 | `and` `xor` |
| 7 (lowest) | `or` |


### 16. C++ Interop

Myra provides seamless C++ passthrough as a built-in capability. Every Myra source file can freely mix Myra code and raw C++ code without any special syntax or escape mechanism.

**What Myra defines** (semantically analyzed): all keywords, types, and grammar constructs listed in this BNF.

**What C++ provides** (passthrough, no semantic analysis by Myra): all C++ keywords and constructs (`class`, `struct`, `template`, `namespace`, etc.), `{ }` blocks, `::` qualified names, `->` arrow access, preprocessor directives (`#include`, `#define`), and standard C++ exception syntax (`try`/`catch`/`throw`).


<div align="center">

**Myra** Programming Language.

Copyright 2025-present tinyBigGAMES LLC
All Rights Reserved.

</div>
