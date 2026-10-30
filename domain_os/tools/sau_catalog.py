#!/usr/bin/env python3
"""sau_catalog.py - which routines are the same code on every SR10.2 SAU.

    tools/sau_catalog.py [--json OUT] [--only NAME ...] [--saus 2,3,...]
    tools/sau_catalog.py --diff 2,5 --only NAME ...     (one routine, two SAUs)

Reads every SR10.2 `sau<N>/domain_os' image and its link map under
../sr10.2-install/install/ri.apollo.os.v.10.2/ beside the repository (no
Ghidra), takes each map symbol's bytes (from the symbol to the next symbol
or the end of its module segment), and compares the SAUs that have it:

  identical    the same bytes on every SAU that has the symbol;
  equivalent   the same instructions once branch sizes (bra.s / bra.w) and
               addresses are set aside: an absolute or PC-relative operand
               counts as equal when both SAUs' maps resolve it to the same
               symbol + offset, and bsr/jsr, bra/jmp are one form each;
  differs      anything else.  Families say which SAUs agree.

A symbol in one SAU's map only is listed as such.  Prints a summary and,
with --json, writes the per-symbol table (the progress page reads it).
The disassembly (m68k-elf-objdump, per symbol) is cached under
tmp/sau_catalog/ keyed by the bytes.

Map format: fixed columns.  Column 0 is the kind (`D' data, `I' code, ` '
a symbol), columns 1-2 the section number of a section line, columns 3-10
the address (the SAU6..9 maps run an 8-digit address into a 2-digit
section number: `D993C000000'), then the name, then `loaded at' and
`size = ' for a section, `size = ' for a module segment.
"""
import argparse
import bisect
import collections
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import repo_paths  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
INSTALL = repo_paths.beside('sr10.2-install', 'install', 'ri.apollo.os.v.10.2')
SAUS = [2, 3, 4, 5, 6, 7, 8, 9]
OBJDUMP = 'm68k-elf-objdump'
CACHE = os.path.join(ROOT, '..', 'tmp', 'sau_catalog')

SIZE_RE = re.compile(r'size = ([0-9A-F]+)')
LOADED_RE = re.compile(r'loaded at ([0-9A-F]+)')


class SauMap:
    """One SAU's link map: sections, module segments and symbols."""

    def __init__(self, path):
        self.sections = []   # (va, size, loaded_at, name, kind)
        self.segments = []   # (va, size, name, kind): a module's contribution
        self.symbols = {}    # name -> va (first occurrence)
        self.sym_seg = {}    # name -> index into segments
        seg = None
        with open(path, encoding='latin-1') as f:
            for n, line in enumerate(f):
                if n == 0 or len(line) < 12:
                    continue    # build banner
                kind = line[0]
                addr_s = line[3:11].strip()
                if not re.fullmatch(r'[0-9A-F]+', addr_s or 'x'):
                    continue
                va = int(addr_s, 16)
                rest = line[11:].split()
                if not rest:
                    continue
                name = rest[0]
                if kind in 'DI':
                    sm = SIZE_RE.search(line)
                    size = int(sm.group(1), 16) if sm else 0
                    lm = LOADED_RE.search(line)
                    if line[1:3].strip():          # a numbered section
                        if lm and size:
                            self.sections.append((va, size, int(lm.group(1), 16),
                                                  name, kind))
                    else:
                        self.segments.append((va, size, name, kind))
                        seg = len(self.segments) - 1
                elif kind == ' ':
                    if name not in self.symbols:
                        self.symbols[name] = va
                        if seg is not None:
                            self.sym_seg[name] = seg
        self.addrs = sorted(set(self.symbols.values()))
        self.by_addr = collections.defaultdict(list)
        for name, va in self.symbols.items():
            self.by_addr[va].append(name)
        self.seg_order = sorted(range(len(self.segments)),
                                key=lambda k: self.segments[k][0])
        self.seg_starts = [self.segments[k][0] for k in self.seg_order]
        self.seg_max = max((sz for _, sz, _, _ in self.segments), default=0)
        self.trap_base = self.symbols.get('TRAP_PAGE')
        self.data_end = collections.defaultdict(set)
        for sva, size, name, kind in self.segments:
            if kind == 'D':
                self.data_end[name].add(sva + size)

    def extent(self, name):
        """(va, length) of a symbol: to the next symbol or the end of its
        module segment, whichever is first."""
        va = self.symbols[name]
        i = bisect.bisect_right(self.addrs, va)
        end = self.addrs[i] if i < len(self.addrs) else None
        s = self.sym_seg.get(name)
        if s is not None:
            sva, size = self.segments[s][0], self.segments[s][1]
            if sva <= va < sva + size and (end is None or sva + size < end):
                end = sva + size
        return va, (end - va) if end else 0

    def segment_of(self, name):
        s = self.sym_seg.get(name)
        return self.segments[s] if s is not None else None

    def resolve(self, va):
        """`SYM+off' for an address inside a module segment (the nearest
        symbol at or before it in that segment, else the segment's own
        name, `UID_ data' as `[D]UID_+8'), or None."""
        seg = None
        i = bisect.bisect_right(self.seg_starts, va) - 1
        while i >= 0:
            sva, size, name, kind = self.segments[self.seg_order[i]]
            if sva <= va < sva + max(size, 1):
                if seg is None or size < seg[1]:
                    seg = (sva, size, name, kind)
            if self.seg_starts[i] + self.seg_max < va:
                break
            i -= 1
        if seg is None:
            # a numbered section with no module segment over it
            # (FILE_$LOT_DATA, the bss areas): its own name
            sec = None
            for sva, size, _, name, _ in self.sections:
                if sva <= va < sva + size and (sec is None or size < sec[1]):
                    sec = (sva, size, name)
            return '[S]%s+%X' % (sec[2], va - sec[0]) if sec else None
        j = bisect.bisect_right(self.addrs, va) - 1
        if j >= 0 and self.addrs[j] >= seg[0]:
            base = self.addrs[j]
            return '%s+%X' % (sorted(self.by_addr[base])[0], va - base)
        if seg[3] == 'I':
            # unnamed code (a module-local routine): its offset in the
            # segment moves whenever the code before it changes size, so
            # only the segment counts
            return '[I]%s+?' % seg[2]
        return '[%s]%s+%X' % (seg[3], seg[2], va - seg[0])


