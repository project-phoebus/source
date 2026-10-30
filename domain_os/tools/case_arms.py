#!/usr/bin/env python3
"""Case statements whose arms mix compound and simple statements.

Style rule: when any arm of a case statement is a begin ... end block,
every arm that has a statement is one (the otherwise arm included).  An
empty arm stays empty, with a comment between its `:` and `;`
(`0: { empty };`).  `case_arms.py` lists the case statements that break
either rule; `--fix` rewrites them in place:

    1: n := 1;                  1: begin
    2: begin            ->        n := 1;
      ...                       end;
    end;                        2: begin
                                  ...
                                end;

An unmarked empty arm becomes `0: { empty };`, or takes the comment that
follows it on its line (`0: ;  { none }` -> `0: { none };`).  Variant
parts of records are not case statements and are left alone.  A case
statement laid out in a way the fixer does not handle (two arms on one
line, an arm that ends mid-line or crosses a %if line) is reported and
left for a hand edit.

    python3 tools/case_arms.py [--fix] [path ...]   (default: the tree)
"""

import bisect
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

OPENERS = ('begin', 'case', 'record', 'repeat')
BRANCH_END = re.compile(r'\n[ \t]*%(else|elseif|endif)\b')
WORD = re.compile(r'[A-Za-z_$][A-Za-z0-9_$]*|\d+#[0-9A-Za-z]+|\d+(\.\d+)?')


class Tok:
    __slots__ = ('text', 'start', 'end', 'line', 'col')

    def __init__(self, text, start, end, line, col):
        self.text, self.start, self.end = text, start, end
        self.line, self.col = line, col

    @property
    def low(self):
        return self.text.lower()


def tokenize(text):
    starts = [0] + [m.end() for m in re.finditer('\n', text)]
    toks = []
    i, n = 0, len(text)

    def add(a, b):
        ln = bisect.bisect_right(starts, a) - 1
        toks.append(Tok(text[a:b], a, b, ln, a - starts[ln]))

    while i < n:
        c = text[i]
        if c in ' \t\r\n\f':
            i += 1
        elif c == '%' and text[text.rfind('\n', 0, i) + 1:i].strip() == '':
            j = text.find('\n', i)          # a directive line
            i = n if j < 0 else j
        elif c == '{':
            j = text.find('}', i)
            i = n if j < 0 else j + 1
        elif text.startswith('(*', i):
            j = text.find('*)', i + 2)
            i = n if j < 0 else j + 2
        elif c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            add(i, j + 1)
            i = j + 1
        else:
            m = WORD.match(text, i)
            if m:
                add(i, m.end())
                i = m.end()
            elif text[i:i + 2] in (':=', '..', '<=', '>=', '<>'):
                add(i, i + 2)
                i += 2
            else:
                add(i, i + 1)
                i += 1
    return toks


def statement_cases(toks):
    """Indices of the `case` tokens that begin case statements."""
    out, stack = [], []
    for k, t in enumerate(toks):
        w = t.low
        if w in ('(', '['):
            stack.append(w)
        elif w in (')', ']'):
            if stack and stack[-1] in ('(', '['):
                stack.pop()
        elif w == 'case':
            blocks = [s for s in stack if s in OPENERS]
            if blocks and blocks[-1] == 'record':
                continue                     # a variant part
            out.append(k)
            stack.append('case')
        elif w in ('begin', 'record', 'repeat'):
            stack.append(w)
        elif w == 'end':
            while stack and stack[-1] in ('(', '['):
                stack.pop()
            if stack:
                stack.pop()
        elif w == 'until':
            while stack and stack[-1] != 'repeat':
                stack.pop()
            if stack:
                stack.pop()
    return out


def scan_statement(toks, j):
    """Index of the token ending the statement at j: a `;`, or the
    enclosing `end` / `otherwise`, at depth 0."""
    depth = 0
    while j < len(toks):
        w = toks[j].low
        if depth == 0 and w in (';', 'end', 'otherwise'):
            return j
        if w in OPENERS or w in ('(', '['):
            depth += 1
        elif w in ('end', ')', ']', 'until'):
            depth -= 1
        j += 1
    raise ValueError('unterminated statement')


def is_block(toks, s, e):
    """Whether tokens s..e are one begin ... end, a statement label
    (`normal_char: begin ... end`) allowed in front."""
    while e > s + 1 and toks[s + 1].text == ':':
        s += 2
    return e > s and toks[s].low == 'begin' and toks[e].low == 'end'


