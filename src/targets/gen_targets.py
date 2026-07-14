#!/usr/bin/env python3
"""
gen_targets.py - Generate Myra.Build.Targets.pas from `zig targets` output.

The `zig targets` command emits Zig Object Notation (ZON), not JSON. Rather
than depend on a third-party ZON library or hardcode byte offsets, this script
navigates the ZON structure itself: it walks the outermost container, finds the
top-level `.arch`, `.os`, and `.abi` sections (string- and brace-aware, so it
is immune to reordering, indentation, and added sections), and extracts their
quoted string members.

If a required section is missing or empty, it fails loudly rather than emitting
a half-empty unit - so a future format change is obvious, not silent.

Output is TWO generated artifacts, both derived from the same dump so they
cannot drift:
  1. A Delphi unit: header.txt verbatim, then a constants unit declaring every
     arch/os/abi tag as a string constant.
  2. An MLD langdef file: the same tags as MLD constants, plus a generated
     validator routine per section (isValidArch / isValidOS / isValidAbi).
     Reusable logic that consumes them lives in myra_utils.mld, not there.

Usage:
  python gen_targets.py [dump] [header] [output] [mld_output]

Defaults (relative to this script's folder):
  dump       = ./targets.txt
  header     = ./header.txt
  output     = ../Myra.Build.Targets.pas
  mld_output = ../../bin/res/language/myra_targets.mld
"""
import os
import re
import sys

UNIT_NAME = 'Myra.Build.Targets'

# (zon section name, constant prefix, section title comment)
SECTIONS = [
    ('arch', 'ARCH', 'Architectures'),
    ('os',   'OS',   'Operating Systems'),
    ('abi',  'ABI',  'ABIs'),
]

# zon section name -> generated MLD validator routine name (myra_targets.mld)
VALIDATORS = {
    'arch': 'isValidArch',
    'os':   'isValidOS',
    'abi':  'isValidAbi',
}


def capture_block(text, start):
    # Given an index just past an opening '{', return the substring up to the
    # matching close '}', skipping over string literals.
    i = start
    n = len(text)
    depth = 1
    in_str = False
    esc = False
    while i < n:
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    return text[start:i]
        i += 1
    raise SystemExit("ERROR: unterminated block (no matching '}').")


def find_section(text, name):
    # Walk the ZON string/brace-aware and return the content block of the
    # top-level `.<name> = .{ ... }`. Top-level = a direct child of the
    # single outermost container, i.e. found while brace depth == 1.
    key = '.' + name
    i = 0
    n = len(text)
    depth = 0
    in_str = False
    esc = False
    while i < n:
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == '{':
            depth += 1
            i += 1
            continue
        if c == '}':
            depth -= 1
            i += 1
            continue
        if depth == 1 and text.startswith(key, i):
            after = text[i + len(key):]
            m = re.match(r'\s*=\s*\.\{', after)
            if m:
                start = i + len(key) + m.end()
                return capture_block(text, start)
        i += 1
    raise SystemExit(
        "ERROR: top-level section '." + name + "' not found. "
        "The `zig targets` output format may have changed.")


def extract_tags(block):
    # Ordered, de-duplicated list of double-quoted tokens in a section block.
    tags = []
    seen = set()
    for m in re.finditer(r'"([^"\\]*)"', block):
        tag = m.group(1)
        if tag and tag not in seen:
            seen.add(tag)
            tags.append(tag)
    return tags


def to_ident(prefix, tag):
    # PREFIX_TAG with any non-identifier character replaced by '_', uppercased.
    body = re.sub(r'[^A-Za-z0-9_]', '_', tag).upper()
    return prefix + '_' + body


