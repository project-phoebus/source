{ mst_$free_region - free an active region of an address space's
  private segments.

  Image addresses:
    sau4  0x0F882188  mst_$free_region (module-local)
    sau6  0x78082FD8  mst_$free_region (module-local)
    sau7  0x3C48B14E  mst_$free_region (module-local)
    sau8  0x03C7F3EA  mst_$free_region (module-local)
    sau9  0x3C47C4AA  mst_$free_region (module-local)

  Assume we're called with the ASID lock held.

  - An inactive region is left alone.  An active one leaves
    MST_$REGIONS_ACTIVE, its root entry in RARS is made invalid, and
    the page of segment map entries of its MST segment group is given
    back.
  - The group's BST page, shared with the other group of its pair, is
    given back only when that group's region is not active either.
  - The group's two MST words lose their pages of MSTEs, and the event
    is logged when network logging is on.
  - The log entry names the group; mst_$alloc_table_page's names the
    region.
  - With the layout chosen at boot the page of segment map entries is
    shared by the pair of regions and given back when the other is not
    active; the BST page, shared by four groups, when none of the four
    has a segment mapped; and the group has one MST word.
  - With the region registers the region's register is made invalid
    when its RARS page is installed, and loaded into the MMU when the
    address space is the current one; the group's BST page and its
    four MST words are given back with the region; without them (the
    65536 segments) the region's RARS entry is made invalid alone.

  Status stored: none.
}

[section(proc2_delete_pro, data$)]
procedure mst_$free_region(region: mst_region_t; group: pinteger;
                           asid: integer);
%if run_time_layout %then
var
  other: mst_region_t;
  quad: pinteger;
  seg: pinteger;
  page: 0..31;
  word: integer;
begin
  if region in mst_$regions_active[asid] then begin
    mst_$set_clear(mst_$regions_active[asid], mst_region_members, region);
    rars[rars_asid_base[asid] + region].ctl.dt := mst_smap_invalid;
    { the pair's other region: the page of segment map entries is freed
      with the last of the two }
    other := xor(group, 1);
    if other >= region_$private_a_size then
      other := other + (region_$private_b - region_$private_a_size);
    if not (other in mst_$regions_active[asid]) then
      mst_$unwire_page(addr(smaps[lshft(group, 6) + smap_asid_base[asid]]));
    { the BST page, freed when none of its four groups has a segment }
    quad := group & ~3;
    if (mst_$segs_mapped[asid][quad + 3] = 0) and then
       (mst_$segs_mapped[asid][quad + 2] = 0) and then
       (mst_$segs_mapped[asid][quad] = 0) and then
       (mst_$segs_mapped[asid][quad + 1] = 0) then begin
      seg := lshft(group, 6);
      page := seg div 256;
      if page in mst_$bst_pages[asid] then begin
        mst_$bst_pages[asid] := mst_$bst_pages[asid] - [page];
        mst_$unwire_page(addr(bst[seg + bst_asid_base[asid]]));
      end;
    end;
    word := lshft(group, 6) div 64 + mst_asid_base[asid];
    mst_$unwire_asid_pages(word, word);
    if netlog_$ok_to_log then
      netlog_$log_it(mst_region_netlog_kind, uid_$nil, 0, 0, -1, group,
                     0, 0);
  end;
end;
%elseif region_mmu %then
var
  seg: pinteger;
  page: 0..31;
  word: integer;
begin
  if region in mst_$regions_active[asid] then begin
    mst_$set_clear(mst_$regions_active[asid], mst_region_members, region);
%if region_registers %then
    { the region register, in its page of RARS (8 ASIDs' to a page) }
    if rshft(asid, 3) in mst_$rar_pages then begin
      rars[rars_asid_base[asid] + region].rar.valid := false;
      if asid = proc1_$as_id then
        mmu_$install_region(region, rars[rars_asid_base[asid] + region].all);
    end;
%else
    rars[rars_asid_base[asid] + region].rar.valid := false;
%endif
    seg := group * mst_region_segs;
    mst_$unwire_page(addr(smaps[seg + smap_asid_base[asid]]));
    page := seg div 256;
    if page in mst_$bst_pages[asid] then begin
      mst_$bst_pages[asid] := mst_$bst_pages[asid] - [page];
      mst_$unwire_page(addr(bst[seg + bst_asid_base[asid]]));
    end;
    word := seg div 64 + mst_asid_base[asid];
    mst_$unwire_asid_pages(word, word + mst_region_segs div 64 - 1);
    if netlog_$ok_to_log then
      netlog_$log_it(mst_region_netlog_kind, uid_$nil, 0, 0, -1, group,
                     0, 0);
  end;
end;
%else
var
  seg: pinteger;
  other: mst_region_t;
  page: 0..127;
  word: integer;
begin
  if region in mst_$regions_active[asid] then begin
    mst_$set_clear(mst_$regions_active[asid], 256, region);
    rars[rars_asid_base[asid] + region].ctl.dt := mst_smap_invalid;
    seg := group * mst_region_segs;
    mst_$unwire_page(addr(smaps[seg + smap_asid_base[asid]]));
    { the other group of the BST page, as a region }
    other := xor(group, 1);
    if other >= mst_private_a_regions then
      other := other + mst_global_a_regions;
    if not (other in mst_$regions_active[asid]) then begin
      page := seg div 256;
      if page in mst_$bst_pages[asid] then begin
        mst_$bst_pages[asid] := mst_$bst_pages[asid] - [page];
        mst_$unwire_page(addr(bst[seg + bst_asid_base[asid]]));
      end;
    end;
    word := seg div 64 + mst_asid_base[asid];
    mst_$unwire_asid_pages(word, word + 1);
    if netlog_$ok_to_log then
      netlog_$log_it(mst_region_netlog_kind, uid_$nil, 0, 0, -1, group,
                     0, 0);
  end;
end;
%endif
