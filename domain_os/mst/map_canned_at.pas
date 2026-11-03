{ MST_$MAP_CANNED_AT - map a canned (boot-time) object at a fixed
  global address.

  Image addresses:
    sau2  0x00E30FAA  MST_$MAP_CANNED_AT
    sau4  0x0F8346A0  MST_$MAP_CANNED_AT
    sau8  0x03C342C2  MST_$MAP_CANNED_AT
    sau9  0x3C437052  MST_$MAP_CANNED_AT

  - The object's segments offset .. offset + size - 1 go to ASID 0's
    segments from va onwards; every MSTE of the run must be free (or,
    with touch, hold a UID whose first byte is 0).
  - mst_$set_mstes fills the run.
  - With the large VM layout and touch, the object's segment is
    activated and wired, and threaded, once for each segment of the run.
  - For the paging file the run's segment map entries point at the
    page map.  The address translation cache is purged at the end.
  - That arm activates and threads the run's first segment on every
    pass; only the segment map entry follows the run.

  Status stored:
    status_$ok: mapped
    status_$reference_to_illegal_address: an ASID over 57
    status_$mst_no_space_available: an MSTE in use
    AST_$ACTIVATE_AND_WIRE's status: the large VM arm's activation
      failed
}

[section(os_init_proc, os_init_data)]
procedure mst_$map_canned_at(va: integer32; in uid: uid_$t;
                             offset: integer32; size: integer32;
                             flags: univ mst_$canned_flags_t;
                             wire: boolean; touch: boolean;
                             desc: integer32; out status: status_$t);
var
  unused_6: integer;                      { stand-in (below dpc's
                                            `with' slot) }
  seg: pinteger;
  first: pinteger;
  n: pinteger;
  obj_seg: pinteger;
  last: pinteger;
  i: pinteger;
  unused_18: array[1..3] of integer;      { stand-in }
%if large_vm %then
  asid: pinteger;
  aste: ast_$aste_ptr_t;
%endif
begin
  obj_seg := rshft(offset, 15);
  n := rshft(offset + size - 1, 15) - obj_seg + 1;
%if large_vm %then
  asid := mst_$va_to_segno(va, seg, mst_asid_none);
  if asid > mst_max_asid then begin
%else
  if mst_$va_to_segno(va, seg, mst_asid_none) > mst_max_asid then begin
%endif
    status.all := status_$reference_to_illegal_address;
    return;
  end;
  first := seg;
  last := n + first - 1;
  for i := first to last do
    with mste_pages[mst[i div 64 + mst_asid_base[0]]][i & 63] do
      if uid_high <> 0 then
        if not ((first_byte = 0) and touch) then begin
          status.all := status_$mst_no_space_available;
          return;
        end;
  mst_$set_mstes(uid, obj_seg, desc, first, last,
                 flags.touch_count, 0, flags.prot, wire);
%if large_vm %then
  if touch then
    for i := first to last do begin
      aste := ast_$activate_and_wire(uid, obj_seg, status);
      if status.all <> status_$ok then return;
      { the first segment's thread, on every pass }
      bst[first + bst_asid_base[asid]] :=
        mst_$pmap_link_t(aste^.pmap_link);
      aste^.pmap_link.asid := asid;
      aste^.pmap_link.seg := first;
      if uid = network_$paging_file_uid then
%if region_mmu %then
        smaps[i + smap_asid_base[0]].e.pmap_pa := aste^.pmap_pa;
%else
        smaps[i + smap_asid_base[0]].table :=
          (smaps[i + smap_asid_base[0]].table & 15) + aste^.pmap_pa;
%endif
    end;
  mmu_$purge;
%endif
  status.all := status_$ok;
end;

{ TODO(pascal) MST_$MAP_CANNED_AT's frame

  The SAU2 image's frame addresses only seg; the stand-ins unused_6 and
  unused_18 place it.  dpc's frame is still 4 bytes larger, and its
  loop is not the image's strength-reduced one.  The SAU9 image's frame
  is 4 bytes larger than the SAU2's and also holds obj_seg, last and
  the run's count, which dpc keeps in registers. }
