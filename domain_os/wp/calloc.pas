{ WP_$CALLOC - allocate one wired page.

  Image addresses:
    sau2  0x00E070EC  WP_$CALLOC
    sau4  0x0F807456  WP_$CALLOC
    sau9  0x3C408326  WP_$CALLOC

  - Under ml_$pmap_lock, ast_$allocate_pages takes one page; its number
    is handed back.  A routine of the AST_ module (wp/README.md).

  Status stored:
    status_$ok: always
}

procedure wp_$calloc(out ppn_out: integer32; out status: status_$t);
var
  ppn_buf: array[1..32] of integer32;
begin
  ml_$lock(ml_$pmap_lock);
  discard(ast_$allocate_pages(1, 1, ppn_buf));
  ml_$unlock(ml_$pmap_lock);
  ppn_out := ppn_buf[1];
  status.all := status_$ok;
end;
