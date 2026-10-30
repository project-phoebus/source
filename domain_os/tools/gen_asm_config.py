#!/usr/bin/env python3
"""tools/gen_asm_config.py - base/config.ins.pas's parts for the assembler.

    gen_asm_config.py --sau sau5 [-o build/sau5/base/config.inc]

The hand assembly that two or more SAUs share (<subsystem>/m68k/*.s) tests
the same parts the Pascal does (`%if mt_driver %then'), as gas conditionals:

    .include "base/config.inc"
    .if mt_driver
    ...
    .endif

This script evaluates base/config.ins.pas for one SAU the way dpc does with
`-config <sau>' and writes one `.set <name>, 1' or `.set <name>, 0' line per
`%var' name, the SAU variables included.  The Makefile writes the result to
$(BUILD_DIR)/base/config.inc and assembles with -I $(BUILD_DIR), so the
.include line names the file it was made from.

Only the directives config.ins.pas uses are understood: `%var NAMES',
`%if NAME %then', `%if not %config %then', `%enable NAMES;', `%error(..)',
`%endif', and `{ .. }' comments.  Anything else stops the script, so a
change to config.ins.pas cannot be silently mistranslated.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, 'base', 'config.ins.pas')


def evaluate(text, sau):
    text = re.sub(r'\{[^}]*\}', ' ', text)          # comments
    names = []                                       # in %var order
    value = {}
    stack = []                                       # one bool per open %if
    for lineno, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line:
            continue

        def fail(why):
            sys.exit('%s:%d: %s: %s' % (CONFIG, lineno, why, line))

        active = all(stack)
        m = re.fullmatch(r'%var\s+(.*)', line)
        if m:
            for n in m.group(1).split():
                if n in value:
                    fail('%var of a name twice')
                names.append(n)
                value[n] = n == sau
            continue
        m = re.fullmatch(r'%if\s+(not\s+)?(%?\w+)\s+%then', line)
        if m:
            neg, n = m.groups()
            if n == '%config':
                v = True
            elif n in value:
                v = value[n]
            else:
                fail('%if of an undeclared name')
            stack.append(v != bool(neg))
            continue
        if line == '%endif':
            if not stack:
                fail('%endif without %if')
            stack.pop()
            continue
        m = re.fullmatch(r'%enable\s+(.*);', line)
        if m:
            for n in m.group(1).split(','):
                n = n.strip()
                if n not in value:
                    fail('%enable of an undeclared name')
                if active:
                    value[n] = True
            continue
        if line.startswith('%error('):
            if active:
                fail('the configuration stops here')
            continue
        fail('not a directive this script understands')
    if stack:
        sys.exit('%s: %d unclosed %%if' % (CONFIG, len(stack)))
    if sau not in value:
        sys.exit('%s: no %%var %s' % (CONFIG, sau))
    return names, value


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sau', required=True, help='e.g. sau5 (TARGET_SAU)')
    ap.add_argument('-o', dest='out', help='output file (default stdout)')
    a = ap.parse_args()
    with open(CONFIG, encoding='latin-1') as f:
        names, value = evaluate(f.read(), a.sau)
    lines = ['| base/config.inc - base/config.ins.pas evaluated for %s' % a.sau,
             '| (written by tools/gen_asm_config.py; do not edit).', '']
    w = max(len(n) for n in names)
    lines += ['        .set    %-*s %d' % (w + 1, n + ',', int(value[n]))
              for n in names]
    out = '\n'.join(lines) + '\n'
    if a.out:
        os.makedirs(os.path.dirname(a.out) or '.', exist_ok=True)
        with open(a.out, 'w') as f:
            f.write(out)
    else:
        sys.stdout.write(out)


if __name__ == '__main__':
    main()
