{ CHKSUM - the checksum of one physical page.

  Image addresses:
    sau2  0x00E0A290  CHKSUM
    sau9  0x3C40BDD0  CHKSUM

  - The page is mapped at a fixed scratch address, summed with
    CHKSUM_$GET_CHKSUM, its old mapping put back (or removed), and its
    used bit cleared.  The map symbol has no `$'.
  - Without `pft_mmu' the page is mapped at CHK_BUFF and that mapping
    removed after; the page's own mapping is left as it is.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function chksum(ppn: integer32): pinteger;
var
  old_va: integer32;
%if pft_mmu %then
begin
  old_va := mmu_$ptov(ppn);

  mmu_$install(ppn, univ_ptr(16#00FF8400), 0, 16#16);
  chksum := chksum_$get_chksum(univ_ptr(16#00FF8400));

  if old_va <> 0 then
    mmu_$install(ppn, univ_ptr(old_va), 0, 16#16)
  else
    mmu_$remove(ppn);

  mmu_$clr_used(ppn);
end;
%else
begin
  mmu_$install(ppn, addr(chk_buff), 0, 16#16);
  chksum := chksum_$get_chksum(addr(chk_buff));
  mmu_$remove(addr(chk_buff), 0);
end;
%endif
