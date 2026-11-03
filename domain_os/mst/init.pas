{ MST_$INIT - the MST words and the first pages of MSTEs, at boot.

  Image addresses:
    sau2  0x00E30AAE  mst_init_page (nested)
    sau2  0x00E30B10  mst_init_global_page (nested)
    sau2  0x00E30B88  MST_$INIT
    sau4  0x0F8340E2  mst_init_page (nested)
    sau4  0x0F834144  mst_init_global_page (nested)
    sau4  0x0F8341BC  MST_$INIT
    sau8  0x03C33BD2  mst_init_page (nested)
    sau8  0x03C33C34  mst_init_global_page (nested)
    sau8  0x03C33CA8  MST_$INIT
    sau9  0x3C436AB0  mst_init_page (nested)
    sau9  0x3C436B14  mst_init_global_page (nested)
    sau9  0x3C436B8C  MST_$INIT

  - The ASID set gets ASID 0 alone; the pages behind the MST words are
    allocated, installed and zeroed, and one page of MSTEs allocated
    for each 64 segments of global A and B.
  - MST_$MST_PAGES_LIMIT becomes the smaller of what 58 address spaces
    need and a tenth of memory (bounded to 125..358, rounded down to
    32); pages above it leave the bitmap.
  - With the large address space the share is 15% of the real pages
    and the bound 9830; every ASID's regions and segment counts are
    cleared, ASID 1 gets its RARS page (a copy of ASID 0's) and both
    the global regions, and ASID 0 its first nine BST pages.
  - With the layout chosen at boot ASID 1's root entries follow ASID
    0's in RARS's first page and are a copy of them; ASID 0's and ASID
    1's active regions are the global ones and region 0, whose segment
    map page ASID 1 gets with a copy of ASID 0's entry after its global
    segments; ASID 0 gets the BST pages of its global segments.
  - With the region registers the same, the regions constants: ASID 1's
    32 region registers follow ASID 0's, and its region 0 register,
    valid and not global, points at the page of segment map entries it
    gets.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mst_$init;
var
  words: linteger;
  end_va: linteger;
  pages: linteger;
  va: linteger;                           { shared with the nested
                                            routines }
  word: integer;                          { shared }
  bit: integer;                           { shared }
  seg: integer;
  i: integer;
  n: integer32;
  ten_percent: linteger;
%if vm_regions %then
  asid: integer;
  grp: integer;
%endif

  { mst_init_page - allocate a free page, install it at va and zero it;
    the page number is the result.

    - Nested in MST_$INIT; it reaches no enclosing frame.

    Status stored: none.
  }
  function mst_init_page(va: linteger): linteger;
  var
    vpns: array[1..3] of integer32;
    ppn: integer32;
    page: mst_mem_page_ptr_t;
    count: pinteger;
    i: integer;
  begin
    page := mst_mem_page_ptr_t(va);
    count := mmap_$alloc_free(vpns, 1);
    ppn := vpns[1];
    if count = 0 then
      crash_system(status_$virtual_memory_resources_exhausted);
    mmu_$install(ppn, page, 0, 16#16);
    for i := 0 to 255 do
      page^[i] := 0;
    mst_init_page := ppn;
  end;

  { mst_init_global_page - back MST word seg with a page of MSTEs, the
    next free page of the bitmap.

    - Nested in MST_$INIT; it reaches INIT's frame through the dynamic
      link.

    Status stored: none.
  }
  procedure mst_init_global_page(seg: integer);
  begin
    discard(mst_init_page(va));
    mst_$mst_pages_wired := mst_$mst_pages_wired + 1;
    mst[seg] := word * 32 + bit;
    page_avail_bitmap[word] := page_avail_bitmap[word] - [bit];
    if page_avail_bitmap[word] <> [] then
      bit := bit + 1
    else begin
      word := word + 1;
      bit := 0;
    end;
    va := va + 16#400;
  end;

begin
  mst_$touch_count := 4;
  mst_$asid_list := [0];
  va := linteger(addr(mst));
  words := ((mst_$seg_tn + 64 - 1) div 64) * (mst_max_asid + 1);
  end_va := linteger(addr(mst[words]));
  repeat
    discard(mst_init_page(va));
    va := va + 16#400;
  until end_va <= va;
  for i := 0 to words - 1 do
    mst[i] := 0;
  page_avail_bitmap[0] := page_avail_bitmap[0] - [0];
  va := linteger(addr(mste_pages));
  mst_$mst_pages_wired := 0;
  word := 0;
  bit := 1;
  for seg := 0 to mst_$global_a_size div 64 - 1 do
    mst_init_global_page(seg);
  for seg := mst_$global_a_size div 64 to
      (mst_$global_a_size + mst_$global_b_size) div 64 - 1 do
    mst_init_global_page(seg);
%if large_address_space or run_time_layout or vm_8192_segs %then
  pages := mmap_$real_pages;
%else
  if not m68020 then
    pages := mmap_$pageable_pages
  else
    pages := mmap_$real_pages;
%endif
  ten_percent := (pages * mst_pages_percent) div 100;
  mst_$mst_pages_limit := min((mst_$seg_tn div 64) * (mst_max_asid + 1),
                              ten_percent);
  mst_$mst_pages_limit := max(125, mst_$mst_pages_limit);
  mst_$mst_pages_limit := min(mst_$mst_pages_limit, mst_pages_max);
  mst_$mst_pages_limit := (mst_$mst_pages_limit div 32) * 32;
  page_alloc_hint := word;
  n := mst_$mst_pages_limit + 1;
  word := n div 32;
  for bit := n mod 32 to 31 do
    page_avail_bitmap[word] := page_avail_bitmap[word] - [bit];
  for word := word + 1 to mst_bitmap_last do
    page_avail_bitmap[word] := [];
%if region_mmu %then
  { every ASID's regions and segment counts cleared }
  for asid := 0 to mst_max_asid do begin
    mst_$regions_active[asid] := [];
    for grp := 0 to mst_seg_groups - 1 do
      mst_$segs_mapped[asid][grp] := 0;
  end;
  { ASID 1's region registers, after ASID 0's in RARS's first page, a
    copy of them }
  mmu_$rars_phaddr[1] := mmu_$rars_phaddr[0] + mst_region_members * 4;
  mst_$rar_pages := [0];
  for i := 0 to mst_region_members - 1 do
    rars[rars_asid_base[1] + i] := rars[rars_asid_base[0] + i];
  mst_$regions_active[0] := mst_global_regions;
  mst_$regions_active[0] := mst_$regions_active[0] + [0];
  mst_$regions_active[1] := mst_$regions_active[0];
  { ASID 1's region 0: its page of segment map entries, the first one a
    copy of ASID 0's after the global segments }
  va := linteger(addr(smaps[smap_asid_base[1]])) & ~16#3FF;
  n := mst_init_page(va);
  rars[rars_asid_base[1]].all := 0;
  rars[rars_asid_base[1]].rar.smap_pa := n * 1024;
  rars[rars_asid_base[1]].bits := rars[rars_asid_base[1]].bits - [30];
  rars[rars_asid_base[1]].bits := rars[rars_asid_base[1]].bits + [31];
  smaps[smap_asid_base[1]] :=
    smaps[smap_asid_base[0] + mst_$global_a_size + mst_$global_b_size];
  { ASID 0's BST pages, for its global segments }
  for asid := 0 to mst_max_asid do
    mst_$bst_pages[asid] := [];
  va := linteger(addr(bst));
  for i := 0 to ((mst_$global_b_size + mst_$global_a_size) * 4 - 1)
                div 1024 do begin
    mst_$bst_pages[0] := mst_$bst_pages[0] + [i];
    discard(mst_init_page(va));
    va := va + 16#400;
  end;
%elseif large_address_space %then
  { every ASID's regions and segment counts cleared }
  for asid := 0 to mst_max_asid do begin
    mst_$regions_active[asid] := [];
    for grp := 0 to mst_seg_groups - 1 do
      mst_$segs_mapped[asid][grp] := 0;
  end;
  { ASID 1's RARS page, a copy of ASID 0's }
  mmu_$rars_phaddr[1] :=
    mst_init_page(linteger(addr(rars[rars_asid_base[1]]))) * 1024;
  for i := 0 to 255 do
    rars[rars_asid_base[1] + i] := rars[rars_asid_base[0] + i];
  mst_$regions_active[0] := mst_global_regions;
  mst_$regions_active[1] := mst_$regions_active[0];
  { ASID 0's first nine BST pages }
  for asid := 0 to mst_max_asid do
    mst_$bst_pages[asid] := [];
  va := linteger(addr(bst));
  for i := 0 to 8 do begin
    mst_$bst_pages[0] := mst_$bst_pages[0] + [i];
    discard(mst_init_page(va));
    va := va + 16#400;
  end;
%elseif run_time_layout %then
  { every ASID's regions and segment counts cleared }
  for asid := 0 to mst_max_asid do begin
    mst_$regions_active[asid] := [];
    for grp := 0 to region_$private_tn - 1 do
      mst_$segs_mapped[asid][grp] := 0;
  end;
  { ASID 1's root entries, after ASID 0's in RARS's first page, a copy
    of them }
  mmu_$rars_phaddr[1] := mmu_$rars_phaddr[0] + region_$tn * 4;
  mst_$rar_pages := [0];
  for i := 0 to region_$tn - 1 do
    rars[rars_asid_base[1] + i] := rars[rars_asid_base[0] + i];
  mst_$regions_active[0] :=
    [region_$global_b .. region_$global_b + region_$global_b_size - 1,
     region_$global_a .. region_$global_a + region_$global_a_size - 1];
  mst_$regions_active[0] := mst_$regions_active[0] + [0];
  mst_$regions_active[1] := mst_$regions_active[0];
  { ASID 1's region 0: its page of segment map entries, the first one a
    copy of ASID 0's after the global segments }
  va := linteger(addr(smaps[smap_asid_base[1]])) & ~16#3FF;
  rars[rars_asid_base[1]].all := mst_init_page(va) * 1024 +
                                 mst_rars_valid;
  smaps[smap_asid_base[1]] :=
    smaps[smap_asid_base[0] + mst_$global_a_size + mst_$global_b_size];
  { ASID 0's BST pages, for its global segments }
  for asid := 0 to mst_max_asid do
    mst_$bst_pages[asid] := [];
  va := linteger(addr(bst));
  for i := 0 to ((mst_$global_b_size + mst_$global_a_size) * 4 - 1)
                div 1024 do begin
    mst_$bst_pages[0] := mst_$bst_pages[0] + [i];
    discard(mst_init_page(va));
    va := va + 16#400;
  end;
%endif
end;

{ TODO(pascal) MST_$INIT's loose forms

  - The first product's word-width sum, which a 32-bit `div' here does
    not give; the original's operand types are not seen.
  - The clearing loop has no guard, which a `for' has.
  - mst_init_page's frame is larger in dpc (a result slot and homes for
    count and i).  dpc compiles INIT longer than the image's.
  - With the large address space: the image's frame has two bytes
    between va and word and a longword the RARS copy stores
    rars_asid_base[0] in on each pass; the constant region set is
    copied from the code and the BST page's member added through a
    16-byte set built in the frame, where dpc stores immediates and sets
    the bit in place; the 15% is divided unsigned (the SAU2's
    M$DIU$LLW), dpc's signed. }

{ TODO(pascal) MST_$INIT's global regions with the layout chosen at boot

  The set constructor of the global regions has run-time ranges, which
  dpc does not compile yet; the image builds it in a 16-byte frame
  temporary.  The count and root-entry loops have no zero-trip test in
  the image, which a `for' has. }
