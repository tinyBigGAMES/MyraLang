![Myra](../media/myra.png)

# MLD Reference Manual

The Myra Language Definition format.

## Table of Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Tokens Block](#tokens-block)
4. [Types Block](#types-block)
5. [Grammar Block](#grammar-block)
6. [Semantics Block](#semantics-block)
7. [Emitters Block](#emitters-block)
8. [The Imperative Language](#the-imperative-language)
9. [Routines and Constants](#routines-and-constants)
10. [Fragments, Imports, and Includes](#fragments-imports-and-includes)
11. [Built-in Functions Reference](#built-in-functions-reference)
12. [Formal Grammar (EBNF)](#formal-grammar-ebnf)


## Overview

MLD (Myra Language Definition) is the meta-language used to define the Myra programming language. A `.mld` file describes a complete compiler pipeline: lexer tokens, Pratt parser grammar, multi-pass semantic analysis, and code generation. The Myra compiler engine reads the `.mld` files, populates its internal dispatch tables, and then uses those tables to compile `.myra` source files into native binaries.

Myra's language definition is split across six `.mld` files via `import` statements:

| File | Lines | Purpose |
|------|-------|---------|
| `myra.mld` | 49 | Root file: language declaration, imports, module paths |
| `myra_tokens.mld` | 340 | All token declarations and type system |
| `myra_helpers.mld` | 610 | Shared routines (resolveType, collectTypeText, buildRoutineSig, etc.) |
| `myra_grammar.mld` | 1448 | All grammar rules (prefix, infix, statement) |
| `myra_semantics.mld` | 332 | Semantic analysis handlers |
| `myra_emitters.mld` | 1230 | C++23 code generation handlers |

MLD is Turing complete: variables, loops, conditionals, recursion, and string operations are all first-class constructs alongside declarative grammar rules and token definitions. Every handler body uses the same unified language. No host language glue code, no build system integration, no escape hatch to C, Java, or Python. The `.mld` files are self-contained, portable language specifications.

The compilation pipeline works in two phases. In the setup phase, the `.mld` files are parsed and their contents populate dispatch tables (token registrations, grammar rules, semantic handlers, emitter handlers, user-defined routines). In the compilation phase, these tables drive a generic lexer, Pratt parser, semantic analyzer, and code generator that process `.myra` source files and produce C++23 output, which is then compiled to native binaries via Zig/Clang.

## File Structure

A `.mld` file begins with a `language` declaration and contains top-level blocks that describe each aspect of the language. Comments use `//` (line) and `/* ... */` (block).

```mld
language Myra version "1.0";

// Optional: constants must appear before they are referenced
const {
  ENABLE_OVERLOADS = true;
  ENABLE_FORWARD_REFS = true;
}

// Optional: define conditional compilation symbols
setDefine("MYRA");

// Optional: module search paths
addModulePath("res/libs/std");

// Optional: imports load other .mld files
import "myra_tokens.mld";
import "myra_helpers.mld";
import "myra_grammar.mld";
import "myra_semantics.mld";
import "myra_emitters.mld";

tokens {
  // Keywords, operators, delimiters, comments, strings, directives, config
}

types {
  // Type keywords, type mappings, literal types, compatibility rules
}

grammar {
  // Prefix, infix, and statement rules
}

semantics {
  // Semantic analysis handlers (scope, declare, visit)
}

emitters {
  // Code generation handlers
}

// Reusable helper routines (callable from any handler)
routine resolveType(typeText: string) -> string {
  if typeText == "int32" { return "int32_t"; }
  return typeText;
}
```

Top-level constructs that can appear in a `.mld` file:

| Construct | Description |
|-----------|-------------|
| `language Name version "X.Y";` | Language declaration (required, must be first) |
| `tokens { ... }` | Token declarations and lexer configuration |
| `types { ... }` | Type system configuration |
| `grammar { ... }` | Parser grammar rules |
| `semantics { ... }` | Semantic analysis handlers |
| `emitters { ... }` | Code generation handlers |
| `const { ... }` | Named constants |
| `enum Name { ... }` | Enum declarations |
| `routine name(...) { ... }` | User-defined routines |
| `fragment name { ... }` | Reusable declaration blocks |
| `import "file.mld";` | Load external `.mld` file |
| `include fragmentName;` | Expand a fragment |
| `guard EXPR { ... }` | Conditional inclusion |


## Tokens Block

The `tokens {}` block teaches the lexer how to break source code into meaningful pieces. Every `token` entry follows the pattern:

```mld
token category.name = "text" [flags];
```

The `category` prefix determines how the token is registered with the engine:

| Category | Description |
|----------|-------------|
| `keyword.*` | Reserved word |
| `op.*` | Operator |
| `delimiter.*` | Punctuation/delimiter |
| `comment.line` | Line comment prefix |
| `comment.block_open` / `comment.block_close` | Block comment delimiters |
| `string.*` | String literal style |
| `directive.*` | Named directive |

### Keywords

Keywords are reserved words. Once declared, the lexer emits the specified token kind instead of `identifier`. These words can never be used as variable or function names.

```mld
tokens {
  casesensitive = true;

  // Module structure
  token keyword.module    = "module";
  token keyword.import    = "import";
  token keyword.exported  = "exported";
  token keyword.external  = "external";

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
  token keyword.return    = "return";
  token keyword.match     = "match";
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

  // Logical / bitwise operators
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

  // Literals
  token keyword.true      = "true";
  token keyword.false     = "false";
  token keyword.nil       = "nil";

  // ... (full list in myra_tokens.mld)
}
```

### Operators and Delimiters

The engine sorts operators by length internally to ensure longest-match behavior (`:=` matches before `:`), but declaring multi-character operators first serves as documentation.

```mld
tokens {
  // Multi-character operators (longest-match order)
  token op.assign         = ":=";
  token op.plus_assign    = "+=";
  token op.minus_assign   = "-=";
  token op.mul_assign     = "*=";
  token op.div_assign     = "/=";
  token op.neq            = "<>";
  token op.lte            = "<=";
  token op.gte            = ">=";
  token op.ellipsis       = "...";
  token op.range          = "..";

  // Single-character operators
  token op.eq             = "=";
  token op.lt             = "<";
  token op.gt             = ">";
  token op.plus           = "+";
  token op.minus          = "-";
  token op.multiply       = "*";
  token op.divide         = "/";
  token op.deref          = "^";

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

### Comments

Line comments use `comment.line`. Block comments require a `comment.block_open` / `comment.block_close` pair. Multiple comment styles can be declared.

```mld
tokens {
  token comment.line        = "//";
  token comment.block_open  = "/*";
  token comment.block_close = "*/";
}
```

### String Styles

The default behavior (no flags) processes backslash escape sequences (`\n`, `\t`, `\\`, etc.) and uses the pattern text as both opening and closing delimiter. Use `[noescape]` to disable escapes (Pascal-style `''` convention). Use `[close "X"]` when the opening delimiter differs from the closing delimiter.

```mld
tokens {
  // C-style escaped string: "..."
  token string.cstring    = "\"";
  // Wide string: w"..." with escape sequences, closes on "
  token string.wstring    = "w\"" [close "\""];
}
```

| Flag | Description |
|------|-------------|
| `noescape` | Disable backslash escape processing. Two consecutive close delimiters represent one literal close delimiter. |
| `close "X"` | Use `X` as the closing delimiter instead of the opening pattern. |

### Directives

Directives are a two-tier system. Some are handled by the lexer at lex time (conditional compilation directives like `@ifdef` and `@endif`). Others are passed through to the parser as regular tokens.

```mld
tokens {
  directive_prefix = "@";

  // Conditional compilation directives (handled by lexer)
  token directive.define   = "define"  [define];
  token directive.undef    = "undef"   [undef];
  token directive.ifdef    = "ifdef"   [ifdef];
  token directive.ifndef   = "ifndef"  [ifndef];
  token directive.elseif   = "elseif"  [elseif];
  token directive.else     = "else"    [else];
  token directive.endif    = "endif"   [endif];

  // Regular directives (passed to parser as tokens)
  token directive.exeicon       = "exeicon";
  token directive.copydll       = "copydll";
  token directive.linklibrary   = "linklibrary";
  token directive.librarypath   = "librarypath";
  token directive.modulepath    = "modulepath";
  token directive.includepath   = "includepath";
  token directive.subsystem     = "subsystem";
  token directive.target        = "target";
  token directive.optimize      = "optimize";
  token directive.breakpoint    = "breakpoint";
  token directive.message       = "message";
  token directive.unittestmode  = "unitTestMode";
  // ... version info directives
}
```

| Flag | Description |
|------|-------------|
| `define` | Conditional compilation: `@define` |
| `undef` | Conditional compilation: `@undef` |
| `ifdef` | Conditional compilation: `@ifdef` |
| `ifndef` | Conditional compilation: `@ifndef` |
| `elseif` | Conditional compilation: `@elseif` |
| `else` | Conditional compilation: `@else` |
| `endif` | Conditional compilation: `@endif` |

### Structural Configuration

Key-value assignments in the `tokens {}` block configure the parser engine:

```mld
tokens {
  casesensitive = true;
  terminator  = delimiter.semicolon;
  block_open  = keyword.begin;
  block_close = keyword.end;
  hex_prefix  = "0x";
  hex_prefix  = "0X";
}
```

| Setting | Description |
|---------|-------------|
| `casesensitive = true/false;` | Keyword matching case sensitivity |
| `identifier_start = "chars";` | Characters that can start an identifier |
| `identifier_part = "chars";` | Characters that can continue an identifier |
| `terminator = kind;` | Statement terminator token kind |
| `block_open = kind;` | Block-open token kind |
| `block_close = kind;` | Block-close token kind |
| `directive_prefix = "text";` | Directive prefix character(s) |
| `hex_prefix = "text";` | Hex literal prefix |
| `binary_prefix = "text";` | Binary literal prefix |


## Types Block

The `types {}` block connects three worlds: source type names (what the user writes), internal type kinds (how the engine tracks types), and C++ types (what gets generated). When a user writes `var x: int32;`, the types block tells the engine that `int32` maps to `type.int32` internally, and `type.int32` maps to `int32_t` in C++.

### Type Keywords

Map source type names to internal type kind strings:

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

### Type Mappings

Map internal type kinds to C++ output types:

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

### Literal Type Mappings

Connect AST node kinds (from the parser) to type kinds (for the type system):

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

### Type Compatibility

Define type widening and coercion rules. Each `compatible` entry specifies a source type, target type, and the resulting coercion type:

```mld
types {
  // Integer widening
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
  // ... (full matrix in myra_tokens.mld)

  // Nil to pointer
  compatible "type.nil", "type.pointer";

  // Char to string promotion
  compatible "type.char",  "type.string"  -> "type.string";
  compatible "type.wchar", "type.wstring" -> "type.wstring";
}
```

When the `->` coerce_to is omitted, it defaults to the target type.

### Declaration and Call Kinds

Tell the semantic engine which AST node kinds represent declarations and calls:

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
| `call_name_attr = "attr";` | Attribute name holding callee name on call nodes |



## Grammar Block

The `grammar {}` block defines how the token stream is parsed into an AST. The engine uses a Pratt parser where each token can trigger a **prefix** handler (at the start of an expression), an **infix** handler (between two expressions), or a **statement** handler (at statement position).

The node kind prefix determines how each rule is registered:

| Prefix | Registration | Trigger |
|--------|-------------|---------|
| `expr.*` (no precedence) | Prefix | First `expect`/`consume` token |
| `expr.*` + `precedence left N` | Infix left | First `expect`/`consume` token |
| `expr.*` + `precedence right N` | Infix right | First `expect`/`consume` token |
| `stmt.*` | Statement | First `expect`/`consume` token |

### Prefix Rules

Prefix rules fire when a matching token appears at expression-start position. They handle literals, identifiers, unary operators, and grouped expressions.

```mld
grammar {
  // Literals
  rule expr.integer {
    consume literal.integer -> @value;
  }
  rule expr.float {
    consume literal.float -> @value;
  }
  rule expr.cstring {
    consume string.cstring -> @value;
  }
  rule expr.wstring {
    consume string.wstring -> @value;
  }

  // Keyword literals
  rule expr.nil {
    expect keyword.nil;
  }
  rule expr.bool {
    consume keyword.true -> @value;
  }
  rule expr.bool {
    consume keyword.false -> @value;
  }

  // Identifier
  rule expr.ident {
    consume identifier -> @name;
  }

  // Grouped expression
  rule expr.grouped {
    expect delimiter.lparen;
    parse expr -> @inner;
    expect delimiter.rparen;
  }

  // Unary operators (binding power 35)
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

  // address of expr
  rule expr.address_of {
    expect keyword.address;
    requireToken("keyword.of");
    let nd = getResultNode();
    addChild(nd, parseExpr(35));
  }

  // Set literal: [elem, elem..elem, ...]
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
        let elem2 = createNode("expr.set_element");
        addChild(elem2, parseExpr(0));
        if matchToken("op.range") {
          addChild(elem2, parseExpr(0));
        }
        addChild(nd, elem2);
      }
    }
    requireToken("delimiter.rbracket");
  }
}
```

### Intrinsics as Prefix Rules

Myra's intrinsic functions (len, size, utf8, paramcount, paramstr, getmem, resizemem, etc.) are parsed as prefix rules that produce `expr.call` nodes with a pre-set `call.name` attribute:

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

### Infix Rules

Infix rules fire when the trigger token appears after an already-parsed left expression. The left operand is child 0 of the result node. Binding power determines grouping: `2 + 3 * 4` groups as `2 + (3 * 4)` because multiplication (power 30) binds tighter than addition (power 20).

```mld
grammar {
  // Assignment (right-associative, power 2)
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

  // Function call (power 40)
  rule expr.call precedence left 40 {
    expect delimiter.lparen;
    let nd = getResultNode();
    // Extract call name from the callee (child 0)
    let left = getChild(nd, 0);
    if nodeKind(left) == "expr.ident" {
      setAttr(nd, "call.name", getAttr(left, "name"));
    }
    // Parse arguments
    if not checkToken("delimiter.rparen") {
      addChild(nd, parseExpr(0));
      while matchToken("delimiter.comma") {
        addChild(nd, parseExpr(0));
      }
    }
    requireToken("delimiter.rparen");
  }

  // Array index (power 45)
  rule expr.array_index precedence left 45 {
    expect delimiter.lbracket;
    let nd = getResultNode();
    addChild(nd, parseExpr(0));
    requireToken("delimiter.rbracket");
  }

  // Field access (power 45)
  rule expr.field_access precedence left 45 {
    expect delimiter.dot;
    let nd = getResultNode();
    setAttr(nd, "field.name", currentText());
    advance();
  }

  // Pointer dereference (power 50)
  rule expr.deref precedence left 50 {
    expect cpp.op.bitxor;
  }
}
```

### Binding Power Scale

| Power | Category |
|-------|----------|
| 2 | Assignment (right-associative) |
| 6 | Logical OR |
| 8 | Logical AND, XOR |
| 10 | Comparison (`=`, `<>`, `<`, `>`, `<=`, `>=`), set membership (`in`) |
| 20 | Addition/subtraction |
| 25 | Bitwise shift (`shl`, `shr`) |
| 30 | Multiplication/division/modulo |
| 35 | Unary prefix (not, negate, address-of) |
| 40 | Call |
| 45 | Array index, field access |
| 50 | Dereference |

### Statement Rules

Statement rules fire when their trigger token appears at statement position. They handle language constructs like `module`, `if`, `while`, `for`, variable declarations, and routine definitions.

```mld
grammar {
  // Module: module kind name; [directives] [imports] {decls} [begin body end] end.
  rule stmt.module {
    expect keyword.module;
    let nd = getResultNode();
    setAttr(nd, "module.kind", currentText());
    advance();
    setAttr(nd, "module.name", currentText());
    advance();
    requireToken("delimiter.semicolon");
    // Optional directives, imports, declarations...
    // Optional module body: begin StatementSeq end .
    if matchToken("keyword.begin") {
      let body = createNode("stmt.module_body");
      while not checkToken("keyword.end") and not checkToken("eof") {
        let s = parseStmt();
        if s != nil { addChild(body, s); }
      }
      addChild(nd, body);
    }
    requireToken("keyword.end");
    requireToken("delimiter.dot");
  }

  // If/then/else/end
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

  // While/do/end
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

  // For/to|downto/do/end
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

  // Match/of/end
  rule stmt.match {
    expect keyword.match;
    let nd = getResultNode();
    addChild(nd, parseExpr(0));
    requireToken("keyword.of");
    // Parse match arms, optional else, end
    // ... (see myra_grammar.mld for full implementation)
    requireToken("keyword.end");
    matchToken("delimiter.semicolon");
  }

  // Var block: var { ident : type [= expr]; }
  rule stmt.var_block {
    expect keyword.var;
    let nd = getResultNode();
    while checkToken("identifier") {
      let nameTok = currentText();
      advance();
      let v = createNode("stmt.var_decl");
      setAttr(v, "var.name", nameTok);
      requireToken("delimiter.colon");
      let typeRaw = collectTypeText();
      setAttr(v, "var.type_text", typeRaw);
      if matchToken("op.eq") {
        addChild(v, parseExpr(0));
      }
      requireToken("delimiter.semicolon");
      addChild(nd, v);
    }
  }

  // Routine declaration
  rule stmt.routine_decl {
    expect keyword.routine;
    let nd = getResultNode();
    // Optional linkage: "C"
    if checkToken("string.cstring") {
      setAttr(nd, "decl.linkage", currentText());
      advance();
    }
    setAttr(nd, "decl.name", currentText());
    advance();
    // Parameters, return type, external or body...
    // (see myra_grammar.mld for full implementation)
  }
}
```

### Grammar Declarative Reference

| Syntax | Description |
|--------|-------------|
| `expect TOKEN_KIND;` | Assert current token matches kind, consume it. Error if mismatch. |
| `consume TOKEN_KIND -> @attr;` | Consume token, store its text as attribute on result node. |
| `consume [K1, K2, ...] -> @attr;` | Consume if current token is any of listed kinds, store text. |
| `parse expr -> @attr;` | Parse a sub-expression (power 0), add as child. |
| `parse many stmt until KIND -> @attr;` | Parse statements until `KIND`, collect into block child. |
| `optional { ... }` | Execute block only if the next token allows it. |
| `sync TOKEN_KIND;` | Declare error recovery point. |

### Required Number Literal Grammar Rules

The generic lexer automatically produces `literal.integer` and `literal.float` tokens, but the parser requires explicit prefix grammar rules to consume them. Without these, numeric expressions fail:

```mld
grammar {
  rule expr.integer {
    consume literal.integer -> @value;
  }
  rule expr.float {
    consume literal.float -> @value;
  }
}
```

### Myra Grammar Rule Catalog

**Prefix expressions:** `expr.integer`, `expr.float`, `expr.cstring`, `expr.cchar`, `expr.wstring`, `expr.nil`, `expr.bool`, `expr.ident`, `expr.self`, `expr.parent`, `expr.varargs`, `expr.not`, `expr.negate`, `expr.unary_plus`, `expr.address_of`, `expr.grouped`, `expr.set_literal`, `expr.pointer_cast`, intrinsics as `expr.call` (len, size, utf8, paramcount, paramstr, getexceptioncode, getexceptionmessage, getmem, resizemem)

**Infix expressions:** `expr.assign` (power 2, right), `expr.binary` (arithmetic power 20/30, comparison power 10, logical power 6/8), `expr.shl`/`expr.shr` (power 25), `expr.in` (power 10), `expr.call` (power 40), `expr.array_index` (power 45), `expr.field_access` (power 45), `expr.deref` (power 50)

**Statements:** `stmt.module`, `stmt.var_block`, `stmt.const_block`, `stmt.type_block`, `stmt.exported`, `stmt.routine_decl`, `stmt.method_decl`, `stmt.begin_block`, `stmt.if`, `stmt.while`, `stmt.for`, `stmt.repeat`, `stmt.match`, `stmt.return`, `stmt.leave`, `stmt.skip`, `stmt.guard`, `stmt.raiseexception`, `stmt.raiseexceptioncode`, `stmt.create`, `stmt.destroy`, `stmt.getmem`, `stmt.freemem`, `stmt.resizemem`, `stmt.setlength`, `stmt.writeln`, `stmt.write`, `stmt.test_block`, test assertions (`stmt.testassert`, `stmt.testasserttrue`, etc.), all directive statements (`stmt.directive_optimize`, `stmt.directive_subsystem`, etc.)


## Semantics Block

The `semantics {}` block validates that a syntactically correct program is also meaningful. Semantic handlers walk the AST, manage scopes, declare and look up symbols, and report errors.

### Basic Handlers

Each `on` handler fires when a node of the matching kind is visited. The most common operations are pushing/popping scopes, declaring symbols, and visiting children.

```mld
semantics {
  on program.root {
    scope "global" {
      visit children;
    }
  }

  // Module: set build mode, scope, visit
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

  // Import: trigger module compilation
  on stmt.import_item {
    let iname = getAttr(node, "import.name");
    setAttr(node, "iname", iname);
    setAttr(node, "itype", "module");
    pushBuildState();
    setModuleExtension("myra");
    compileModule(iname);
    popBuildState();
    declare @iname as variable typed @itype;
  }

  // Variable declaration
  on stmt.var_decl {
    setAttr(node, "vname", getAttr(node, "var.name"));
    setAttr(node, "vtype", getAttr(node, "var.type_text"));
    declare @vname as variable typed @vtype;
    visit children;
  }

  // Routine with overload detection
  on stmt.routine_decl {
    let rname = getAttr(node, "decl.name");
    // Build signature key: "Name(type1,type2)"
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
    // Overload detection
    if symbolExistsWithPrefix(rname + "(") {
      demoteCLinkageForPrefix(rname + "(");
    }
    setAttr(node, "sig", sig);
    declare @sig as routine;
    scope @rname {
      visit children;
    }
  }

  // Exported: stamp attributes on children
  on stmt.exported {
    let n = child_count();
    if n > 0 {
      let ch = getChild(node, 0);
      let chKind = nodeKind(ch);
      if chKind == "stmt.routine_decl" {
        setAttr(ch, "decl.exported", "true");
      }
      // ... (also handles var blocks)
    }
    visit children;
  }

  // Expression handlers
  on expr.assign { visit children; }
  on expr.call   { visit children; }
  on expr.binary { visit children; }
  on expr.ident  { }
}
```

### Semantics Declarative Reference

| Syntax | Description |
|--------|-------------|
| `scope "name" { ... }` | Push named scope, execute body, pop scope |
| `scope @attr { ... }` | Push scope named by attribute value |
| `declare @attr as variable;` | Declare symbol as a variable |
| `declare @attr as routine;` | Declare symbol as a routine |
| `declare @attr as type;` | Declare symbol as a type |
| `declare @attr as constant;` | Declare symbol as a constant |
| `declare @attr as parameter;` | Declare symbol as a parameter |
| `declare @attr as KIND typed @type;` | Declare with type information |
| `visit children;` | Visit all children of current node |
| `visit @attr;` | Visit child stored in named attribute |
| `visit child[N];` | Visit child at index N |
| `lookup @attr -> let sym;` | Look up symbol, bind to variable |
| `lookup @attr or { ... };` | Look up symbol, execute block if not found |

### Multi-Pass Semantics

For languages requiring forward reference resolution, use `pass` blocks:

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

Each pass walks the full AST with only that pass's handlers active. The scope tree persists across passes. The scope stack resets to the root between passes.

### Myra Semantic Features

Myra's semantic handlers implement several notable features:

- **Overload detection:** When declaring a routine, the handler builds a signature key (`Name(type1,type2)`) and checks for existing symbols with the same name prefix. If found, C linkage is demoted for all overloads.
- **Module compilation:** The `stmt.import_item` handler calls `compileModule(name)` to trigger recursive compilation of imported modules, with build state push/pop to protect the parent's configuration.
- **Pointer access detection:** The `expr.field_access` handler checks whether the left-hand side is a pointer type (direct, via type alias, or via call return type) and stamps `pointer_access = "true"` for the emitter to use `->` instead of `.`.
- **Float literal stamping:** The `expr.assign` handler propagates the target type to float literals in the RHS for correct overload resolution.
- **Variadic call detection:** The `expr.call` handler checks for a `__va:` marker symbol to stamp variadic calls.


## Emitters Block

The `emitters {}` block produces output code. Each `on` handler fires when a node of the matching kind is walked during code generation. There are two kinds of emitter handlers: **statement emitters** produce output lines via `emitLine()`, and **expression emitters** produce expression strings via `emit` that can be composed recursively through `exprToString()`.

### Statement Emitters

Statement emitters call `emitLine()` to write indented lines to the output:

```mld
emitters {
  on stmt.if {
    let cond = exprToString(getChild(node, 0));
    emitLine("if (" + cond + ") {");
    indentIn();
    emitNode(getChild(node, 1));  // then branch
    indentOut();
    if child_count() > 2 {
      emitLine("} else {");
      indentIn();
      emitNode(getChild(node, 2));  // else branch
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
    let varName = getAttr(node, "for.var");
    let startExpr = exprToString(getChild(node, 0));
    let finishExpr = exprToString(getChild(node, 1));
    let dir = getAttr(node, "for.dir");
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
    // emit body children...
    indentOut();
    emitLine("}");
  }
}
```

### Expression Emitters

Expression emitters use the `emit` keyword to produce string fragments that `exprToString()` captures:

```mld
emitters {
  on expr.binary {
    let lhs = exprToString(getChild(node, 0));
    let rhs = exprToString(getChild(node, 1));
    let op = getAttr(node, "operator");
    if op == "=" { op = "=="; }
    else if op == "<>" { op = "!="; }
    else if op == "div" { op = "/"; }
    else if op == "mod" { op = "%"; }
    else if op == "and" { op = "&&"; }
    else if op == "or" { op = "||"; }
    else if op == "xor" { op = "^"; }
    emit "(" + lhs + " " + op + " " + rhs + ")";
  }

  on expr.assign {
    let lhs = exprToString(getChild(node, 0));
    let rhs = exprToString(getChild(node, 1));
    let op = getAttr(node, "operator");
    if op == ":=" { op = "="; }
    emit lhs + " " + op + " " + rhs;
  }

  on expr.ident   { emit @name; }
  on expr.integer { emit @value; }
  on expr.nil     { emit "nullptr"; }
  on expr.bool    {
    let val = getAttr(node, "value");
    if val == "true" { emit "true"; }
    else { emit "false"; }
  }
  on expr.cstring { emit "\"" + @value + "\""; }
  on expr.wstring { emit "L\"" + @value + "\""; }
  on expr.self    { emit "this"; }
  on expr.parent  { emit "Super"; }
}
```

### Header vs Source Emission

The emitter maintains two output buffers: source (default) and header. Use `emitLine(text, "header")` to write to the header file:

```mld
emitters {
  on stmt.module {
    emitLine("#include <cstdint>", "header");
    emitLine("#include <string>", "header");
    // ... header includes
    emitLine("#include <cstdint>");
    emitLine("#include <string>");
    // ... source includes
  }
}
```

### Directive Emitters

Directive emitters wire source-level directives to pipeline builtins:

```mld
emitters {
  on stmt.directive_optimize    { setOptimize(getAttr(node, "value")); }
  on stmt.directive_subsystem   { setSubsystem(getAttr(node, "value")); }
  on stmt.directive_target      { setPlatform(getAttr(node, "value")); }
  on stmt.directive_exeicon     { setExeIcon(getAttr(node, "value")); }
  on stmt.directive_copydll     { addCopyDLL(getAttr(node, "value")); }
  on stmt.directive_linklibrary { addLinkLibrary(getAttr(node, "value")); }
  on stmt.directive_breakpoint  {
    addBreakpoint(getNodeFile(node), getNodeLine(node));
  }
}
```

### Node Walking

| Function | Description |
|----------|-------------|
| `emitNode(node)` | Dispatch the emitter handler for a node |
| `emitChildren(node)` | Emit all children of a node sequentially |
| `exprToString(node)` | Render an expression node tree to a string |

`exprToString` behavior: if an emitter handler exists for the node kind, it runs in string-capture mode (intercepting `emit` calls). Otherwise, if the node has 2 children and an `@operator` attribute, it produces `left op right`. Otherwise, falls back to the engine's default.

### Myra Emitter Architecture

Myra's emitters implement a multi-pass emission strategy within the module handler:

1. **Preprocessor directives and C++ raw statements** are emitted first (before any namespace)
2. **Import includes** are emitted next (`#include "module.h"`)
3. For lib modules, a **namespace wrapper** is opened
4. **Declarations** (types, constants, variables, routines) are emitted
5. **Test block functions** are emitted (must precede main for forward declaration)
6. **Module body** (main) is emitted last

The `stmt.exported` handler emits forward declarations to the header file for lib modules, including routine signatures, extern variable declarations, and type/const definitions.


## The Imperative Language

The `.mld` language is Turing complete. Every handler body has access to variables, unbounded loops, conditionals, recursion, and string/arithmetic operations as first-class constructs.

### Variables and Assignment

```mld
let x = 42;
let name = "hello";
let ok = true;
let n = createNode("my_node");
x = x + 1;
name = upper(name);
```

Variables are block-scoped. The interpreter uses a stack of scope frames.

### Control Flow

**if / else if / else**

```mld
if x > 10 {
  emitLine("big");
} else if x > 5 {
  emitLine("medium");
} else {
  emitLine("small");
}
```

**while**

```mld
let i = 0;
while i < child_count() {
  emitNode(getChild(node, i));
  i = i + 1;
}
```

**for**

```mld
for i in child_count() {
  emitNode(getChild(node, i));
}
```

`for X in N` iterates from 0 to N-1. The loop variable is automatically declared.

**return**

```mld
routine max(a: int, b: int) -> int {
  if a > b { return a; }
  return b;
}
```

**match**

```mld
match getAttr(node, "kind") {
  "exe" => {
    setBuildMode("exe");
  }
  "dll" | "lib" => {
    setBuildMode(getAttr(node, "kind"));
  }
  else => {
    error "unknown module kind";
  }
}
```

**guard**

```mld
guard getAttr(node, "has_init") == "true" {
  emit " = ";
  emitNode(getChild(node, 0));
}
```

### Expressions and Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not` |
| String concatenation | `+` (overloaded) |

### Operator Precedence (MLD Expressions)

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (highest) | `not`, `-` (unary) | Right |
| 2 | `*`, `/`, `%` | Left |
| 3 | `+`, `-` | Left |
| 4 | `==`, `!=`, `<`, `>`, `<=`, `>=` | Left |
| 5 | `and` | Left (short-circuit) |
| 6 (lowest) | `or` | Left (short-circuit) |

### Attribute Access

`@name` reads/writes attributes on the current context node:

```mld
grammar {
  rule stmt.module {
    expect keyword.module;
    consume identifier -> @name;  // sets @name on result node
  }
}

emitters {
  on stmt.module {
    emitLine("// Module: " + @name);  // reads @name from current node
  }
}
```

### String Interpolation

Two forms of inline interpolation in double-quoted strings:

- `{@attr}` reads an attribute from the current node
- `{expr}` evaluates an expression

Use `\{` to emit a literal `{`.

### Triple-Quoted Strings

`"""` for multi-line text. Leading whitespace is trimmed to minimum common indent. No escape processing.

### Try/Recover

Graceful error handling. If any statement in `try` fails, execution jumps to `recover`:

```mld
try {
  let lhs = exprToString(getChild(node, 0));
  emit lhs;
} recover {
  error "malformed expression";
  emit "/* ERROR */";
}
```

### Implicit Variables

| Variable | Context | Description |
|----------|---------|-------------|
| `node` | All handlers | Current AST node |
| `true`, `false` | All | Boolean literals |
| `nil` | All | Null value |

### Diagnostics

| Builtin | Description |
|---------|-------------|
| `error "message";` | Compilation error |
| `warning "message";` | Warning |
| `hint "message";` | Suggestion |
| `note "message";` | Informational |
| `info "message";` | General info |

All diagnostics carry source location from the current node. Interpolation supported.


## Routines and Constants

### User-Defined Routines

Routines are defined at the top level, outside any block. They are callable from any grammar, semantic, or emitter handler.

```mld
routine resolveType(typeText: string) -> string {
  if typeText == "int8" { return "int8_t"; }
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

**Syntax:** `routine name(param1: type, param2: type) -> returnType { ... }`

**Parameter types:** `string`, `int`, `bool`, `node`, `list`.

When called from an emitter context, routines inherit the emitter's output builder and can call `emitLine()`, `indentIn()`, etc.

### Myra Helper Routines

Myra defines several helper routines in `myra_helpers.mld`:

| Routine | Returns | Purpose |
|---------|---------|---------|
| `resolveType(typeText)` | string | Map Myra type names to C++ types, including compound types |
| `emitBlock(blk)` | - | Walk children of a node and emit each |
| `buildRoutineSig(nd, rname, retType)` | string | Build C++ function signature from routine declaration |
| `parseCallArgs(nd)` | - | Parse `( [expr, ...] )` argument list |
| `isDirectiveToken()` | bool | Check if current token is a directive |
| `collectTypeText()` | string | Collect compound type text from token stream |
| `emitArrayVarDecl(name, type)` | - | Emit array variable declaration |
| `emitPointerVarDecl(name, type)` | - | Emit pointer variable declaration |
| `emitRoutineForwardDecl(ch)` | - | Emit forward declaration to header |
| `emitExportedVarForwardDecls(blk)` | - | Emit extern declarations to header |
| `emitExportedTypeToHeader(td)` | - | Emit type declaration to header |
| `emitExportedConstToHeader(cd)` | - | Emit const declaration to header |
| `stampFloatLiterals(n, targetType)` | - | Recursively stamp float literals with resolved type |

### Constants

```mld
const {
  MAX_PARAMS = 255;
  DEFAULT_ALIGN = 8;
  ENABLE_OVERLOADS = true;
}
```

### Enums

```mld
enum BuildMode { exe, lib, dll }
```

Members are global constants with sequential integer values starting from 0.


## Fragments, Imports, and Includes

### Fragments

A `fragment` defines a reusable block of top-level declarations that can be expanded with `include`. Fragments are organizational tools within the same file.

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

### Imports

Imports load external `.mld` files for sharing definitions across multiple files. Myra uses this to split its definition across six files:

```mld
import "myra_tokens.mld";
import "myra_helpers.mld";
import "myra_grammar.mld";
import "myra_semantics.mld";
import "myra_emitters.mld";
```

Paths are resolved relative to the importing file. Each path is processed only once.

### Top-Level Guards

Guards conditionally include or exclude features:

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



## Built-in Functions Reference

### Common: All Contexts

**Node operations:**

| Function | Returns | Description |
|----------|---------|-------------|
| `nodeKind(node)` | string | Get the kind string of a node |
| `getAttr(node, key)` | string | Read a string attribute from a node |
| `getAttr(key)` | string | Read attribute from current context node |
| `setAttr(node, key, value)` | - | Write an attribute onto a node |
| `setAttr(key, value)` | - | Write attribute on current context node |
| `has_attr(name)` | bool | True if current node has this attribute |
| `getChild(node, index)` | node | Get child node at zero-based index |
| `childCount(node)` | int | Number of children of specified node |
| `child_count()` | int | Number of children of current context node |
| `child_count(node)` | int | Number of children of specified node |
| `createNode("kind")` | node | Create new AST node with given kind |
| `addChild(parent, child)` | - | Append child to parent node |
| `getResultNode()` | node | Get the result node (grammar context) |

**String operations:**

| Function | Returns | Description |
|----------|---------|-------------|
| `concat(a, b, ...)` | string | Concatenate strings (also: `a + b`) |
| `upper(s)` | string | Convert to upper case |
| `lower(s)` | string | Convert to lower case |
| `trim(s)` | string | Strip leading/trailing whitespace |
| `replace(s, find, repl)` | string | Replace all occurrences |
| `len(s)` | int | String length |
| `substr(s, start, len)` | string | Substring (0-based start) |
| `startsWith(s, prefix)` | bool | True if s starts with prefix |
| `endsWith(s, suffix)` | bool | True if s ends with suffix |
| `contains(s, sub)` | bool | True if s contains sub |
| `intToStr(n)` | string | Integer to string |
| `strToInt(s)` | int | String to integer (0 on failure) |

### Parse Context

Available inside `grammar { rule ... { } }` bodies:

| Function | Returns | Description |
|----------|---------|-------------|
| `checkToken("kind")` | bool | True if current token is `kind` (no consume) |
| `matchToken("kind")` | bool | If current is `kind`, consume and return true |
| `advance()` | string | Consume current token, return its text |
| `requireToken("kind")` | - | Assert current is `kind` and consume (error if not) |
| `currentText()` | string | Text of current token |
| `currentKind()` | string | Kind string of current token |
| `peekKind()` | string | Kind of next token (1-token lookahead) |
| `peekKindAt(N)` | string | Kind of token N positions ahead |
| `parseExpr(power)` | node | Parse expression with minimum binding power |
| `parseExprFrom(node, power)` | node | Parse expression starting from an existing node |
| `parseStmt()` | node | Parse next statement |
| `collectRaw()` | string | Collect raw text until balanced delimiters |

### Semantic Context

Available inside `semantics { on ... { } }` handlers:

| Function | Returns | Description |
|----------|---------|-------------|
| `symbolExistsWithPrefix(prefix)` | bool | True if any symbol starts with prefix |
| `demoteCLinkageForPrefix(prefix)` | int | Strip `"C"` linkage from matching symbols |
| `lookupSymbolType(name)` | string | Look up a symbol's type string |
| `compileModule(name)` | bool | Trigger compilation of module `name` |
| `setModuleExtension(ext)` | - | Set file extension for module resolution |
| `addModulePath(path)` | - | Add directory to module search path |

Plus declarative constructs: `declare`, `lookup`, `scope`, `visit`.

### Emit Context: Low-Level Output

| Function | Description |
|----------|-------------|
| `emitLine(text)` | Emit indented line with newline to source file |
| `emitLine(text, "header")` | Emit to header file instead |
| `emit text;` | Emit text verbatim (expression emitter) |
| `emit @attr;` | Emit attribute value from current node |
| `indentIn()` | Increase indentation level |
| `indentOut()` | Decrease indentation level |

### Emit Context: Function Builder

| Function | C++ Output |
|----------|------------|
| `func(name, returnType)` | Opens: `returnType name(` ... `) {` |
| `param(name, type)` | Adds parameter to current function |
| `endFunc()` | Closes: `}` |

### Emit Context: Declarations and Statements

| Function | C++ Output |
|----------|------------|
| `declVar(name, type)` | `type name;` |
| `declVar(name, type, init)` | `type name = init;` |
| `assign(lhs, rhs)` | `lhs = rhs;` |
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

### Emit Context: Type Resolution

| Function | Returns | Description |
|----------|---------|-------------|
| `typeTextToKind(text)` | string | Resolve type text to type kind |
| `typeToIR(kind)` | string | Resolve type kind to C++ type |
| `exprToString(node)` | string | Render expression node tree to string |

### Emit Context: Node Walking

| Function | Description |
|----------|-------------|
| `emitNode(node)` | Dispatch emitter handler for a node |
| `emitChildren(node)` | Emit all children sequentially |

### Pipeline Configuration Builtins

**Build configuration:**

| Function | Values | Description |
|----------|--------|-------------|
| `setPlatform(p)` | `"win64"`, `"linux64"` | Target platform |
| `setBuildMode(m)` | `"exe"`, `"lib"`, `"dll"` | Output type |
| `setOptimize(o)` | `"debug"`, `"releasesafe"`, `"releasefast"`, `"releasesmall"` | Optimization level |
| `setSubsystem(s)` | `"console"`, `"gui"` | Windows subsystem |

**Version info:**

| Function | Description |
|----------|-------------|
| `setAddVerInfo(v)` | Enable version resource |
| `setExeIcon(path)` | Embed icon into executable |
| `setVersionMajor(v)` | Version major number |
| `setVersionMinor(v)` | Version minor number |
| `setVersionPatch(v)` | Version patch number |
| `setProductName(v)` | Product name |
| `setDescription(v)` | File description |
| `setFilename(v)` | Original filename |
| `setCompanyName(v)` | Company name |
| `setCopyright(v)` | Copyright string |

**Paths and libraries:**

| Function | Description |
|----------|-------------|
| `addIncludePath(path)` | Add C++ include search path |
| `addLibraryPath(path)` | Add library search path |
| `addLinkLibrary(name)` | Add library to link |
| `addCopyDLL(path)` | Copy DLL to output directory |
| `addSourceFile(path)` | Add additional source file |
| `setModuleExtension(ext)` | Set file extension for module resolution |
| `addModulePath(path)` | Add module search directory |

**Build state management:**

| Function | Description |
|----------|-------------|
| `pushBuildState()` | Save current build configuration onto stack |
| `popBuildState()` | Restore most recently pushed configuration |

**Conditional compilation:**

| Function | Returns | Description |
|----------|---------|-------------|
| `setDefine(name)` | - | Define a symbol |
| `setDefine(name, value)` | - | Define a symbol with value |
| `removeDefine(name)` | - | Remove a defined symbol |
| `hasDefine(name)` | bool | True if symbol is defined |

**Debug:**

| Function | Description |
|----------|-------------|
| `addBreakpoint(file, line)` | Add a breakpoint entry |
| `getNodeFile(node)` | Get source file of a node |
| `getNodeLine(node)` | Get source line of a node |


## Formal Grammar (EBNF)

This section provides the complete EBNF grammar for the MLD meta-language. Brackets `[` `]` denote optionality, braces `{` `}` denote repetition (zero or more), parentheses `(` `)` group alternatives, and `|` separates alternatives.

### Lexical Elements

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

### Reserved Words

The meta-language is **case-sensitive** for all keywords and identifiers.

| Category | Words |
|----------|-------|
| Structure | `language`, `version`, `tokens`, `grammar`, `semantics`, `emitters`, `section` |
| Rules | `rule`, `on`, `token`, `optional`, `expect`, `consume`, `parse`, `many`, `until`, `sync` |
| Declarations | `let`, `const`, `routine`, `fragment`, `types`, `import`, `include` |
| Control flow | `if`, `else`, `while`, `for`, `in`, `break`, `continue`, `return`, `match`, `guard`, `try`, `recover` |
| Semantics | `declare`, `lookup`, `scope`, `visit`, `children`, `child`, `parent`, `as`, `where`, `pass` |
| Emission | `emit`, `to`, `indent`, `before`, `after`, `node` |
| Diagnostics | `error`, `warning`, `hint`, `note`, `info` |
| Literals | `true`, `false`, `nil` |
| Logic | `and`, `or`, `not` |

### Built-in Types

```
string   - text values
int      - integer values
bool     - boolean values
node     - AST node reference
list     - ordered collection
```

### Operators and Delimiters

```
+    -    *    /    %
==   !=   <    >    <=   >=
=    ;    ,    .    :    @
(    )    [    ]    {    }
->   =>   |
```

### Top-Level Structure

```ebnf
SourceFile     = LanguageDecl { TopLevelBlock } .
LanguageDecl   = "language" ident "version" string ";" .
TopLevelBlock  = TokenBlock | GrammarBlock | SemanticsBlock
               | EmitterBlock | TypesBlock | ConstBlock
               | EnumDecl | RoutineDecl | FragmentDecl
               | ImportStmt | IncludeStmt | GuardBlock .
```

### Token Declarations

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
CaseSensitiveDecl  = "casesensitive" "=" ( "true" | "false" ) ";" .
StructuralDecl     = ( "terminator" | "block_open" | "block_close" ) "=" TokenKind ";" .
HexPrefixDecl      = "hex_prefix" "=" string ";" .
DirectivePrefixDecl = "directive_prefix" "=" string ";" .
```

### Grammar Rule Declarations

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
TokenRef       = TokenKind | "[" TokenKind { "," TokenKind } "]"
               | "identifier" .
```

### Semantic Handler Declarations

```ebnf
SemanticsBlock = "semantics" "{" { SemanticDecl | PassBlock } "}" .
PassBlock      = "pass" integer string "{" { SemanticDecl } "}" .
SemanticDecl   = "on" NodeKind "{" { SemanticStmt } "}" .
SemanticStmt   = VisitStmt | DeclareStmt | LookupStmt | ScopeBlock
               | HandlerStmt .
VisitStmt      = "visit" VisitTarget ";" .
VisitTarget    = "children" | "@" ident | "child" "[" Expression "]" .
DeclareStmt    = "declare" "@" ident "as" SymbolKind
                 [ "typed" Expression ] [ WhereBlock ] ";" .
SymbolKind     = "variable" | "routine" | "type" | "constant" | "parameter" .
LookupStmt     = "lookup" "@" ident
                 ( "->" "let" ident | "or" "{" { SemanticStmt } "}" ) ";" .
ScopeBlock     = "scope" Expression "{" { SemanticStmt } "}" .
```

### Emitter Handler Declarations

```ebnf
EmitterBlock   = "emitters" "{" { SectionDecl | EmitDecl | BeforeBlock | AfterBlock } "}" .
SectionDecl    = "section" ident [ "indent" string ] ";" .
EmitDecl       = "on" NodeKind "{" { EmitStmt } "}" .
EmitStmt       = EmitToStmt | VisitStmt | IndentBlock | HandlerStmt .
EmitToStmt     = "emit" [ "to" ident ":" ] Expression ";" .
IndentBlock    = "indent" "{" { EmitStmt } "}" .
```

### Expressions

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

### Handler Body Logic

```ebnf
HandlerStmt    = LetStmt | AssignStmt | IfStmt | WhileStmt | ForStmt
               | MatchStmt | GuardStmt | BreakStmt | ContinueStmt
               | ReturnStmt | TryRecover
               | DiagStmt | FuncCallStmt | SetAttrStmt .
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

### Type Declarations

```ebnf
TypesBlock     = "types" "{" { TypeDecl | IncludeStmt | GuardBlock } "}" .
TypeDecl       = TypeKeywordDecl | TypeMappingDecl | LiteralTypeDecl
               | TypeCompatDecl | DeclKindDecl | CallKindDecl
               | CallNameAttrDecl .
TypeKeywordDecl    = "type" ident "=" string ";" .
TypeMappingDecl    = "map" string "->" string ";" .
LiteralTypeDecl    = "literal" string "=" string ";" .
TypeCompatDecl     = "compatible" string "," string [ "->" string ] ";" .
DeclKindDecl       = "decl_kind" string ";" .
CallKindDecl       = "call_kind" string ";" .
CallNameAttrDecl   = "call_name_attr" "=" string ";" .
```

### Routines, Constants, Fragments, Imports

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

### Token Kind Naming Conventions

| Category | Examples |
|----------|---------|
| `keyword.*` | `keyword.if`, `keyword.while`, `keyword.var` |
| `op.*` | `op.plus`, `op.assign`, `op.neq` |
| `delimiter.*` | `delimiter.lparen`, `delimiter.semicolon` |
| `literal.*` | `literal.integer`, `literal.float`, `literal.hex` |
| `string.*` | `string.cstring`, `string.wstring` |
| `comment.*` | `comment.line`, `comment.block_open` |
| `directive.*` | `directive.define`, `directive.optimize` |
| `type.*` | `type.int32`, `type.string`, `type.boolean` |
| `identifier` | (bare, no dot) |
| `eof` | (bare, no dot) |

### Node Kind Naming Conventions

| Category | Examples |
|----------|---------|
| `program.*` | `program.root` |
| `stmt.*` | `stmt.if`, `stmt.var_decl`, `stmt.routine_decl`, `stmt.module` |
| `expr.*` | `expr.ident`, `expr.call`, `expr.binary`, `expr.grouped` |

The engine uses `program.root` as the root node kind. All other node kinds are defined by the `.mld` file.
