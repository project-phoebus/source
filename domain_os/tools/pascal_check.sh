#!/bin/sh
# pascal_check.sh - run `dpc --check-only` over the Domain Pascal tree's
# module files.
#
# Usage (from domain_os/): tools/pascal_check.sh [module.pas ...]
#   default: every module file under domain_os/: <subsystem>/<subsystem>.pas
#   and the subsystem's other module files (below).
#
# Copies every .pas file under domain_os/ to ../tmp/pascal_check/tree and
# works on that copy, which it changes in these ways:
#   - %include lines for fragments that do not exist yet are dropped,
#     together with their continuation comments, so that a module checks
#     while its translation is incomplete;
#   - a `forward' heading of a routine whose fragment does not exist yet
#     (a heading preceded by a line `{ body: <fragment> }') becomes an
#     `extern' one when <fragment> is missing: the body is not written
#     yet, dpc rightly reports a forward routine that is never defined,
#     and the routines already written call it;
#   - errors that are known dpc gaps are let through (see known_gaps
#     below), as long as nothing else is reported.
# The source tree is never modified.  Exit status 0 = every module checks.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)               # domain_os/
# the Makefile's DPC (the compiler repo's stable build, beside this
# repository's checkout); DPC overrides it
dpc=${DPC:-$(cd "$here" && printf 'p:\n\t@echo $(DPC)\n' | make -s -f Makefile -f - p)}
# the Makefile's DPC_FLAGS (-config <sau>, and -cpu on the MC68020-class
# SAUs) for TARGET_SAU (default the Makefile's), so the check compiles what
# the build compiles; DPC_FLAGS overrides them
dpc_flags=${DPC_FLAGS:-$(cd "$here" && printf 'p:\n\t@echo $(DPC_FLAGS)\n' | make -s -f Makefile -f - ${TARGET_SAU:+TARGET_SAU=$TARGET_SAU} p)}
work=$here/../tmp/pascal_check
# A module file is <subsystem>/<subsystem>.pas, and any other .pas of the
# subsystem (not an insert file) with a module heading, a line starting
# `module <name>' followed by `,' or `;' (any case): the module file of a
# second map module (pbu/ec2_pbu.pas).  The heading's form, not the bare
# word, so that a fragment's comment line that begins with "module ..."
# does not make it a module.
[ $# -gt 0 ] || set -- $(cd "$here" && for d in */; do d=${d%/}; [ -f "$d/$d.pas" ] && echo "$d/$d.pas"; for f in "$d"/*.pas; do [ "${f%.ins.pas}" = "$f" ] && [ "$f" != "$d/$d.pas" ] && [ -f "$f" ] && grep -qiE '^module[[:space:]]+[a-z_$][a-z0-9_$]*[[:space:]]*[,;]' "$f" && echo "$f"; done; done)
rm -rf "$work/tree"; mkdir -p "$work/tree"
cd "$here"; find . -name '*.pas' | cpio -pdm "$work/tree" 2>/dev/null
cd "$work/tree"
python3 - "$@" <<'PY'
import re, os, sys, glob
for m in sys.argv[1:]:
    out, skipping, fwd = [], False, False
    for line in open(m):
        if fwd:
            # the heading right after the `body:' line, up to its `forward'
            assert line.strip(), (m, 'no forward heading after body: line')
            if re.search(r'\bforward\b', line, re.I):
                line = re.sub(r'\bforward\b', 'extern', line, flags=re.I)
                fwd = False
            out.append(line)
            continue
        mb = re.match(r"\s*\{ body: (\S+) \}\s*$", line)
        if mb and not os.path.exists(mb.group(1)):
            fwd = True
            continue
        if skipping:
            if '}' in line: skipping = False
            continue
        mm = re.match(r"\s*%include '([^']+)'", line)
        if mm and not os.path.exists(mm.group(1)):
            skipping = '{' in line and '}' not in line
            continue
        out.append(line)
    assert not fwd, (m, 'no forward heading after body: line')
    open(m, 'w').write(''.join(out))
PY
# Known dpc gaps that dpc reports as errors but that need no rewrite of
# the copy: an error whose message matches one of these is printed but
# does not fail the check.  One pattern per line
# (grep -F), and no blank line.  An empty list lets nothing through (see
# the test below), because an empty grep pattern would match every
# error.
# The list is empty: dpc reports no error that needs it.
known_gaps=""
rc=0
for m in "$@"; do
  echo "== $m"
  out=$("$dpc" $dpc_flags --check-only "$m" 2>&1) && st=0 || st=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  if [ $st -ne 0 ]; then
    if [ -n "$known_gaps" ]; then
      other=$(printf '%s\n' "$out" | grep ': error: ' | grep -v -F "$known_gaps" || true)
    else
      other=$(printf '%s\n' "$out" | grep ': error: ' || true)
    fi
    if [ -n "$other" ] || ! printf '%s\n' "$out" | grep -q ': error: '; then
      rc=1
    else
      echo "   (only known dpc gaps: not a failure)"
    fi
  fi
done
exit $rc
