{ mst_$alloc_segs - find room for a mapping in an address space and fill
  its MSTEs; with its nested mst_$audit_map.

  Image addresses:
    sau2  0x00E430D0  mst_$audit_map (nested)
    sau2  0x00E43182  mst_$alloc_segs (module-local)
    sau4  0x0F84B1C6  mst_$audit_map (nested)
    sau4  0x0F84B278  mst_$alloc_segs (module-local)
    sau8  0x03C4B2DC  mst_$audit_map (nested)
    sau8  0x03C4B38E  mst_$alloc_segs (module-local)
    sau9  0x3C44A4E4  mst_$audit_map (nested)
    sau9  0x3C44A596  mst_$alloc_segs (module-local)

  - The MST_$MAP* wrappers' worker: it sizes the mapping, picks the
    segment range, and under the ASID lock searches the segment table
    for a run of free MSTEs (backing missing MST pages).
  - It threads an anonymous area's BSTEs, fills the MSTEs
    (mst_$set_mstes) and returns the mapping's virtual address.
  - With the large address space or the 8192 segments a private
    B-space mapping goes in the top 8 segments of private B.
  - The result is written on the success path only; an anonymous area's
    location has only bit 31 set.

  Status stored:
    status_$ok: mapped
    status_$mst_object_not_found: a bad or inactive anonymous area
    status_$mst_invalid_length: the range lies outside the object
    status_$mst_no_space_available: no free run of MSTEs
    status_$reference_to_illegal_address: a fixed address outside its
      space
    the callee's status: mst_$lookup_object, a table page or
      AREA_$THREAD_BSTES failed
}

function mst_$alloc_segs(addr_hint: integer32; in uid: uid_$t;
                         start_va: linteger; length: integer32;
                         area_size: integer32; asid: integer;
                         prot: integer; touch_count: pinteger;
                         wired: boolean; b_space: boolean;
                         out map_info: integer32;
                         out status: status_$t): univ_ptr;

var
  { The register-held locals are declared at the holes they take in
    dpc's layout.  dpc puts the function's result at the
    frame's top, so first_seg takes the image's result slot here. }
  handle: area_$handle_t;
  st: status_$t;
  location: mst_location_t;
  mapped: linteger;
  last: linteger;
  obj_len: linteger;
  first_seg: linteger;
  count: pinteger;
  limit: pinteger;
  lo: pinteger;
  end_seg: pinteger;
  cur: pinteger;
  target: pinteger;
  base: pinteger;
  s: pinteger;
  obj_seg: pinteger;
  unused_34: integer;                     { stand-in }
  all_free: boolean;
  last_seg: linteger;

label
  bad_length, illegal, sized, unlock, out;

  { mst_$audit_map - log a private anonymous mapping unless it succeeded
    in an area of the current address space.

    - Nested in mst_$alloc_segs: it reads the parent's status, handle and
      protection through its static link.

    Status stored: none.
  }
  procedure mst_$audit_map;
  var
    unused_08: integer32;                   { stand-in (above it dpc's static
                                              link slot) }
    data: array[1..4] of integer;
    event: uid_$t;
    unused_1e: array[1..3] of integer;      { stand-in }
    data_len: pinteger;
    flag: pinteger;
    unused_24: integer;                     { stand-in }
  begin
    if (status.all <> status_$mst_object_not_found) and then
       (areas[handle.area_id].owner_asid = proc1_$as_id) then
      return;
    data_len := 8;
    event.high := 16#00040022;
    event.low := 0;
    if status.all = status_$ok then flag := 0
    else flag := 1;
    data[1] := handle.area_id;
    data[2] := handle.generation;
    data[3] := areas[handle.area_id].owner_asid;
    data[4] := prot;
    audit_$log_event(event, flag, status, data, data_len);
  end;