class Arm:
    def __init__(self, label, colon, first, last, term, compound):
        self.label = label        # index of the label's first token
        self.colon = colon        # index of ':' (or of `otherwise`)
        self.first = first        # first statement token (== term if empty)
        self.last = last          # last statement token (before any `;`)
        self.term = term          # the `;` after the arm, or None
        self.compound = compound


def parse_case(text, toks, k):
    j, depth = k + 1, 0
    while True:
        w = toks[j].low
        if w == 'of' and depth == 0:
            break
        depth += w in ('(', '[')
        depth -= w in (')', ']')
        j += 1
    j += 1
    arms = []
    while toks[j].low != 'end':
        label = j
        if toks[j].low == 'otherwise':
            colon = j
            j += 1
            first, stmts = j, []
            while toks[j].low != 'end':
                e = scan_statement(toks, j)
                if e > j:
                    stmts.append((j, e - 1))
                j = e + 1 if toks[e].text == ';' else e
                if BRANCH_END.search(text, toks[j - 1].end, toks[j].start):
                    break                    # the otherwise of one branch
            last_tok = j - 1
            term = last_tok if toks[last_tok].text == ';' and last_tok >= first else None
            last = last_tok - 1 if term is not None else last_tok
            compound = len(stmts) == 1 and is_block(toks, *stmts[0])
            if not stmts:
                first = last + 1
            arms.append(Arm(label, colon, first, last, term, compound))
            continue
        depth = 0
        while not (toks[j].text == ':' and depth == 0):
            depth += toks[j].text in ('(', '[')
            depth -= toks[j].text in (')', ']')
            j += 1
        colon = j
        first = j + 1
        e = scan_statement(toks, first)
        compound = is_block(toks, first, e - 1)
        term = e if toks[e].text == ';' else None
        arms.append(Arm(label, colon, first, e - 1, term, compound))
        j = e + 1 if term is not None else e
    return arms, j


class Bail(Exception):
    pass


def wrap(text, toks, arm):
    """Return text with one simple arm turned into a begin ... end."""
    lines = text.split('\n')
    lab, colon = toks[arm.label], toks[arm.colon]
    ind = lab.col
    if lines[lab.line][:ind].strip():
        raise Bail('the arm does not start its line')
    pad = ' ' * ind
    ll = colon.line                     # a label list may span lines
    col_end = colon.col + len(colon.text)
    head = lines[ll][:col_end]

    after = arm.term + 1 if arm.term is not None else arm.last + 1
    end_tok = toks[arm.term] if arm.term is not None else toks[arm.last]
    if after < len(toks) and toks[after].line == end_tok.line:
        raise Bail('code follows the arm on its line')

    if arm.first > arm.last:
        raise Bail('an empty arm')

    f, l = toks[arm.first], toks[arm.last]
    le = end_tok.line
    m = re.compile(r'[ \t]*(\{|\(\*)').match(text, end_tok.end)
    if m:                                # a comment after the arm, to its end
        close = text.find('}' if m.group(1) == '{' else '*)', m.end())
        le = text.count('\n', 0, close)
    if any(lines[i].lstrip().startswith('%') for i in range(lab.line, le + 1)):
        raise Bail('a directive inside the arm')
    if arm.term is None:                           # supply the `;`
        lines[l.line] = lines[l.line][:l.col + len(l.text)] + ';' \
            + lines[l.line][l.col + len(l.text):]

    def shift(i, delta):
        s = lines[i]
        if not s.strip() or s.lstrip().startswith('%'):
            return
        lead = len(s) - len(s.lstrip(' '))
        if delta < 0 and lead < -delta:
            raise Bail('a continuation line left of the body')
        lines[i] = ' ' * (lead + delta) + s.lstrip(' ')

    body = ind + 2
    if f.line == ll:
        rest = lines[ll][f.col:]
        delta = body - f.col
        lines[ll] = head + ' begin'
        new_first = ' ' * body + rest
        for i in range(ll + 1, le + 1):
            shift(i, delta)
        lines[ll + 1:ll + 1] = [new_first]
        le += 1
    else:
        tail = lines[ll][col_end:]
        lines[ll] = head + ' begin' + (tail if tail.strip() else '')
        delta = body - f.col
        if delta:
            for i in range(f.line, le + 1):
                shift(i, delta)
    lines[le + 1:le + 1] = [pad + 'end;']
    return '\n'.join(lines)