class SauImage:
    """One SAU's image file, read by virtual address through its map's
    `loaded at' sections (file offset = loaded at - the RFC header's load
    address)."""

    def __init__(self, path, smap):
        with open(path, 'rb') as f:
            self.data = f.read()
        self.load = int.from_bytes(self.data[0:4], 'big')
        self.secs = [(va, size, loaded - self.load)
                     for va, size, loaded, _, _ in smap.sections
                     if loaded >= self.load]

    def read(self, va, n):
        best = None
        for sva, size, off in self.secs:
            if sva <= va and va + n <= sva + size:
                if best is None or size < best[1]:
                    best = (sva, size, off)
        if best is None:
            return None
        o = best[2] + (va - best[0])
        if o < 0 or o + n > len(self.data):
            return None
        return self.data[o:o + n]


# ---------------------------------------------------------------------------
# Disassembly and normalization
# ---------------------------------------------------------------------------

INSN_RE = re.compile(r'^\s*([0-9a-f]+):\t([0-9a-f ]+)\t(\S+)\s*(.*)$')
NUM_RE = re.compile(r'(?<![\w%])(#?)(0x[0-9a-f]+|-?\d+)\b')
# branch mnemonics that take a size suffix in objdump's MIT syntax: bras,
# braw, bral; bsrs ...; bccs ...; dbcc has none
BRANCH_RE = re.compile(r'^(b(?:ra|sr|hi|ls|cc|cs|ne|eq|vc|vs|pl|mi|ge|lt|gt|le|hs|lo))[swlb]$')


def disassemble(data, va):
    """[(va, text)] for the bytes at va, one per instruction."""
    key = hashlib.sha1(data + va.to_bytes(4, 'big')).hexdigest()
    path = os.path.join(CACHE, key[:2], key)
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as t:
        t.write(data)
    try:
        out = subprocess.run([OBJDUMP, '-D', '-b', 'binary', '-m', 'm68k:68040',
                              '--adjust-vma=0x%X' % va, t.name],
                             capture_output=True, text=True).stdout
    finally:
        os.unlink(t.name)
    insns = []
    for line in out.split('\n'):
        m = INSN_RE.match(line)
        if m:
            insns.append((int(m.group(1), 16), m.group(3), m.group(4)))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(insns, f)
    return insns


