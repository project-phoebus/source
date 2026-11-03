{ AST_$ASSOC_IOPPN - map an I/O page at a page of a segment.

  Image addresses:
    sau8  0x03C07524  AST_$ASSOC_IOPPN
    sau9  0x3C408530  AST_$ASSOC_IOPPN

  - Under the PMAP lock, after the entry's transition: an entry already
    resident (or with the descriptor type's other bit set) crashes the
    system.
  - The entry becomes a resident, installed descriptor of the page,
    cache-inhibited where the page maps' pages are
    (`pmap_cache_inhibit'), and the segment's wire count goes up by one.

  Status stored: none.
}

{ TODO(sau) The SAU4's and SAU6's AST_$ASSOC_IOPPN

  The SAU4 and SAU6 maps have AST_$ASSOC_IOPPN and AST_$REMOVE_IOPPN too,
  for their own page-map layout; this is the page-descriptor layout's
  body only. }

procedure ast_$assoc_ioppn(var aste: ast_$aste_t; page: integer;
                           ppn: integer32);
  options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  with ast_pmaps[aste.seg_index, page] do begin
    while ast_$pmap_in_trans in flags do
      ast_$wait_for_page_transition;
    { member 1: the descriptor type's high bit }
    if (ast_$pmap_resident in flags) or else (1 in flags) then
      crash_system(status_$pmap_io_page_over_real_page);
    all := 0;
    vpn := ppn;
%if pmap_cache_inhibit %then
    flags := flags + [ast_$pmap_resident, ast_$pmap_cache_inhibit,
                      ast_$pmap_installed];
%else
    flags := flags + [ast_$pmap_resident, ast_$pmap_installed];
%endif
  end;
  aste.wire_count := aste.wire_count + 1;
  ml_$unlock(ml_$pmap_lock);
end;
