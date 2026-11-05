#!/usr/bin/env python3
"""sau_overview.py - per-SAU progress across SR10.2, from tools/sau_catalog.py.

    tools/sau_overview.py            (from domain_os/: prints the table)

For every SR10.2 SAU, how its map routines stand against the other
SAUs':

  same as another SAU  the catalog puts it in a family (identical or
                       equivalent code) with at least one other SAU,
                       whichever SAU that is: one translation covers them;
  own code             code no other SAU has in this form: translation work.

Every routine is in exactly one of the two, so routines = same + own.

Only symbols in code segments (`I') count as routines; the hand-written
modules' code (in `D' segments) and the data are listed apart.  The
catalog is cached in ../tmp/kernel_progress/sau_catalog.json, keyed by the
catalog tool's own bytes (the images and maps never change).

render_html gives the table as HTML for a progress page.
"""
import collections
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sau_catalog  # noqa: E402

WORK = os.path.abspath(os.path.join(HERE, '..', '..', 'tmp', 'kernel_progress'))
def catalog_rows():
    """The catalog's rows, from the cache when the tool is unchanged."""
    with open(sau_catalog.__file__, 'rb') as f:
        key = hashlib.sha1(f.read()).hexdigest()[:16]
    path = os.path.join(WORK, 'sau_catalog.json')
    try:
        with open(path) as f:
            c = json.load(f)
        if c.get('key') == key:
            return c['rows']
    except (OSError, ValueError):
        pass
    maps, images = sau_catalog.load(sau_catalog.SAUS)
    rows = sau_catalog.catalog(maps, images)
    for r in rows:               # JSON keys: SAU numbers as strings
        for k in ('segment', 'kind', 'va', 'len'):
            r[k] = {str(n): v for n, v in r[k].items()}
    os.makedirs(WORK, exist_ok=True)
    with open(path, 'w') as f:
        json.dump({'key': key, 'rows': rows}, f)
    return rows


def classify(r, n):
    """The column one SAU's copy of a catalog row counts in."""
    have = set(r['saus'])
    if r['status'] in ('identical', 'equivalent'):
        return 'same' if len(have) > 1 else 'own'
    if r['status'] == 'one sau':
        return 'own'
    fams = [set(f) for f in r.get('families', [])]
    mine = next((f for f in fams if n in f), {n})
    return 'same' if len(mine) > 1 else 'own'


def overview(rows=None):
    """{sau: Counter of the columns}, cached beside the catalog."""
    path = os.path.join(WORK, 'sau_overview.json')
    with open(sau_catalog.__file__, 'rb') as f:
        key = hashlib.sha1(f.read()).hexdigest()[:16]
    with open(__file__, 'rb') as f:
        key += hashlib.sha1(f.read()).hexdigest()[:16]
    if rows is None:
        try:
            with open(path) as f:
                c = json.load(f)
            if c.get('key') == key:
                return collections.OrderedDict(
                    (int(n), collections.Counter(v)) for n, v in c['stats'])
        except (OSError, ValueError):
            pass
    stats = _overview(rows if rows is not None else catalog_rows())
    os.makedirs(WORK, exist_ok=True)
    with open(path, 'w') as f:
        json.dump({'key': key, 'stats': [(n, dict(v)) for n, v in stats.items()]}, f)
    return stats


def _overview(rows):
    stats = collections.OrderedDict()
    for n in sau_catalog.SAUS:
        stats[n] = collections.Counter()
    for r in rows:
        if r['status'] == 'no bytes':
            continue
        for n in r['saus']:
            kind = r['kind'].get(str(n))
            if not r['len'].get(str(n)):
                continue
            c = stats[n]
            if kind != 'I':
                c['data/asm'] += 1
                continue
            c['routines'] += 1
            c[classify(r, n)] += 1
    return stats


COLS = [('routines', 'Routines'), ('same', 'Same as another SAU'), ('own', 'Own code'),
        ('data/asm', 'Data / hand asm')]


# the Pascal columns' header tooltips
PCREL_TITLE = ('identical modulo PC-relative displacements: the same code, only a '
               'PC-relative operand reaching an equivalent target at another distance; '
               'not in Routines identical')
SIM_TITLE = ('mean similarity (0-1) of the compared routines that are not identical: '
             'an exact alignment of our instructions and the image\'s, positions (branch '
             'targets and sizes, PC-relative displacements) left out and addresses named '
             'by map symbol, a register-only difference counting half; the routine count '
             'in parentheses')


def sim_cell(mean, n, title=''):
    """A mean-similarity cell: `0.71 (1069)', or an empty one with no
    routines compared."""
    import html
    t = ' title="%s"' % html.escape(title) if title else ''
    if not n:
        return '<td class="n mut"%s>&ndash;</td>' % t
    return '<td class="n"%s>%.2f <span class="mut cnt">(%d)</span></td>' % (t, mean, n)