begin
  { the length test }
  if length = 0 then goto bad_length;

  { last, the range's last byte rounded up to its segment's end }
  last := (start_va + length - 1) ! 16#7FFF;
  if not (last > start_va) then last := linteger(-1);

  { an anonymous UID }
  if uid.high = anon_$uid.high then begin
    handle := mst_anon_uid_t(uid).handle;
    { the area entry's tests }
    if (handle.area_id = 0) or else
       (handle.area_id > area_max_entries) then begin
      status.all := status_$mst_object_not_found;
      goto out;
    end;
    with areas[handle.area_id] do begin
      if not (area_$f_active in flags) or else
         (handle.generation <> generation) then begin
        status.all := status_$mst_object_not_found;
        goto out;
      end;
      st.all := status_$ok;
      location.bits := location.bits - [31];
      { a reversed area's clamps }
      if area_$f_reversed in flags then begin
        if last > 16#7FFFFFFF then last := 16#7FFFFFFF;
        if start_va > last then goto bad_length;
        if not wired then
          if 16#7FFFFFFF - (virt_size - 1) > start_va then
            goto bad_length;
        goto sized;
      end;
      { the area's size (the image keeps it in a register, the named object's path loads it from the frame) }
      obj_len := virt_size;
    end;
  end
  else begin
    { a named UID }
    mst_$lookup_object(uid, prot, area_size, location.all, obj_len, st);
    if st.all <> status_$ok then begin
      status := st;
      goto out;
    end;
  end;

  { unless wired: the object-size clamps }
  if not wired then begin
    if obj_len <= start_va then goto bad_length;
    if last >= obj_len then last := obj_len - 1;
  end;

sized:
  { the mapped length and the segment numbers }
  mapped := last - start_va + 1;
  last_seg := rshft(last, 15);
  if last_seg > 16#FFFF then goto bad_length;
  first_seg := rshft(start_va, 15);
  if first_seg > 16#FFFF then begin
bad_length:
    status.all := status_$mst_invalid_length;
    goto out;
  end;

  obj_seg := first_seg;
  count := last_seg - first_seg + 1;
  target := rshft(addr_hint, 15);

  if (addr_hint = 0) or else (addr_hint = 16#7FFFFFFF) then begin
    { the search window [lo, limit) }
    if asid = 0 then begin
      if not b_space then begin
        lo := 0;
        limit := mst_$global_a_size;
      end
      else begin
        lo := mst_$global_a_size;
        limit := mst_$seg_high - mst_$seg_global_b_offset;
      end;
    end
    else if b_space then begin
%if large_address_space or vm_8192_segs %then
      lo := mst_$seg_tn - mst_b_space_segs;
%elseif run_time_layout %then
      lo := mst_$private_a_size + mst_b_space_first;
%else
      lo := mst_$private_a_size;
%endif
      limit := mst_$seg_tn;
    end
    else begin
      lo := 0;
      limit := mst_$private_a_size;
    end;
    if limit - lo < count then begin
      status.all := status_$mst_no_space_available;
      goto out;
    end;
  end
  else begin
    { a fixed address }
    limit := target + count - 1;
    if target > limit then goto illegal;
    if (target <= mst_$seg_private_a_end) and then
       (limit <= mst_$seg_private_a_end) then
      lo := target
    else if (target >= mst_$seg_global_a) and then
            (target <= mst_$seg_global_a_end) and then
            (limit <= mst_$seg_global_a_end) then begin
      lo := target - mst_$seg_global_a;
      limit := limit - mst_$seg_global_a;
      asid := 0;
    end
    else begin
illegal:
      status.all := status_$reference_to_illegal_address;
      goto out;
    end;
    limit := limit + 1;
  end;

  { the ASID lock, base }
  ml_$lock(ml_$mst_asid_lock);
  base := mst_asid_base[asid];

  if addr_hint = 16#7FFFFFFF then begin
    { ---- top-down ---- }
    lo := lo + count;
    end_seg := limit;
    repeat
      cur := end_seg - count;
      all_free := true;
      repeat
        if mst[rshft(cur, 6) + base] <> 0 then begin
          if mste_pages[mst[rshft(cur, 6) + base]][cur & 63].uid.high
             <> 0 then begin
            end_seg := cur;
            all_free := false;
            exit;
          end;
          cur := cur + 1;
        end
        else begin
          st := mst_$alloc_table_page(asid, cur, mst[rshft(cur, 6) + base]);
          if st.all <> status_$ok then goto unlock;
          cur := cur + (64 - (cur & 63));
        end;
      until cur >= end_seg;
      if all_free then exit;
    until lo > end_seg;
    cur := end_seg - count;
  end
  else begin
    { ---- bottom-up ---- }
    limit := limit - count;
    cur := lo;
    repeat
      s := count + cur;
      all_free := true;
      repeat
        s := s - 1;
        if mst[rshft(s, 6) + base] <> 0 then begin
          if mste_pages[mst[rshft(s, 6) + base]][s & 63].uid.high
             <> 0 then begin
            cur := s + 1;
            all_free := false;
            exit;
          end;
        end
        else begin
          st := mst_$alloc_table_page(asid, s, mst[rshft(s, 6) + base]);
          if st.all <> status_$ok then goto unlock;
          s := s - (s & 63);
        end;
      until s <= cur;
      if all_free then exit;
    until cur > limit;
  end;

  { nothing free }
  if not all_free then begin
    st.all := status_$mst_no_space_available;
    goto unlock;
  end;

  { an anonymous UID: AREA_$THREAD_BSTES }
  if uid.high = anon_$uid.high then begin
    area_$thread_bstes(handle, asid, cur, count, obj_seg, st);
    if st.all <> status_$ok then goto unlock;
  end;

  mst_$set_mstes(uid, obj_seg, location.all, cur, count + cur - 1,
                 touch_count, asid, prot, wired);

unlock:
  { the store's own flags serve the test }
  ml_$unlock(ml_$mst_asid_lock);
  status := st;
  if st.all <> status_$ok then goto out;

  { the three arms share one addition }
  if asid = 0 then begin
    if b_space then cur := cur + mst_$seg_global_b_offset
    else cur := cur + mst_$seg_global_a;
  end
  else if b_space then cur := cur + mst_$seg_private_b_offset;

  { the address and map_info }
  mst_$alloc_segs := univ_ptr((start_va & 16#7FFF) + lshft(cur, 15));
  map_info := mapped;

out:
  { the audit }
  if (asid <> 0) and then (uid.high = anon_$uid.high) and then
     audit_$enabled then
    mst_$audit_map;
end;

{ TODO(pascal) mst_$alloc_segs and mst_$audit_map against dpc

  Neither routine has a map symbol, so neither is measured against the
  image.  To recheck: mst_$audit_map's event stores and static-link
  register; mst_$alloc_segs' frame, its nine registers held across the
  searches, and its inner `exit's. }
