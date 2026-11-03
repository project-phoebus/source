{ os_$free_ppn - return a physical page of the boot image to the free pool.

  Image addresses:
    sau2  0x00E6D222  os_$free_ppn (module-local)
    sau3  0x00E6D7CE  os_$free_ppn (module-local)
    sau5  0x00E6E8FE  os_$free_ppn (module-local)

  - The page's mapping is removed, then the page freed.
  - Only with `pft_mmu': the other SAUs' os_$free_va_page does this
    itself.

  Status stored: none.
}

%if pft_mmu %then
procedure os_$free_ppn(ppn: integer32); internal;
begin
  mmu_$remove(ppn);
  mmap_$free(ppn);
end;
%endif
