{ scsi_init_ppn_owners - map and clear the page owners table.

  Image addresses:
    sau9  0x3C43BACA  scsi_init_ppn_owners

  - Only the part of SCSI_$PPN_OWNERS that covers physical memory
    (MMAP_$LPPN .. MMAP_$HPPN, widened to 512 pages) gets pages, and is
    cleared.
}

[section(os_init_proc, os_init_data)]
procedure scsi_init_ppn_owners;
type
  data_ptr_t = ^os_$data_t;
var
  first: integer32;
  last: integer32;
  pages: pinteger;
  i: pinteger;
  va: integer32;
  ppn_list: array[1..1] of integer32;
begin
  first := integer32(addr(scsi_$ppn_owners[mmap_$lppn & 16#FFFFFE00]))
           & 16#FFFFFC00;
  last := integer32(addr(scsi_$ppn_owners[(mmap_$hppn + 511)
                                          & 16#FFFFFE00]));
  pages := (last - first + 1023) div 1024;
  va := first;
  for i := 1 to pages do begin
    if mmap_$alloc_free(ppn_list, 1) = 0 then
      crash_system(status_$scsi_too_many_wired_pages);
    mmu_$install(ppn_list[1], univ_ptr(va), 0, 16#16);
    va := va + 1024;
  end;
  os_$data_zero(data_ptr_t(first)^, pages * 1024);
end;
