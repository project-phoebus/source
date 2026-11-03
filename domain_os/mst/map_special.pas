{ MST_$MAP_SPECIAL - map an object's special segments into an address
  space.

  Image addresses:
    sau8  0x03C4C994  MST_$MAP_SPECIAL
    sau9  0x3C44BB18  MST_$MAP_SPECIAL

  - ASID 0 crashes the system.
  - Under the ASID lock, count segments from special segment seg (the
    top 16 of private B) get pages of MSTEs and obj_uid.
  - An entry holding SPECIAL_SEG_$UID is left alone; any other used
    entry stops the mapping.
  - Each entry filled counts in its group's MST_$SEGS_MAPPED.
  - The result is special segment seg's address.
  - An entry's object segment is its MST segment plus its place in the
    run; the result is not written when the mapping fails, nor, for a
    count of 0, the status.

  Status stored:
    status_$ok: mapped (mst_$alloc_table_page's)
    mst_$alloc_table_page's result: no page for the MSTEs
    status_$mst_no_space_available: a segment of the run is in use
}

function mst_$map_special(in seg: pinteger; in count: integer;
                          in obj_uid: uid_$t; in asid: integer;
                          out status_ret: status_$t): univ_ptr;
label
  done;
var
  s: pinteger;
  i: integer;
begin
  if asid = 0 then
    crash_system(status_$mst_asid_0_illegal);
  ml_$lock(ml_$mst_asid_lock);
%if large_address_space %then
  s := seg + (mst_$seg_global_b_offset - mst_special_segs);
%elseif run_time_layout %then
  s := mst_$private_a_size + seg + (mst_private_b_count - mst_special_segs);
%endif
  for i := 0 to count - 1 do begin
    status_ret := mst_$alloc_table_page(asid, s,
                    mst[mst_asid_base[asid] + s div 64]);
    if status_ret.all <> status_$ok then goto done;
    with mste_pages[mst[mst_asid_base[asid] + s div 64]][s & 63] do
      if uid_high <> special_seg_$uid.high then begin
        if uid_high <> 0 then begin
          status_ret.all := status_$mst_no_space_available;
          goto done;
        end;
        uid := obj_uid;
        { the run's place added to the MST segment }
        area_id := s + i;
        flags.bits := [];
        mst_$segs_mapped[asid][s div mst_region_segs] :=
          mst_$segs_mapped[asid][s div mst_region_segs] + 1;
      end;
    s := s + 1;
  end;
%if large_address_space %then
  mst_$map_special := univ_ptr(lshft(seg, 15) +
                        lshft(mst_$seg_global_b - mst_special_segs, 15));
%elseif run_time_layout %then
  mst_$map_special := univ_ptr(lshft(seg, 15) + special_$seg);
%endif
done:
  ml_$unlock(ml_$mst_asid_lock);
end;