def write_mld(path, sections):
    # Emit the langdef counterpart: the same tags as MLD constants, plus a
    # generated validator routine per section. The routine bodies ARE the tag
    # data, so they must be generated - a hand-written chain would drift.
    lines = []
    lines.append('// ' + ('=' * 73))
    lines.append('//  myra_targets.mld -- Supported target architectures, OSes, and ABIs.')
    lines.append('//')
    lines.append('//  Myra(TM) - Pascal. Refined.')
    lines.append('//  Copyright (c) 2025-present tinyBigGAMES(TM) LLC')
    lines.append('//  https://myralang.org')
    lines.append('//')
    lines.append('//  Every arch/os/abi tag the bundled Zig/Clang toolchain accepts, exposed to')
    lines.append('//  the langdef as constants plus a validator routine per section. Reusable')
    lines.append('//  logic that CONSUMES these lives in myra_utils.mld, not here.')
    lines.append('//')
    lines.append('//  GENERATED FILE - DO NOT EDIT BY HAND.')
    lines.append('//  Regenerate with: python src\\targets\\gen_targets.py')
    lines.append('// ' + ('=' * 73))
    lines.append('')

    # Constants: one const block covering every section.
    lines.append('const {')
    for idx, (name, title, consts) in enumerate(sections):
        if idx > 0:
            lines.append('')
        width = max(len(ident) for ident, _ in consts)
        lines.append('  // ' + title)
        for ident, tag in consts:
            lines.append('  ' + ident.ljust(width) + ' = "' + tag + '";')
    lines.append('}')
    lines.append('')

    # Validator routines: one per section, generated from the same tag list.
    for name, title, consts in sections:
        routine = VALIDATORS[name]
        lines.append('// True if the tag is one the toolchain accepts. Section: ' +
                     title + '.')
        lines.append('routine ' + routine + '(s: string) -> bool {')
        for ident, tag in consts:
            lines.append('  if s == "' + tag + '" { return true; }')
        lines.append('  return false;')
        lines.append('}')
        lines.append('')

    body = '\n'.join(lines)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    # MLD source: plain UTF-8, no BOM, CRLF to match the other langdef files.
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(body)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    dump = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'targets.txt')
    header = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, 'header.txt')
    output = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, '..', 'Myra.Build.Targets.pas')
    output = os.path.abspath(output)
    mld_output = sys.argv[4] if len(sys.argv) > 4 else os.path.join(
        here, '..', '..', 'bin', 'res', 'language', 'myra_targets.mld')
    mld_output = os.path.abspath(mld_output)

    if not os.path.isfile(dump):
        raise SystemExit("ERROR: dump not found: " + dump)
    if not os.path.isfile(header):
        raise SystemExit("ERROR: header not found: " + header)

    with open(dump, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()
    with open(header, 'r', encoding='utf-8-sig') as f:
        header_text = f.read().rstrip('\n')

    # Extract each section, failing loudly on missing/empty, and build the
    # constant list while checking for identifier collisions.
    sections = []
    idents = {}
    for name, prefix, title in SECTIONS:
        block = find_section(text, name)
        tags = extract_tags(block)
        if not tags:
            raise SystemExit("ERROR: section '." + name + "' is empty.")
        consts = []
        for tag in tags:
            ident = to_ident(prefix, tag)
            if ident in idents:
                raise SystemExit(
                    "ERROR: duplicate constant '" + ident + "' from tags '" +
                    idents[ident] + "' and '" + tag + "'.")
            idents[ident] = tag
            consts.append((ident, tag))
        sections.append((name, title, consts))

    # Emit the unit: header verbatim, then the constants unit.
    lines = []
    lines.append(header_text)
    lines.append('')
    lines.append('unit ' + UNIT_NAME + ';')
    lines.append('')
    lines.append('interface')
    lines.append('')
    lines.append('const')
    for idx, (name, title, consts) in enumerate(sections):
        if idx > 0:
            lines.append('')
        width = max(len(ident) for ident, _ in consts)
        lines.append('  { ' + title + ' }')
        for ident, tag in consts:
            lines.append('  ' + ident.ljust(width) + " = '" + tag + "';")
    lines.append('')
    lines.append('implementation')
    lines.append('')
    lines.append('end.')
    body = '\n'.join(lines) + '\n'

    os.makedirs(os.path.dirname(output), exist_ok=True)
    # Delphi source: UTF-8 with BOM, CRLF line endings.
    with open(output, 'w', encoding='utf-8-sig', newline='\r\n') as f:
        f.write(body)

    write_mld(mld_output, sections)

    total = 0
    print('DONE: ' + output)
    print('DONE: ' + mld_output)
    for name, title, consts in sections:
        total += len(consts)
        print('  ' + title + ': ' + str(len(consts)))
    print('  total constants: ' + str(total))


if __name__ == '__main__':
    main()
