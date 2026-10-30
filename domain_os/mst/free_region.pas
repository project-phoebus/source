{ mst_$free_region - free an active region of an address space's
  private segments.

  Image addresses:
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

  Status stored: none.
}

[section(proc2_delete_pro, data$)]
procedure mst_$free_region(region: mst_region_t; group: pinteger;
                           asid: integer);
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
