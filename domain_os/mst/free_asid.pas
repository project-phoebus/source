{ MST_$FREE_ASID - tear down an address space's mappings and free its
  ASID.

  Image addresses:
    sau2  0x00E74B3C  MST_$FREE_ASID
    sau4  0x0F8822C8  MST_$FREE_ASID
    sau6  0x7808312C  MST_$FREE_ASID
    sau7  0x3C48B2BA  MST_$FREE_ASID
    sau8  0x03C7F550  MST_$FREE_ASID
    sau9  0x3C47C616  MST_$FREE_ASID

  - The private A and then the private B segments are unmapped; then
    the areas are freed and, under the ASID lock, the pages behind the
    MST words given back and the ASID cleared from MST_$ASID_LIST.
  - With the large address space the active private regions are freed
    instead (mst_$free_region), and the ASID's RARS page given back.
  - With the layout chosen at boot the active regions but the global
    ones are freed; the root entries' page stays.
  - With the region registers the private regions are freed as with the
    large address space; the region registers' page, shared with other
    ASIDs, stays.
  - A failed unmap crashes the system.

  Status stored:
    status_$ok: freed (MST_$UNMAP_PRIVI's)
}

[section(proc2_delete_pro, data$)]
procedure mst_$free_asid(asid: integer; out status: status_$t);
label
  crash;
%if vm_regions %then
var
%if run_time_layout %then
  { a set of 256 regions: the image forms the difference in 32 bytes }
  private: set of 0..255;
%else
  private: mst_region_set_t;
%endif
  region: mst_region_t;
  group: pinteger;
%endif
begin
  mst_$unmap_privi(mst_unmap_any_seg, uid_$nil, 0,
                   lshft(linteger(mst_$private_a_size), 15),
                   asid, status);
  if status.all <> status_$ok then goto crash;
  mst_$unmap_privi(mst_unmap_any_seg, uid_$nil,
                   lshft(linteger(mst_$seg_private_b), 15),
                   lshft(linteger(mst_private_b_count), 15), asid,
                   status);
  if status.all = status_$ok then begin
    area_$free_asid(asid);
    ml_$lock(ml_$mst_asid_lock);
%if large_address_space or vm_8192_segs or vm_65536_segs %then
    private := mst_$regions_active[asid] * mst_private_regions;
    if private <> [] then begin
      group := 0;
      for region := 0 to mst_private_a_regions - 1 do begin
        if region in mst_$regions_active[asid] then
          mst_$free_region(region, group, asid);
        group := group + 1;
      end;
      for region := mst_$seg_private_b div mst_region_segs to
                    mst_$seg_private_b_end div mst_region_segs do begin
        if region in mst_$regions_active[asid] then
          mst_$free_region(region, group, asid);
        group := group + 1;
      end;
    end;
%if not region_mmu %then
    mst_$unwire_page(addr(rars[rars_asid_base[asid]]));
    mmu_$rars_phaddr[asid] := 0;
%endif
%elseif run_time_layout %then
    private := mst_$regions_active[asid] -
      [region_$global_b .. region_$global_b + region_$global_b_size - 1,
       region_$global_a .. region_$global_a + region_$global_a_size - 1];
    if private <> [] then begin
      group := 0;
      for region := 0 to region_$private_a_size - 1 do begin
        if region in mst_$regions_active[asid] then
          mst_$free_region(region, group, asid);
        group := group + 1;
      end;
      for region := region_$private_b to region_$private_b do begin
        if region in mst_$regions_active[asid] then
          mst_$free_region(region, group, asid);
        group := group + 1;
      end;
    end;
%else
    mst_$unwire_asid_pages(mst_asid_base[asid],
                           rshft(mst_$seg_tn, 6) + mst_asid_base[asid]
                           - 1);
%endif
    mst_$set_clear(mst_$asid_list, mst_asid_none, asid);
    ml_$unlock(ml_$mst_asid_lock);
  end
  else begin
  crash:
    crash_system(status);
  end;
end;

{ TODO(pascal) MST_$FREE_ASID's frame with the large address space

  The image's frame is 40 bytes: the 32-byte set of the private regions
  at its bottom and 8 bytes above it that no instruction reaches.  dpc
  places the local private at the top of a 36-byte frame.  Whether the
  set is a compiler temporary below the homes of region and group, or a
  local after stand-ins, is still to be settled against dpc's layout. }

{ TODO(pascal) MST_$FREE_ASID's private regions with the layout chosen
  at boot

  dpc does not compile the set constructor with run-time ranges, nor
  the assignment of the 16-byte difference to the 32-byte set; the
  image forms both in 32-byte frame temporaries. }
