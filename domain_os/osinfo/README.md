# The OSINFO subsystem in Domain Pascal

The memory-management queries.

## Layout

One module, `osinfo.pas`, `module osinfo;` (the map segment's name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | 0x43C bytes | OSINFO_$GET_SEG_TABLE (0xD0), OSINFO_$GET_MMAP (0x36C, its jump table inside) | none |

Data: none.  The map has no OSINFO data segment, and neither routine
loads A5; everything they read is another unit's, by absolute address.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| OSINFO_$GET_SEG_TABLE | `get_seg_table.pas` (two `for` loops of record copies) |
| OSINFO_$GET_MMAP | `get_mmap.pas` (a `case` with a jump table, a `while` page search, two `for` loops; the ASID selection inline, three times) |

`osinfo.ins.pas`: Apollo's two status codes from its osinfo.ins.pas
(osinfo_$array_toosmall, osinfo_$wrong_version) and two others; the
request flags as an enumeration and its set; the paging counters, the
global information record (a variant part at 0x28), the working set
entries and the segment table buffer; the two headings (SVC entries, the
default convention).

Changes to shared insert files:
- `mmap/mmap.ins.pas`: the page entry, the working set list header, the
  table MMAP (indexed from 16#200), MMAP_$WSL, MMAP_$WS_OWNER, the
  counters and page numbers, MMAP_$SET_WS_MAX's heading.
- `pmap/pmap.ins.pas`: the PMAP_ intervals and counters,
  PMAP_$PURGE_WS's heading.
- `ast/ast.ins.pas`: the AOTE (to its UID) and ASTE types, the AST and
  AST_PMAPS tables, the AST_ counters and AST_$SIZE_AST.
- `proc1/proc1.ins.pas`: PROC1_$CURRENT and PROC1_$TYPE.
- `proc2/proc2.ins.pas`: PROC2_$GET_PID's heading.

No conformance unit of `../domain-pascal/tests/conformance/` covers this
module.

## Open items

### Names and forms

- 16#00200002 is Apollo's osinfo_$wrong_version (its customer
  osinfo.ins.pas), used here for an ASID out of range.
- OSINFO_$GET_SEG_TABLE's table type 1 is the map's AST_PMAPS (0x80
  bytes per entry), not the AOT.
- OSINFO_$GET_MMAP tests the request's flag byte for each block.
- The three ASID selections are inline in the image, not a routine.

### TODO(pascal)

- `get_mmap.pas`: 12 frame bytes (stand-in `unused_18`).

## Named dispatch codes

osinfo/osinfo.ins.pas's dispatch-code block names OSINFO_$GET_MMAP's set
operations (`osinfo_$set_ws_interval` .. `_set_ws_limit`; Apollo's
osinfo.ins.pas has none).