def normalize(insns, smap, lo, hi, module=None):
    """The instruction stream with addresses resolved through the map and
    branch sizes dropped.  A number that lands on one of the routine's own
    instructions becomes that instruction's index (`L12'), so a local
    branch compares by where it lands, not by its encoding or by the size
    of the code before it; other numbers inside the routine become offsets
    (`.+N').  Alignment fillers (`movea.l A0,A0') and the zero words that
    pad the routine's end are dropped."""
    insns = list(insns)
    while insns and insns[-1][1] == 'orib' and insns[-1][2] == '#0,%d0':
        insns.pop()     # 0000 padding
    # loop-alignment fillers are dropped before the instructions are
    # numbered, so a filler one SAU has and another lacks shifts nothing; a
    # branch to a filler lands on the instruction after it
    real = [x for x in insns if not (x[1] == 'moveal' and x[2] == '%a0,%a0')]
    index = {}
    k = 0
    for va, mn, ops in insns:
        index[va] = k
        if not (mn == 'moveal' and ops == '%a0,%a0'):
            k += 1
    insns = real
    out = []
    for va, mn, ops in insns:
        bm = BRANCH_RE.match(mn)
        if bm:
            mn = bm.group(1)
        if mn in ('jsr', 'bsr'):
            mn = 'call'
        elif mn in ('jmp', 'bra'):
            mn = 'goto'

        def sub(m):
            hashmark, num = m.group(1), m.group(2)
            v = int(num, 16) if num.startswith('0x') else int(num)
            v &= 0xFFFFFFFF
            if lo <= v < hi:
                if v in index:
                    return '%sL%d' % (hashmark, index[v])
                return '%s.+%X' % (hashmark, v - lo)
            # below 0x400: a number (bit-field offsets, scales, the trap
            # page's vectors on the SAUs that keep it at 0), left as printed
            if v < 0x400:
                return m.group(0)
            # the SAU7 and SAU9 move the trap page (the vectors, the PROM's
            # cells at 0x100..): an address in it is its offset, as the
            # other SAUs' absolute word addresses read
            if smap.trap_base and smap.trap_base <= v < smap.trap_base + 0x400:
                return hashmark + '0x%x' % (v - smap.trap_base)
            # the end of the routine's own module's data block (A5 loaded
            # with the end of a 4-byte block, codegen-patterns 4) is that
            # block's, not the start of whatever segment follows it
            if module and v in smap.data_end.get(module, ()):
                return hashmark + '[D]%s+end' % module
            r = smap.resolve(v)
            return hashmark + r if r else m.group(0)
        # a displacement off an address register (%a2@(458), %fp@(8),
        # %sp@(40,%d0:w)) is a number, not an address: leave it alone
        parts = re.split(r'(%(?:a[0-7]|fp|sp)@\([^)]*\))', ops)
        ops = ''.join(p if k % 2 else NUM_RE.sub(sub, p)
                      for k, p in enumerate(parts))
        # absolute and PC-relative forms of one address are one operand
        ops = re.sub(r'%pc@\(([^)]*)\)', r'\1', ops)
        ops = re.sub(r'(\S+?):[wl]\b', r'\1', ops)
        out.append(mn + ' ' + ops)
    return out


# ---------------------------------------------------------------------------
# The catalog
# ---------------------------------------------------------------------------

def load(saus):
    maps, images = {}, {}
    for n in saus:
        d = os.path.join(INSTALL, 'sau%d' % n)
        maps[n] = SauMap(os.path.join(d, 'domain_os.map'))
        images[n] = SauImage(os.path.join(d, 'domain_os'), maps[n])
    return maps, images


def canon(smap, v, module):
    """An address as normalize() writes it, or None for a plain number."""
    if v < 0x400:
        return None
    if smap.trap_base and smap.trap_base <= v < smap.trap_base + 0x400:
        return 'trap+%x' % (v - smap.trap_base)
    if module and v in smap.data_end.get(module, ()):
        return '[D]%s+end' % module
    return smap.resolve(v)


def same_masked(a, b, ma, mb, moda, modb):
    """The bytes equal but for aligned longwords that both maps resolve to
    the same symbol + offset (address cells after the code, absolute
    operands): for routines whose instructions objdump cannot follow."""
    if len(a) != len(b):
        return False
    i = 0
    while i < len(a):
        if a[i:i + 2] == b[i:i + 2]:
            i += 2
            continue
        ok = False
        for j in (i, i - 2):        # the longword may start a word earlier
            if j < 0 or j + 4 > len(a):
                continue
            va = int.from_bytes(a[j:j + 4], 'big')
            vb = int.from_bytes(b[j:j + 4], 'big')
            ca, cb = canon(ma, va, moda), canon(mb, vb, modb)
            if ca and ca == cb:
                i, ok = j + 4, True
                break
        if not ok:
            return False
    return True


