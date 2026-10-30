#!/usr/bin/env python3
"""pascal_modules.py - list the Domain Pascal tree's module files.

    tools/pascal_modules.py            (from domain_os/)

Prints one path per line: every <subsystem>/<subsystem>.pas, and every other
.pas of a subsystem (not an insert file) whose text has a module heading, a
line starting `module <name>' followed by `,' or `;' (any case): the module
file of a second map module (pbu/ec2_pbu.pas).  The same rule as
tools/pascal_check.sh; the Makefile compiles each of these with dpc.
"""

import glob
import os
import re
import sys

HEADING = re.compile(r'^module\s+[a-z_$][a-z0-9_$]*\s*[,;]', re.I | re.M)


def modules(root='.'):
    out = []
    for d in sorted(e for e in os.listdir(root)
                    if os.path.isdir(os.path.join(root, e))):
        main = '%s/%s.pas' % (d, d)
        if os.path.isfile(os.path.join(root, main)):
            out.append(main)
        for f in sorted(glob.glob(os.path.join(root, d, '*.pas'))):
            rel = os.path.relpath(f, root)
            if rel.endswith('.ins.pas') or rel == main:
                continue
            with open(f, encoding='latin-1') as fh:
                if HEADING.search(fh.read()):
                    out.append(rel)
    return out


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    for m in modules(root):
        print(m)
