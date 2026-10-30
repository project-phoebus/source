{ MST_$INVALIDATE - discard the pages behind a range of private address
  space.

  Image addresses:
    sau2  0x00E441CA  MST_$INVALIDATE
    sau9  0x3C44B7E4  MST_$INVALIDATE

  - Under the ASID lock every segment of the range must map the
    caller's object (any for UID_$NIL) with protection 6 or 7, in
    consecutive object segments; the first entry fixes the object.
  - With the large address space the range must end below the top 8
    segments of private B; with the large VM layout the protection test
    is the segment map entry's write protect.
  - Partial pages are cleared (if zero_flag), whole ones invalidated
    through AREA_$INVALIDATE or AST_$INVALIDATE.
  - A length of 1 fails; only the first MSTE fixes the object; the head
    and tail clears run in opposite orders.

  Status stored:
    status_$ok: invalidated, or a zero length
    status_$mst_invalid_length: the range is empty or wraps
    status_$reference_to_illegal_address: out of private space, or a
      segment with no MSTE
    status_$mst_insufficient_rights: another protection
    status_$mst_uid_mismatch: another object, or a gap
    the invalidation's status: AREA_$INVALIDATE or AST_$INVALIDATE
}

procedure mst_$invalidate(in va: linteger; in length: integer32;
                          in uid: uid_$t; in zero_flag: boolean;
                          out status: status_$t);
const
  prot_a = 6;
  prot_b = 7;
type
  byte_ptr_t = ^mst_byte_t;
  long_ptr_t = ^integer32;
label
  illegal, no_entry, mismatch;
var
  uid_copy: uid_$t;
  area_handle: area_$handle_t;
  cur_va: linteger;
  st: status_$t;
  end_va: linteger;
  start_page: linteger;
  len: integer32;
  chunk: integer32;
  unused_30: array[1..3] of integer32;    { stand-in }
  seg_hi: pinteger;
  seg_lo: pinteger;
  is_area: boolean;
  first: boolean;
  zero: boolean;
  asid: pinteger;
  asid_hi: pinteger;
  slot: pinteger;
  last_slot: pinteger;
  base: integer;
  dir_index: integer;
  obj_seg: pinteger;
  next_seg: pinteger;
  prot: pinteger;
  i: integer;
%if large_vm %then
  smap: ^mst_smap_t;
%endif
begin
  uid_copy := uid;
  zero := zero_flag;
  is_area := false;
  if length = 0 then begin
    status.all := status_$ok;
    return;
  end;
  cur_va := va;
  end_va := cur_va + length - 1;
  if end_va <= cur_va then begin
    status.all := status_$mst_invalid_length;
    return;
  end;
%if large_address_space %then
  if lshft(linteger(mst_unmap_privi_first_refused), 15) <= end_va then
    goto illegal;
%else
  if lshft(linteger(mst_$seg_private_b), 15) <= end_va then
    goto illegal;
%endif
  asid := mst_$va_to_segno(cur_va, seg_lo, proc1_$as_id);
  slot := seg_lo;
  asid_hi := mst_$va_to_segno(end_va, seg_hi, proc1_$as_id);
  last_slot := seg_hi;
  if (asid > mst_max_asid) or else (asid <> asid_hi)
     or else (slot > last_slot) then begin
  illegal:
    status.all := status_$reference_to_illegal_address;
    return;
  end;

  st.all := status_$ok;
  ml_$lock(ml_$mst_asid_lock);
  first := true;
  base := mst_asid_base[asid];
  repeat
    dir_index := (slot div 64) + base;
    if mst[dir_index] = 0 then goto no_entry;
    with mste_pages[mst[dir_index]][slot & 16#3F] do begin
      if uid.high = 0 then begin
      no_entry:
        st.all := status_$reference_to_illegal_address;
        exit;
      end;
      if (uid_$nil <> uid_copy) and then (uid <> uid_copy) then
        goto mismatch;
%if large_vm %then
      smap := addr(smaps[slot + smap_asid_base[asid]]);
      if 2 in smap^.flags then begin
        st.all := status_$mst_insufficient_rights;
        exit;
      end;
%else
      prot := flags.prot;
      if (prot <> prot_a) and then (prot <> prot_b) then begin
        st.all := status_$mst_insufficient_rights;
        exit;
      end;
%endif
      if first then begin
        first := false;
        if uid.high = anon_$uid.high then begin
          is_area := true;
          area_handle := handle;
        end;
        obj_seg := area_id;
        next_seg := obj_seg;
        if is_area and then
           (area_$f_reversed in
            areas[area_handle.area_id].flags) then
          start_page := lshft(16#FFFF - linteger(next_seg), 5)
                        + (rshft(cur_va, 10) & 16#1F)
        else
          start_page := lshft(linteger(next_seg), 5)
                        + (rshft(cur_va, 10) & 16#1F);
      end
      else begin
        next_seg := next_seg + 1;
        if next_seg <> area_id then begin
        mismatch:
          st.all := status_$mst_uid_mismatch;
          exit;
        end;
      end;
    end;
    slot := slot + 1;
  until slot > last_slot;
  ml_$unlock(ml_$mst_asid_lock);
  status := st;
  if st.all <> status_$ok then return;

  len := length;
  chunk := cur_va & 16#3FF;
  if chunk <> 0 then begin
    chunk := 16#400 - chunk;
    if chunk > len then chunk := len;
    if zero then begin
      for i := 1 to chunk mod 4 do begin
        byte_ptr_t(cur_va)^ := 0;
        cur_va := cur_va + 1;
      end;
      for i := 1 to chunk div 4 do begin
        long_ptr_t(cur_va)^ := 0;
        cur_va := cur_va + 4;
      end;
    end
    else
      cur_va := cur_va + chunk;
    start_page := start_page + 1;
    if (start_page & 16#1F) = 0 then
      obj_seg := obj_seg + 1;
    len := len - chunk;
  end;
  if len = 0 then return;

  chunk := rshft(len, 10);
  if chunk <> 0 then begin
    if is_area then
      area_$invalidate(area_handle, obj_seg, start_page & 16#1F,
                       chunk, zero, st)
    else
      ast_$invalidate(uid_copy, start_page, chunk, zero, st);
    if st.all <> status_$ok then begin
      status := st;
      return;
    end;
  end;

  if zero then begin
    len := len & 16#3FF;
    if len <> 0 then begin
      cur_va := cur_va + lshft(chunk, 10);
      for i := 1 to len div 4 do begin
        long_ptr_t(cur_va)^ := 0;
        cur_va := cur_va + 4;
      end;
      for i := 1 to len mod 4 do begin
        byte_ptr_t(cur_va)^ := 0;
        cur_va := cur_va + 1;
      end;
    end;
  end;
end;
