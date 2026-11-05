{ AST_$PTOV - the virtual address that maps a physical page.

  Image addresses:
    sau7  0x3C407ED0  AST_$PTOV
    sau8  0x03C076C4  AST_$PTOV
    sau9  0x3C4086D0  AST_$PTOV

  - Nothing is found while the AST lock is held, or for a page outside
    MMAP's range, not on a working set list, wired, or of no segment.
  - The page's segment must have it installed; the current address
    space's mapping of the segment comes from the thread of its page map
    (MST_$BST_TO_VA), and the result adds the page's offset in the
    segment.
  - The result: true when va and asid (the address space that maps the
    page, 0 for a global segment) were set.

  Status stored: none.
}

function ast_$ptov(ppn: integer32; out asid: integer; out va: integer32):
  boolean;
  options(val_param);
var
  blocked: boolean;
begin
  ast_$ptov := false;
  blocked := proc1_$tst_lock(ml_$ast_lock) or (ppn < mmap_$first_ppn);
  if blocked then return;
  if ppn > mmap_$last_ppn then return;

  with mmap[ppn] do begin
    if not in_wsl then return;
    if flags2_7 then return;
    if segment = 0 then return;
    if not (ast_$pmap_installed in
            ast_pmaps[segment, seg_offset].flags) then return;
    if mst_$bst_to_va(ast[segment].pmap_link, proc1_$as_id, va, asid) then
    begin
      va := va + seg_offset * 1024;
      ast_$ptov := true;
    end;
  end;
end;
