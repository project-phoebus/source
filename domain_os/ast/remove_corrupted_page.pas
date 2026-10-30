{ AST_$REMOVE_CORRUPTED_PAGE - drop a page frame whose contents are
  suspect.

  Image addresses:
    sau2  0x00E07276  AST_$REMOVE_CORRUPTED_PAGE
    sau9  0x3C4087AC  AST_$REMOVE_CORRUPTED_PAGE

  - Called from the parity path.  A page clean in both the PFT and the
    MMAP entry is invalidated (AST_$INVALIDATE_PAGE) and the result is
    true.
  - A modified page cannot be dropped: its object's UID goes to
    AST_$SAVE_CLOBBERED_UID.  Nothing is done when this process holds
    the AST or PMAP lock, or the frame is not an installed page.

  Status stored: none.
}

function ast_$remove_corrupted_page(ppn: linteger): boolean;
  options(val_param);
var
  blocked: boolean;
  seg: pinteger;
  aste: ast_$aste_ptr_t;
  entry: ast_$pmap_entry_ptr_t;
begin
  ast_$remove_corrupted_page := false;
  blocked := proc1_$tst_lock(16#12) or proc1_$tst_lock(16#14) or
             (ppn < mmap_$first_ppn);
  if blocked then return;

  if ppn > mmap_$last_ppn then return;

  with mmap[ppn] do begin
    seg := segment;
    if not in_wsl then return;
    if seg = 0 then return;
    aste := addr(ast[seg]);
    entry := addr(ast_pmaps[seg][seg_offset]);
    if ast_$pmap_in_trans in entry^.flags then return;
    if not (ast_$pmap_installed in entry^.flags) then return;
%if pmmu_page_maps %then
    if not (ast_$pmap_modified in entry^.flags) and then
       not modified then begin
%else
    if not (14 in ast_$word_set_t(pft[ppn].w_02)) and then
       not modified then begin
%endif
      ast_$invalidate_page(aste^, entry^, ppn);
      ast_$remove_corrupted_page := true;
    end
    else
      ast_$save_clobbered_uid(aste^.aote^.uid);
  end;
end;
