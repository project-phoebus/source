{ OS_$COLD_START - build the kernel's first translation tables.

  Image addresses:
    sau9  0x040033E4  OS_$COLD_START
    sau9  0x04003128  map_entry (nested)

  - Clears the root table (RARS's page), the global page maps (OS_PMAPS
    .. OS_PMAP_END), the segment descriptors (SMAPS .. OS_PAGE_END
    rounded up) and MMAP (16#100000 bytes), by physical address.
  - Marks MMAP's entry of every page of memory pageable: mem_size
    bytes from page 16#10000 (physical 16#4000000).
  - Maps the boot map's entries in order (map_entry); the first that
    fails ends it, its status stored.
  - Points the root table: COLD's segment's table, root entries 237 and
    238 at global A's (SMAPS), 240..255 at the global segments'.
  - Stores the tables' physical addresses in MMU_ASM's and DUMP's cells
    (RARS's page, OS_PMAPS, SMAPS).
  - Write protects the kernel's code when the boot flags (the boot
    record's word at +6) have bit 2 set and bit 15 clear.

  Status stored:
    status_$ok: the tables were built
    status_$cold_start_error: an entry not valid, a VA outside the
      global range and COLD's segment, or a page already mapped
}

{ TODO(pascal) stand-in locals

  unused_10, unused_34 and unused_46 hold the places of locals the image
  never addresses; what they were, and where the register-held
  smaps_pa, os_pmaps_pa and k were declared among them, is not visible. }

procedure os_$cold_start(in boot_params: os_cold_boot_params_t;
                         in mem_size: linteger;
                         in mem_flags: integer32;
                         out status: status_$t);
var
  ppn: linteger;                          { the entry's next page }
  segno: integer32;                       { its segment number }
  mmap_e: os_cold_mmape_ptr_t;            { the page's MMAP entry }
  unused_10: array[1..5] of integer32;    { a stand-in }
  mmap_pa: integer32;                     { MMAP's physical address }
  pt_pa: integer32;                       { the segment's page map }
  cold_sd_pa: integer32;                  { COLD's segment's descriptor }
  globals_pa: integer32;                  { the global segments' table }
  sd_pa: integer32;                       { the segment's descriptor }
  unused_34: integer32;                   { a stand-in }
  va: os_cold_va_t;                       { the entry's next VA }
  page: integer;                          { the page in its segment }
  table_seg: integer;                     { the segment in its table }
  count: integer;                         { the entry's pages left }
  k: integer;                             { the boot map's entry }
  unused_46: integer;                     { a stand-in }
  protect_code: boolean;                  { write protect the code }
  smaps_pa: integer32;                    { SMAPS's physical address }
  os_pmaps_pa: integer32;                 { OS_PMAPS's }

  { map_entry - map one boot map entry's pages (the parent's locals). }
  procedure map_entry(in e: os_cold_map_entry_t; out status: status_$t);
  begin
    ppn := e.pa div 1024;
    if e.count = 0 then
      count := (cold_page_round(integer32(addr(os_page_end))) -
                integer32(addr(os_proc))) div 1024
    else
      count := e.count;
    va.ptr := e.va;
    segno := va.segno;
    table_seg := va.table_seg;
    page := va.page;
    if e.flags.valid then begin
      if va.root >= os_cold_global_root then begin
        sd_pa := cold_phys(addr(smaps.global_b[segno - os_cold_global_seg]));
        pt_pa := cold_phys(addr(os_pmaps[segno]));
      end
      else if segno = os_cold_cold_seg then begin
        sd_pa := cold_phys(addr(smaps.private_a[segno]));
        pt_pa := cold_phys(addr(os_pmap_special));
      end
      else begin
        status.all := status_$cold_start_error;
        return;
      end;
    end
    else begin
      status.all := status_$cold_start_error;
      return;
    end;
    repeat
      { the segment's descriptor, once: 32 pages, its page map, the
        entry's protection and flags }
      if os_cold_sd_ptr_t(sd_pa)^.all = 0 then
        with os_cold_sd_ptr_t(sd_pa)^ do begin
          limit := 31;
          bits_15_10 := 63;
          s := true;
          dt := 2;
          wp := not e.flags.write;
          table := pt_pa;
          valid := e.flags.valid;
          write := e.flags.write;
          seg_bit_1 := e.flags.seg_bit_1;
          seg_bit_0 := e.flags.seg_bit_0;
        end;
      repeat
        with os_cold_pmap_ptr_t(pt_pa)^[page] do begin
          if odd(low) then begin
            status.all := status_$cold_start_error;
            return;
          end;
          { the frame, resident }
          frame := ppn;
          resident := true;
          if not e.flags.cacheable then
            ci := true
          else if e.count = 0 then begin
            if (va.all >= linteger(addr(os_pmaps))) and then
               (va.all < linteger(addr(os_pmap_end))) then
              ci := true
            else if protect_code then
              if ((va.all >= linteger(addr(os_proc))) and then
                  (va.all < linteger(addr(os_data_wired)))) or else
                 ((va.all >= linteger(addr(os_init_start))) and then
                  (va.all < linteger(addr(os_init_data_start)))) or else
                 ((va.all >= linteger(addr(os_proc_unwired))) and then
                  (va.all < linteger(addr(os_proc_end)))) then
                wp := true;
          end;
        end;
        { the page's MMAP entry }
        if ppn >= os_cold_first_ppn then begin
          mmap_e := os_cold_mmape_ptr_t((ppn - os_cold_first_ppn) * 16 +
                                        mmap_pa);
          with mmap_e^ do begin
            present := e.flags.mmap_bit_7;
            pageable := e.flags.mmap_bit_6;
          end;
        end;
        page := (page + 1) & 31;
        ppn := ppn + 1;
        va.all := va.all + 1024;
        count := count - 1;
      until (count = 0) or else (page = 0);
      sd_pa := sd_pa + 8;
      pt_pa := pt_pa + 128;
    until count = 0;
  end;

begin
  status.all := status_$ok;
  mmap_pa := cold_phys(addr(mmap));
  smaps_pa := cold_phys(addr(smaps));
  os_pmaps_pa := cold_phys(addr(os_pmaps));
  protect_code := (boot_params.flags * [2, 15]) = [2];

  cold_clear(os_cold_rars_pa, 1024);
  cold_clear(os_pmaps_pa,
             integer32(addr(os_pmap_end)) - integer32(addr(os_pmaps)));
  cold_clear(smaps_pa, cold_page_round(integer32(addr(os_page_end))) -
             integer32(addr(smaps)));
  cold_clear(mmap_pa, 16#100000);

  { the memory present, pageable }
  for ppn := os_cold_first_ppn to mem_size div 1024 + 16#FFFF do
    with os_cold_mmap_ptr_t(mmap_pa)^[ppn] do
      pageable := true;

  for k := 1 to 9 do begin
    map_entry(os_cold_map[k], status);
    if status.all <> status_$ok then
      return;
  end;

  globals_pa := cold_phys(addr(smaps.global_b[0]));
  va.ptr := addr(cold);
  cold_sd_pa := cold_phys(addr(smaps.private_a[va.segno]));
  cold_set_root(va.root, cold_sd_pa, 1);
  cold_set_root(os_cold_global_a_root, smaps_pa, 2);
  cold_set_root(os_cold_global_root, globals_pa, 16);

  os_cold_lp_t(cold_phys(addr(mmu_$rars_phaddr)))^ := os_cold_rars_pa;
  os_cold_lp_t(cold_phys(addr(mmu_$os_pmaps_phaddr)))^ := os_pmaps_pa;
  os_cold_lp_t(cold_phys(addr(dump_$smap_phaddr)))^ := smaps_pa;
  os_cold_lp_t(cold_phys(addr(dump_$rars_phaddr)))^ := os_cold_rars_pa;
end;
