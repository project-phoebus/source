# The WP subsystem in Domain Pascal

The wired-page routines.

## Layout

No module of its own.  The four WP_ routines are routines of the AST_
map module (its WIRED_PROC code segment, 0x6788 bytes, between
AST_$LOCATE_ASTE and AST_$SET_TROUBLE), and they load AST_'s block (the
map's AST_ data segment in WIRED_DATA, 0x498 bytes), which they do not
use.  So they are fragments of AST_'s module file, `../ast/ast.pas`
(`module ast_, wired_proc, wired_data;`), which includes them in image
order, after AST_$LOCATE_ASTE:

| routine | fragment |
|---------|----------|
| WP_$CALLOC | `calloc.pas` |
| WP_$CALLOC_LIST | `calloc_list.pas` (`val_param`) |
| WP_$UNWIRE | `unwire.pas` (`val_param`) |
| WP_$WIRE | `wire.pas` (`val_param`) |

All four are global (map symbols), in WIRED_PROC with AST_'s other code,
so no attribute.  No nested or module-local routine; WP_$CALLOC and
WP_$CALLOC_LIST call AST_'s module-local ast_$allocate_pages, whose
body precedes them in AST_'s module file.  This is the pattern of
`tty/i_get_desc.pas` (OS_TERM's) and `fm/` (VTOC_'s).

`wp.ins.pas`: wp_lock_id (the PMAP lock, 0x14), the list type
`wp_$ppn_list_t`, and the four headings.  `mmap/mmap.ins.pas`:
MMAP_$WIRE and MMAP_$UNWIRE.

No conformance unit of `../domain-pascal/tests/conformance/` covers these
routines.

## Open items

### TODO(pascal)

None.
