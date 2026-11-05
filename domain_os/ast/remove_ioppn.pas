{ AST_$REMOVE_IOPPN - unmap a segment's I/O page.

  Image addresses:
    sau4  0x0F8075E4  AST_$REMOVE_IOPPN
    sau6  0x78007838  AST_$REMOVE_IOPPN
    sau7  0x3C407DCA  AST_$REMOVE_IOPPN
    sau9  0x3C4085CA  AST_$REMOVE_IOPPN

  - Under the PMAP lock, after the entry's transition: the descriptor
    stops being resident, the translations are flushed, the segment's
    wire count goes down by one and the entry is cleared.

  Status stored: none.
}

procedure ast_$remove_ioppn(var aste: ast_$aste_t; page: integer);
  options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  with ast_pmaps[aste.seg_index, page] do begin
    while ast_$pmap_in_trans in flags do
      ast_$wait_for_page_transition;
    flags := flags - [ast_$pmap_resident];
    mmu_$purge;
    aste.wire_count := aste.wire_count - 1;
    all := 0;
  end;
  ml_$unlock(ml_$pmap_lock);
end;
