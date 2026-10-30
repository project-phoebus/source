{ WP_$CALLOC_LIST - allocate a list of wired pages.

  Image addresses:
    sau2  0x00E07138  WP_$CALLOC_LIST
    sau9  0x3C408372  WP_$CALLOC_LIST

  - Under ml_$pmap_lock, ast_$allocate_pages takes count pages into the
    caller's list.  A routine of the AST_ module.

  Status stored: none.
}

procedure wp_$calloc_list(count: integer; out ppn_arr: univ wp_$ppn_list_t);
  options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  discard(ast_$allocate_pages(count, count, ppn_arr));
  ml_$unlock(ml_$pmap_lock);
end;