def render_html(stats, pascal, only=None):
    """The SAU table: the catalog's classes and, for each SAU in `pascal'
    ({sau: columns}), the Pascal build's
    numbers in their own columns.  With `only', that SAU's row alone (its
    own page)."""
    import html
    e = html.escape
    out = []
    if only is None:
        out += ['<h2>SR10.2, every SAU</h2>',
                '<div class="mut">From <code>tools/sau_catalog.py</code>: each SAU\'s map routines '
                'against the others\' (same instructions modulo branch sizes and addresses). '
                '<b>Same as another SAU</b> is the same code as at least one other SAU, whichever '
                'that is, so one translation covers them; <b>own code</b> is this SAU\'s alone '
                '(no other SAU has it in that form).  Routines = same + own.  The <b>Pascal</b> '
                'columns are '
                'the tree compiled with <code>-config sau&lt;N&gt;</code> and compared with that '
                'SAU\'s image; click a SAU for its page. '
                '<a href="/routines">Every routine, by SAU &rarr;</a></div>']
    out.append('<div class="wrap"><table><thead><tr><th rowspan="2">SAU</th>'
               '<th colspan="%d">Catalog</th><th colspan="5">Pascal</th></tr><tr>' % len(COLS))
    out += ['<th>%s</th>' % t for _, t in COLS]
    out.append('<th>Modules compiled</th><th>Unresolved</th><th>Routines identical</th>'
               '<th title="%s">Identical mod PC-relative</th>'
               '<th title="%s">Mean similarity</th></tr></thead><tbody>'
               % (e(PCREL_TITLE), e(SIM_TITLE)))
    for n, c in stats.items():
        if only is not None and n != only:
            continue
        tot = c['routines'] or 1
        cells = []
        for k, _ in COLS:
            v = c[k]
            if k in ('routines', 'data/asm'):
                cells.append('<td class="n">%d</td>' % v)
            else:
                cls = {'same': 'ok', 'own': 'bad'}[k]
                cells.append('<td class="n"><span class="%s">%d</span> <span class="mut">'
                             '%.0f%%</span></td>' % (cls, v, 100.0 * v / tot))
        p = pascal.get(n)
        if p:
            mcls = 'ok' if p['modules_ok'] == p['modules_total'] else 'part'
            cells.append('<td class="n %s">%d/%d</td>' % (mcls, p['modules_ok'], p['modules_total']))
            if p['unresolved'] is None:
                cells.append('<td class="n mut">not linked</td>')
            else:
                chk = {True: ' &middot; check ok', False: ' &middot; check FAILED',
                       None: ''}[p['check']]
                cells.append('<td class="n %s">%d%s</td>'
                             % ('ok' if p['unresolved'] == 0 else 'bad', p['unresolved'], chk))
            cells.append('<td class="n">%d/%d <span class="mut">%.0f%%</span></td>'
                         % (p['same'], p['routines'], 100.0 * p['same'] / (p['routines'] or 1)))
            cells.append('<td class="n">%d</td>' % p['same_pcrel'])
            cells.append(sim_cell(p['sim_mean'], p['sim_n']))
        else:
            cells.append('<td class="n mut">not started</td>')
            cells.append('<td class="n mut">&ndash;</td>')
            cells.append('<td class="n mut">&ndash;</td>')
            cells.append('<td class="n mut">&ndash;</td>')
            cells.append('<td class="n mut">&ndash;</td>')
        out.append('<tr><td><b><a href="/sau?n=%d">sau%d</a></b> <a class="mut" '
                   'href="/routines?sau=%d&amp;cls=own">own</a></td>%s</tr>'
                   % (n, n, n, ''.join(cells)))
    out.append('</tbody></table></div>')
    return '\n'.join(out)


CLASS_NAMES = {'same': 'same as another SAU', 'own': 'own code', 'data/asm': 'data / hand asm', 'no bytes': 'no bytes'}


def routine_rows(rows=None):
    """The catalog's rows trimmed for the routines page: per SAU the
    class, address, length, segment and the SAUs that agree with it."""
    rows = rows if rows is not None else catalog_rows()
    out = []
    for r in rows:
        per = {}
        fams = [list(f) for f in r.get('families', [])]
        for n in r['saus']:
            k = str(n)
            ln = r['len'].get(k) or 0
            if r['status'] == 'no bytes' or not ln:
                cls = 'no bytes'
            elif r['kind'].get(k) != 'I':
                cls = 'data/asm'
            else:
                cls = classify(r, n)
            fam = next((f for f in fams if n in f), [n])
            per[k] = [cls, r['va'][k], ln, r['segment'].get(k) or '',
                      sorted(x for x in fam if x != n)]
        out.append([r['name'], r['status'], per])
    return out


