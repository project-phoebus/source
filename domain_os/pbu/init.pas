{ PBU_$INIT - initialize the PBU support.

  Image addresses:
    sau2  0x00E5910E  PBU_$INIT
    sau3  0x00E5A102  map_owner_pages (nested)
    sau3  0x00E5A1B2  PBU_$INIT
    sau5  0x00E5A5AE  map_owner_pages (nested)
    sau5  0x00E5A65E  PBU_$INIT
    sau8  0x03C62A96  map_owner_pages (nested)
    sau8  0x03C62B3E  PBU_$INIT

  - An empty procedure where the PBU support is configured out (the
    SAU2).
  - With the driver (`pbu_driver'): init_lock initializes the exclusion
    lock (IO_$INIT's call).
  - present and high_ok are the Multibus's (`mbus_bus'); without it
    the PBU is present.
  - With the VME bus (`vme_bus') and without the Multibus, high_ok is
    whether the memory ends at or below 16#380000; otherwise
    PBU_$PPN_OWNERS' pages are mapped and cleared.
  - map_owner_pages (nested) takes its pages from MMAP_$ALLOC_FREE under
    init_lock, else WP_$CALLOC; a failure crashes the system.

  Status stored: none.
}

%if pbu_driver %then
procedure pbu_$init(init_lock: boolean); options(val_param);
type
  page_t = array[1..256] of integer32;
  page_ptr_t = ^page_t;
var
  first: linteger;
  last: linteger;
  start: integer32;
  len: integer32;

  procedure map_owner_pages(len: integer32; va: integer32);
    options(val_param);
  var
    ppn: integer32;
    alloc_status: status_$t;
    npages: integer32;
    i: integer32;
    j: integer;
  begin
    npages := (len + 1023) div 1024;
    for i := 1 to npages do begin
      if init_lock then begin
        if mmap_$alloc_free(ppn, 1) = 0 then
          crash_system(status_$pbu_too_many_wired_pages);
      end
      else begin
        wp_$calloc(ppn, alloc_status);
        if alloc_status.all <> status_$ok then
          crash_system(alloc_status);
      end;
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      for j := 1 to 256 do
        page_ptr_t(va)^[j] := 0;
      va := va + 1024;
    end;
  end;

begin
  if init_lock then
    ml_$exclusion_init(pbu_$exclusion_lock);
%if mbus_bus %then
  pbu_$mcb.present := mbus_$present;
  pbu_$mcb.high_ok := mbus_$high_ok;
%else
  pbu_$mcb.present := true;
%endif
%if vme_bus %then
  if not pbu_$mcb.present then
    pbu_$mcb.high_ok := mmap_$hppn * 1024 <= 16#380000
  else
%endif
  begin
    first := mmap_$lppn & 16#FFFFFE00;
    last := (mmap_$hppn + 16#1FF) & 16#FFFFFE00;
    start := integer32(addr(pbu_$ppn_owners[first])) & 16#FFFFFC00;
    len := integer32(addr(pbu_$ppn_owners[last])) - start;
    map_owner_pages(len, start);
    pbu_$mcb.owners_mapped := true;
  end;
end;
%else
procedure pbu_$init;
begin
end;
%endif