def mark(text, toks, arm):
    """Return text with a comment put in one empty arm."""
    lines = text.split('\n')
    colon = toks[arm.colon]
    ll = colon.line
    head = lines[ll][:colon.col + len(colon.text)]
    if arm.term is None:                           # before `end`
        lines[ll] = head + ' { empty };' + lines[ll][len(head):]
        return '\n'.join(lines)
    t = toks[arm.term]
    rest = lines[t.line][t.col + 1:]
    m = re.fullmatch(r'[ \t]*(\{[^{}]*\})[ \t]*', rest)
    note = m.group(1) if m else '{ empty }'
    if m:
        rest = ''
    if t.line == ll:
        lines[ll] = head + ' ' + note + ';' + rest
    elif len(head) + len(note) + 2 <= 80 and not ''.join(
            lines[ll + 1:t.line]).strip() and not lines[t.line][:t.col].strip():
        lines[ll] = head + ' ' + note + ';' + rest
        del lines[ll + 1:t.line + 1]
    else:
        lines[t.line] = lines[t.line][:t.col] + note + ';' + rest
    return '\n'.join(lines)


def is_marked(text, toks, arm):
    """Whether an empty arm has a comment between its `:` and `;`."""
    stop = toks[arm.term].start if arm.term is not None else toks[arm.first].start
    gap = text[toks[arm.colon].end:stop]
    return '{' in gap or '(*' in gap


def problems(text):
    """(line, toks, case, arms to wrap, empty arms to mark) of each case
    statement that breaks the rules."""
    toks = tokenize(text)
    out = []
    for k in statement_cases(toks):
        try:
            arms, _ = parse_case(text, toks, k)
        except (ValueError, IndexError):
            continue
        empty = [a for a in arms if a.first > a.last]
        simple = [a for a in arms if not a.compound and a not in empty]
        if not any(a.compound for a in arms):
            simple = []
        unmarked = [a for a in empty if not is_marked(text, toks, a)]
        if simple or unmarked:
            out.append((toks[k].line + 1, toks, k, simple, unmarked))
    return out


def fix(text):
    """Rewrite text until no mixed case is left; returns (text, bails)."""
    bails, skip = [], set()
    for _ in range(10000):
        todo = [p for p in problems(text) if p[0] not in skip]
        if not todo:
            return text, bails
        line, toks, k, simple, unmarked = todo[0]
        try:
            # the last arm first, so the earlier arms' tokens keep their lines
            new = text
            for arm in sorted(simple + unmarked, key=lambda a: -a.label):
                new = (wrap if arm in simple else mark)(new, toks, arm)
            if any(p[0] == line for p in problems(new)):
                raise Bail('the rewrite left arms to fix')
            text = new
        except Bail as e:
            bails.append((line, str(e)))
            skip.add(line)
    raise RuntimeError('no fixpoint')


def pascal_files(paths):
    for p in paths:
        if os.path.isfile(p):
            yield p
            continue
        for d, subs, files in os.walk(p):
            subs[:] = sorted(s for s in subs if s not in ('tools', 'test', 'build', 'dist'))
            for f in sorted(files):
                if f.endswith('.pas'):
                    yield os.path.join(d, f)


def main(argv):
    do_fix = '--fix' in argv
    paths = [a for a in argv if not a.startswith('--')] or [ROOT]
    count = 0
    for p in pascal_files(paths):
        with open(p) as fh:
            text = fh.read()
        rel = os.path.relpath(p, ROOT)
        if do_fix:
            new, bails = fix(text)
            if new != text:
                with open(p, 'w') as fh:
                    fh.write(new)
                print('fixed', rel)
            for line, why in bails:
                print('%s:%d: left for a hand edit: %s' % (rel, line, why))
                count += 1
        else:
            for line, _, _, simple, unmarked in problems(text):
                if simple:
                    print('%s:%d: case with %d simple arm(s) beside begin ... end arms'
                          % (rel, line, len(simple)))
                if unmarked:
                    print('%s:%d: case with %d empty arm(s) without a comment'
                          % (rel, line, len(unmarked)))
                count += 1
    return 1 if count else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