def routines_page(css):
    """The /routines page of a progress server: every map
    symbol of one SAU, filterable by class and name (in the browser)."""
    import html
    data = json.dumps(routine_rows(), separators=(',', ':'))
    opts = ''.join('<option value="%d">sau%d</option>' % (n, n) for n in sau_catalog.SAUS)
    copts = ''.join('<option value="%s">%s</option>' % (k, html.escape(v))
                    for k, v in CLASS_NAMES.items())
    return ("""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SAU Routine Catalog</title><style>%s
.filters { display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin:12px 0; }
.filters select, .filters input { font:inherit; padding:3px 6px; background:var(--card);
  color:var(--fg); border:1px solid var(--line); border-radius:6px; }
td.addr { font-family:ui-monospace, monospace; font-size:12.5px; }
.c-same { color:var(--ok); } .c-own { color:var(--bad); }
</style></head><body>
<h1>SR10.2 routine catalog</h1>
<div class="mut"><a href="/">&larr; progress</a> &middot; from <code>tools/sau_catalog.py</code>
(<code>tmp/kernel_progress/sau_catalog.json</code>). Classes as on the progress page: <b>same as
another SAU</b> is the same code as at least one other SAU, whichever that is; <b>own code</b>
is this SAU's alone (no other SAU has it in that form).
<i>Agrees with</i> lists the other SAUs with the same code.</div>
<div class="filters">
 <label>SAU <select id="sau">%s</select></label>
 <label>Class <select id="cls"><option value="">all routines (code)</option>
   <option value="*">everything</option>%s</select></label>
 <label>Name <input id="q" placeholder="substring" size="18"></label>
 <span class="mut" id="count"></span>
</div>
<div class="wrap"><table><thead><tr><th>Symbol</th><th>Class</th><th>Address</th>
<th>Size</th><th>Segment</th><th>Agrees with</th><th>Also in</th></tr></thead>
<tbody id="rows"></tbody></table></div>
<script>
var D=%s, NAMES=%s;
(function(){
 var sau=document.getElementById('sau'), cls=document.getElementById('cls'),
     q=document.getElementById('q'), body=document.getElementById('rows'),
     cnt=document.getElementById('count');
 var P=new URLSearchParams(location.search);
 sau.value=P.get('sau')||'5'; cls.value=P.get('cls')||''; q.value=P.get('q')||'';
 function esc(s){return String(s).replace(/[&<>"]/g,function(c){
   return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
 function hex(v){return '0x'+('00000000'+v.toString(16).toUpperCase()).slice(-8);}
 function draw(){
  var n=sau.value, c=cls.value, s=q.value.toUpperCase(), out=[], k=0;
  for(var i=0;i<D.length;i++){
   var r=D[i], p=r[2][n]; if(!p) continue;
   if(c===''){ if(p[0]==='data/asm'||p[0]==='no bytes') continue; }
   else if(c!=='*' && p[0]!==c) continue;
   if(s && r[0].toUpperCase().indexOf(s)<0) continue;
   var also=Object.keys(r[2]).filter(function(x){return x!==n;});
   k++;
   if(out.length<4000) out.push('<tr><td><code>'+esc(r[0])+'</code></td><td class="c-'+
     p[0].replace('/','')+'">'+esc(NAMES[p[0]])+'</td><td class="n addr">'+hex(p[1])+
     '</td><td class="n">0x'+p[2].toString(16).toUpperCase()+'</td><td>'+esc(p[3])+
     '</td><td>'+p[4].map(function(x){return 'sau'+x;}).join(' ')+'</td><td class="mut">'+
     also.map(function(x){return 'sau'+x;}).join(' ')+'</td></tr>');
  }
  body.innerHTML=out.join('');
  cnt.textContent=k+' symbol'+(k===1?'':'s')+(k>out.length?' (first '+out.length+' shown)':'');
  var u=new URLSearchParams(); u.set('sau',n); if(c) u.set('cls',c); if(s) u.set('q',q.value);
  history.replaceState(null,'','?'+u.toString());
 }
 sau.onchange=cls.onchange=draw; q.oninput=draw; draw();
})();
</script></body></html>""" % (css, opts, copts, data, json.dumps(CLASS_NAMES)))


def main():
    stats = overview()
    print('%-5s' % 'SAU' + ''.join('%21s' % t for _, t in COLS))
    for n, c in stats.items():
        print('sau%-2d' % n + ''.join('%21d' % c[k] for k, _ in COLS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
