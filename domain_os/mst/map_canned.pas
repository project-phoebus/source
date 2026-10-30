{ MST_$MAP_CANNED - map a canned (boot-time) object at the top of
  global A, wherever it fits.

  Image addresses:
    sau2  0x00E30E6C  MST_$MAP_CANNED
    sau9  0x3C436F2C  MST_$MAP_CANNED

  - The search for (size + 32767) div 32768 free segments starts just
    below global B and moves down, backing MST words that have no page
    of MSTEs yet.
  - A free run is filled as MST_$MAP_CANNED_AT does and its virtual
    address returned.
  - MST_ASID_BASE[0] is divided by 64 before it is added.

  Status stored:
    status_$ok: mapped
    status_$mst_no_space_available: no run above global A's size
    mst_$alloc_table_page's result: no page for the MSTEs
}

[section(os_init_proc, os_init_data)]
function mst_$map_canned(in uid: uid_$t; size: integer32;
                         flags: univ mst_$canned_flags_t; wire: boolean;
                         desc: integer32; out status: status_$t): univ_ptr;
label
  next, found;
var
  idx: pinteger;
  asid: integer;
  seg: pinteger;
  base: pinteger;
  top: pinteger;
  n: pinteger;
  ga: pinteger;
  free: boolean;
begin
  status.all := status_$ok;
  asid := 0;
  ga := mst_$global_a_size;
  base := mst_asid_base[0] div 64;
  top := mst_$seg_high - mst_$seg_global_b_offset;
  n := (size + 32767) div 32768;
  if top - ga < n then begin
    status.all := status_$mst_no_space_available;
    return;
  end;
  repeat
    seg := top - n;
    free := true;
    repeat
      idx := seg div 64 + base;
      if mst[idx] <> 0 then begin
        with mste_pages[mst[idx]][seg & 63] do
          if uid_high <> 0 then begin
            top := seg;
            free := false;
            goto next;
          end
          else
            seg := seg + 1;
      end
      else begin
        status := mst_$alloc_table_page(asid, seg, mst[idx]);
        if status.all <> status_$ok then
          return;
        seg := seg + (64 - (seg & 63));
      end;
    until seg >= top;
    if free then
      goto found;
  next:
  until ga + n > top;
found:
  seg := top - n;
  if not free then
    status.all := status_$mst_no_space_available
  else
    mst_$set_mstes(uid, 0, desc, seg, seg + n - 1,
                   flags.touch_count, 0, flags.prot, wire);
  if status.all = status_$ok then begin
    seg := seg + mst_$seg_global_b_offset;
    mst_$map_canned := univ_ptr(lshft(seg, 15));
  end;
end;

{ TODO(pascal) MST_$MAP_CANNED's frame

  dpc's frame is 8 bytes larger than the image's (its `with' slot below
  free).  The routine has no caller to compare its use against. }
