{ os_$free_va_page - return a page of the boot image to the free pool.

  Image addresses:
    sau2  0x00E6D240  os_$free_va_page (module-local)
    sau5  0x00E6E91C  os_$free_va_page (module-local)
    sau9  0x3C473DFE  os_$free_va_page (module-local)

  - With `pft_mmu' the page is freed through os_$free_ppn.  Without it
    os_$free_va_page removes the address's mapping itself and clears the
    page's wire count before freeing it.

  Status stored: none.
}

%if pft_mmu %then
procedure os_$free_va_page(vaddr: integer32); internal;
begin
  os_$free_ppn(vtop_or_crash(vaddr));
end;
%else
procedure os_$free_va_page(vaddr: integer32); internal;
var
  ppn: integer32;
begin
  ppn := vtop_or_crash(vaddr);
  mmu_$remove(univ_ptr(vaddr), 0);
  if mmap[ppn].wire_count <> 0 then
    mmap[ppn].wire_count := 0;
  mmap_$free(ppn);
end;
%endif