def components(nodes, same):
    """Groups of nodes joined by the relation same(x, y)."""
    parent = {n: n for n in nodes}

    def find(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n
    for i, x in enumerate(nodes):
        for y in nodes[i + 1:]:
            if find(x) != find(y) and same(x, y):
                parent[find(y)] = find(x)
    groups = collections.OrderedDict()
    for n in nodes:
        groups.setdefault(find(n), []).append(n)
    return list(groups.values())


def families(keys):
    """{key: [saus]} grouping SAUs whose key is equal."""
    fam = collections.OrderedDict()
    for n, k in keys.items():
        fam.setdefault(k, []).append(n)
    return list(fam.values())


def catalog(maps, images, only=None):
    names = set()
    for m in maps.values():
        names |= set(m.symbols)
    if only:
        names &= set(only)
    rows = []
    for name in sorted(names):
        have = [n for n in maps if name in maps[n].symbols]
        info = {}
        for n in have:
            va, ln = maps[n].extent(name)
            seg = maps[n].segment_of(name)
            data = images[n].read(va, ln) if ln else None
            info[n] = {'va': va, 'len': ln, 'data': data,
                       'segment': seg[2] if seg else None,
                       'kind': seg[3] if seg else None}
        row = {'name': name, 'saus': have,
               'segment': {n: info[n]['segment'] for n in have},
               'kind': {n: info[n]['kind'] for n in have},
               'va': {n: info[n]['va'] for n in have},
               'len': {n: info[n]['len'] for n in have}}
        with_bytes = [n for n in have if info[n]['data']]
        if not with_bytes:
            row['status'] = 'no bytes'          # bss, absolute, empty
        elif len(have) == 1:
            row['status'] = 'one sau'
        else:
            byte_fam = families({n: info[n]['data'] for n in with_bytes})
            if len(byte_fam) == 1 and len(with_bytes) == len(have):
                row['status'] = 'identical'
                row['families'] = byte_fam
            else:
                norm = {}
                for n in with_bytes:
                    va, ln = info[n]['va'], info[n]['len']
                    insns = disassemble(info[n]['data'], va)
                    norm[n] = '\n'.join(normalize(insns, maps[n], va, va + ln,
                                                   info[n]['segment']))
                fam = components(with_bytes, lambda x, y: norm[x] == norm[y] or
                                 same_masked(info[x]['data'], info[y]['data'],
                                             maps[x], maps[y], info[x]['segment'],
                                             info[y]['segment']))
                row['families'] = fam
                row['byte_families'] = byte_fam
                if len(fam) == 1 and len(with_bytes) == len(have):
                    row['status'] = 'equivalent'
                else:
                    row['status'] = 'differs'
        rows.append(row)
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json', metavar='OUT')
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--saus', default=','.join(map(str, SAUS)))
    ap.add_argument('--show', action='store_true',
                    help='with --only: print the normalized streams')
    ap.add_argument('--diff', metavar='A,B',
                    help='with --only: a unified diff of the normalized streams of '
                         'SAU A and SAU B (e.g. 2,5)')
    a = ap.parse_args()
    if a.diff:
        x, y = [int(v) for v in a.diff.split(',')]
        maps, images = load([x, y])
        import difflib
        for name in a.only or []:
            streams = []
            for n in (x, y):
                if name not in maps[n].symbols:
                    streams.append(['(not in sau%d\'s map)' % n])
                    continue
                va, ln = maps[n].extent(name)
                d = images[n].read(va, ln) if ln else None
                seg = maps[n].segment_of(name)
                streams.append(['sau%d 0x%X, 0x%X bytes' % (n, va, ln)] +
                               (normalize(disassemble(d, va), maps[n], va, va + ln,
                                          seg[2] if seg else None) if d else ['(no bytes)']))
            print('== %s' % name)
            print('\n'.join(difflib.unified_diff(streams[0][1:], streams[1][1:],
                                                  streams[0][0], streams[1][0],
                                                  lineterm='', n=2)) or '(same)')
        return 0
    saus = [int(x) for x in a.saus.split(',')]
    maps, images = load(saus)
    rows = catalog(maps, images, a.only)
    count = collections.Counter(r['status'] for r in rows)
    print('%d symbols over sau%s:' % (len(rows), ',sau'.join(map(str, saus))))
    for k in ('identical', 'equivalent', 'differs', 'one sau', 'no bytes'):
        print('  %-11s %5d' % (k, count.get(k, 0)))
    if a.only:
        for r in rows:
            fam = ' | '.join(','.join('sau%d' % n for n in f) for f in r.get('families', []))
            print('%-32s %-10s %s' % (r['name'], r['status'], fam))
            if a.show:
                for n in r['saus']:
                    va, ln = r['va'][n], r['len'][n]
                    d = images[n].read(va, ln) if ln else None
                    if d:
                        print('  -- sau%d 0x%X (0x%X bytes)' % (n, va, ln))
                        seg = maps[n].segment_of(r['name'])
                        for l in normalize(disassemble(d, va), maps[n], va, va + ln,
                                           seg[2] if seg else None):
                            print('    ' + l)
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(rows, f)
    return 0


if __name__ == '__main__':
    sys.exit(main())
