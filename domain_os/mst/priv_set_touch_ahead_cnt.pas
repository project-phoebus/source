{ MST_$PRIV_SET_TOUCH_AHEAD_CNT - set the touch-ahead count of the
  segments covering a range of the current address space.

  Image addresses:
    sau2  0x00E44514  MST_$PRIV_SET_TOUCH_AHEAD_CNT
    sau4  0x0F84C930  MST_$PRIV_SET_TOUCH_AHEAD_CNT
    sau8  0x03C4CAC2  MST_$PRIV_SET_TOUCH_AHEAD_CNT
    sau9  0x3C44BC4A  MST_$PRIV_SET_TOUCH_AHEAD_CNT

  - The count's code selects n: a query, the system's count, 32, one, or
    the count clamped to 1..32.  The range must lie in the address's
    region and its MST words have pages of MSTEs.
  - Under the ASID lock each segment's count is read and, unless the
    call is a query, set to n; the old count is returned.
  - An empty MST word returns an index as the old count; the illegal
    exits do not write it.

  Status stored:
    status_$ok: done
    status_$reference_to_illegal_address: the range is not mapped
}

{ TODO(pascal) MST_$PRIV_SET_TOUCH_AHEAD_CNT: dpc compiles the routine
  to the image's length with other registers; recheck the second half,
  the hoisted `n - 1' byte and MSTE_PAGES's address. }

procedure mst_$priv_set_touch_ahead_cnt(in privileged: boolean;
                                        in va: integer32;
                                        in length: integer32;
                                        in count: integer;
                                        out old_count: pinteger;
                                        out status: status_$t);
label
  illegal, unlock;
var
  st: status_$t;
  asid: pinteger;
  limit: pinteger;
  extra: pinteger;
  last: pinteger;
  base: pinteger;
  n: pinteger;
  old: pinteger;
  seg: pinteger;
  s: pinteger;
  i: pinteger;
  k: pinteger;
begin
  case count of
    mst_touch_ahead_query: begin
      n := 16#FFFF;
    end;
    mst_touch_ahead_system: begin
      n := mst_$touch_count;
    end;
    mst_touch_ahead_most: begin
      n := 32;
    end;
    mst_touch_ahead_one: begin
      n := 1;
    end;
    otherwise begin
      n := max(1, count);
      if n > 32 then n := 32;
    end;
  end;

  asid := mst_$va_to_segno(va, seg, proc1_$as_id);
  s := seg;
  if asid > 57 then goto illegal;
  if asid <> 0 then begin
    if s < mst_$private_a_size then
      limit := mst_$private_a_size - 1
    else begin
      if not privileged then goto illegal;
      limit := mst_$seg_tn - 1;
    end;
  end
  else if s < mst_$global_a_size then
    limit := mst_$global_a_size - 1
  else begin
    if not privileged then goto illegal;
    limit := mst_$seg_tn;
  end;

  extra := rshft(va - (va & (-16#8000)) + length - 1, 15);
  if s + extra > limit then begin
  illegal:
    status.all := status_$reference_to_illegal_address;
    return;
  end;

  last := extra + s;
  ml_$lock(ml_$mst_asid_lock);
  st.all := status_$ok;

  base := mst_asid_base[asid];
  old := rshft(s, 6) + base;
  for i := old to rshft(last, 6) + base do
    if mst[i] = 0 then begin
      st.all := status_$reference_to_illegal_address;
      goto unlock;
    end;

  for k := s to last do
    with mste_pages[mst[rshft(k, 6) + base]][k & 16#3F].page_info do begin
      old := n_pages_m1 + 1;
      if n = 16#FFFF then exit;
      n_pages_m1 := n - 1;
    end;

unlock:
  ml_$unlock(ml_$mst_asid_lock);
  old_count := old;
  status := st;
end;
