{ MST_$FREE_ASID - tear down an address space's mappings and free its
  ASID.

  Image addresses:
    sau2  0x00E74B3C  MST_$FREE_ASID
    sau9  0x3C47C616  MST_$FREE_ASID

  - The private A and then the private B segments are unmapped; then
    the areas are freed and, under the ASID lock, the pages behind the
    MST words given back and the ASID cleared from MST_$ASID_LIST.
  - With the large address space the active private regions are freed
    instead (mst_$free_region), and the ASID's RARS page given back.
  - A failed unmap crashes the system.

  Status stored:
    status_$ok: freed (MST_$UNMAP_PRIVI's)
}

[section(proc2_delete_pro, data$)]
procedure mst_$free_asid(asid: integer; out status: status_$t);
label
  crash;
%if large_address_space %then
var
  private: mst_region_set_t;
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
%if large_address_space %then
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
    mst_$unwire_page(addr(rars[rars_asid_base[asid]]));
    mmu_$rars_phaddr[asid] := 0;
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
