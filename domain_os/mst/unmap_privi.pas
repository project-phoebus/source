{ MST_$UNMAP_PRIVI - unmap a range of segments of an address space.

  Image addresses:
    sau2  0x00E448B0  MST_$UNMAP_PRIVI
    sau4  0x0F84CCB4  MST_$UNMAP_PRIVI
    sau8  0x03C4CE48  MST_$UNMAP_PRIVI
    sau9  0x3C44BFC6  MST_$UNMAP_PRIVI

  - The range must lie in one address space (below private B unless the
    mode allows any segment).  Under the ASID lock each segment with an
    MSTE is unmapped through AREA_$REMOVE_SEG or MST_$REMOVE_SEG.
  - The entry loses its ASTE index and is freed, or, with
    mst_unmap_keep_entry, kept and marked unmapped.
  - With the regions a freed entry counts its segment group
    down in MST_$SEGS_MAPPED (a count already zero crashes the system);
    a private group that reaches zero has its region freed.
  - A missing page-table page skips a whole 64-segment block; the range
    errors return before the lock is taken.

  Status stored:
    status_$ok: unmapped
    status_$mst_invalid_length: the range wraps
    status_$reference_to_illegal_address: out of the address space
    status_$mst_object_is_not_mapped: another object, or a missing page
      with mst_unmap_match_uid
    status_$mst_uid_not_vm_area: a non-area entry with
      mst_unmap_areas_only
    AREA_$REMOVE_SEG's status: the last area segment's removal
}

procedure mst_$unmap_privi(mode: integer; want_uid: uid_$t;
                           start: integer32; size: integer32;
                           asid: integer; out status: status_$t);
label
  illegal, not_mapped, next;
var
%if not vm_regions %then
  unused_80: array[1..32] of integer32;   { stand-in }
%endif
  result: status_$t;
  va: linteger;
  end_va: linteger;
  seg: pinteger;
%if vm_regions %then
  region: mst_region_t;
%endif
  segno: pinteger;
  last_seg: pinteger;
  first_seg: pinteger;
  end_segno: pinteger;
  base: integer;
  is_anon: boolean;
%if vm_regions %then
  group: pinteger;
%endif
begin
  va := linteger(start) & 16#FFFF8000;
%if large_address_space or vm_8192_segs %then
  if ((mode & mst_unmap_any_seg) = 0) and then
     (rshft(va, 15) >= mst_unmap_privi_first_refused) then
    goto illegal;
%elseif run_time_layout %then
  if ((mode & mst_unmap_any_seg) = 0) and then
     (rshft(va, 15) >= linteger(mst_$seg_private_b) + mst_b_space_first)
  then
    goto illegal;
%else
  if ((mode & mst_unmap_any_seg) = 0) and then
     (rshft(va, 15) >= linteger(mst_$seg_private_b)) then
    goto illegal;
%endif
  end_va := linteger(start) + linteger(size);
  if end_va <= linteger(start) then begin
    status.all := status_$mst_invalid_length;
    return;
  end;
  segno := mst_$va_to_segno(va, first_seg, asid);
  seg := first_seg;
  end_segno := mst_$va_to_segno(end_va - 1, last_seg, asid);
  if (segno > mst_max_asid) or else (segno <> end_segno) then begin
  illegal:
    status.all := status_$reference_to_illegal_address;
    return;
  end;

  ml_$lock(ml_$mst_asid_lock);
  result.all := status_$ok;
  base := mst_asid_base[segno];
  while seg <= last_seg do begin
    if mst[(seg div 64) + base] <> 0 then begin
      with mste_pages[mst[(seg div 64) + base]][seg & 16#3F] do begin
        if ((mode & mst_unmap_match_uid) <> 0) and then
           (uid <> want_uid) then
          goto not_mapped;
        if uid.high = 0 then goto next;
        is_anon := uid.high = anon_$uid.high;
        if ((mode & mst_unmap_areas_only) <> 0) and then
           not is_anon then begin
          result.all := status_$mst_uid_not_vm_area;
          exit;
        end;
        if is_anon then
          area_$remove_seg(handle, segno, seg,
                           (mode & mst_unmap_keep_entry) = 0,
                           area_id, result)
        else
          mst_$remove_seg(as_ast, va, seg, segno,
                          page_info.n_pages_m1 = 31);
        flags.aste_idx := 0;
        if (mode & mst_unmap_keep_entry) <> 0 then
          flags.bits := flags.bits + [14]
%if vm_regions %then
        else begin
          uid.high := 0;
          group := seg div mst_region_segs;
          if mst_$segs_mapped[segno][group] = 0 then
            crash_system(status_$mst_invalid_segment_count);
          mst_$segs_mapped[segno][group] :=
            mst_$segs_mapped[segno][group] - 1;
          if (mst_$segs_mapped[segno][group] = 0) and then
             (segno <> 0) then begin
%if run_time_layout %then
            if group >= region_$private_a_size then
              region := group + (region_$private_b -
                                 region_$private_a_size)
            else
              region := group;
%else
            if group >= mst_private_a_regions then
              region := group + mst_global_a_regions
            else
              region := group;
%endif
            mst_$free_region(region, group, segno);
          end;
        end;
%else
        else
          uid.high := 0;
%endif
      end;
    next:
      va := va + 16#8000;
      seg := seg + 1;
    end
    else begin
      if (mode & mst_unmap_match_uid) <> 0 then begin
      not_mapped:
        result.all := status_$mst_object_is_not_mapped;
        exit;
      end;
      seg := seg + (64 - (seg & 16#3F));
      va := va + lshft(64 - linteger(seg & 16#3F), 15);
    end;
  end;
%if pmmu_page_maps %then
  mmu_$purge;
%endif
  ml_$unlock(ml_$mst_asid_lock);
  status := result;
end;

{ TODO(pascal) MST_$UNMAP_PRIVI's frame holes

  The image's frame leaves 128 bytes above the UID's copy and 12 below
  result and first_seg that nothing addresses: too many for the six
  register-held locals' homes.  The stand-in unused_80 keeps result,
  last_seg and first_seg at the image's places. }
