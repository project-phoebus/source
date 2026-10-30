{ mst_$unwire_page - give back the physical page behind one page of
  MSTEs.

  Image addresses:
    sau2  0x00E74A74  mst_$unwire_page (module-local)
    sau9  0x3C47C3DC  mst_$unwire_page (module-local)

  - MMU_$VTOP finds the physical page, which MMU_$REMOVE unmaps and
    MMAP_$FREE frees; a page not mapped crashes the system.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

[section(proc2_delete_pro, data$)]
procedure mst_$unwire_page(va: univ_ptr); internal;
var
  status: status_$t;
  ppn: integer32;
begin
  ppn := mmu_$vtop(integer32(va), status);
  if status.all = status_$ok then begin
%if large_vm %then
    mmu_$remove(va, 0);
%else
    mmu_$remove(ppn);
%endif
    mmap_$free(ppn);
  end
  else
    crash_system(status);
end;
