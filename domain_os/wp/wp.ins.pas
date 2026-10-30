{ wp/wp.ins.pas - WP_ (wired pages), for the Domain Pascal tree.

  What the Pascal files use.  The four WP_ routines are routines of the
  AST_ map module (its WIRED_PROC code segment; wp/README.md),
  whose module file ast/ast.pas includes their fragments, wp/*.pas.
  Include base/base.ins.pas before it.
}

type
  { A list of page numbers WP_$CALLOC_LIST fills, of the caller's
    length: `univ'. }
  wp_$ppn_list_t = array[1..1] of integer32;

{ WP_$UNWIRE - unwire a page. }
procedure wp_$unwire(wired_addr: integer32); options(extern, val_param);

{ WP_$CALLOC - allocate one wired page. }
procedure wp_$calloc(out ppn_out: integer32; out status: status_$t); extern;

{ WP_$CALLOC_LIST - allocate a list of wired pages. }
procedure wp_$calloc_list(count: integer; out ppn_arr: univ wp_$ppn_list_t);
  options(extern, val_param);

{ WP_$WIRE - wire a page. }
procedure wp_$wire(ppn: integer32); options(extern, val_param);
