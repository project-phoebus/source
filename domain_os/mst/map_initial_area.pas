{ MST_$MAP_INITIAL_AREA - map a new process's initial area, an anonymous
  area of its parent's, into the new address space.

  Image addresses:
    sau2  0x00E42E9E  MST_$MAP_INITIAL_AREA
    sau4  0x0F84AF58  MST_$MAP_INITIAL_AREA
    sau8  0x03C4B074  MST_$MAP_INITIAL_AREA
    sau9  0x3C44A24E  MST_$MAP_INITIAL_AREA

  - The parent's anonymous area is moved to the new ASID at the
    descriptor's segment (AREA_$TRANSFER) and mapped there.
  - With the large address space the new ASID's BST page for that
    segment is installed first, if it has none.
  - If asked, the old segment's first 32 KB are unmapped from the
    current address space.

  Status stored:
    status_$mst_uid_not_vm_area: the parent's UID is not anonymous
    AREA_$TRANSFER's or mst_$alloc_segs' status: otherwise
}

procedure mst_$map_initial_area(code_desc: integer32; asid: integer;
                                var parent_uid: uid_$t;
                                map_param: integer32;
                                area_kind: integer;
                                touch: boolean;
                                out status: status_$t);
var
  map_info: integer32;
  unused_8: integer32;                    { stand-in }
  unmap_status: status_$t;
  seg: 0..32767;
  new_seg: pinteger;
begin
  if parent_uid.high <> anon_$uid.high then
    status.all := status_$mst_uid_not_vm_area
  else begin
    seg := rshft(code_desc, 15);
%if vm_regions %then
    if not (seg div 256 in mst_$bst_pages[asid]) then begin
      discard(mst_$init_table_page(linteger(
        addr(bst[lshft(seg div 256, 8) + bst_asid_base[asid]]))));
      mst_$bst_pages[asid] := mst_$bst_pages[asid] + [seg div 256];
    end;
%endif
    new_seg := area_$transfer(parent_uid.low, asid, seg, map_param,
                              status);
    if status.all = status_$ok then begin
      discard(mst_$alloc_segs(code_desc, parent_uid, 0, map_param, 0,
                              asid, area_kind, mst_$touch_count, false,
                              false, map_info, status));
      if touch then
        mst_$unmap_privi(0, parent_uid, lshft(new_seg, 15), 32768,
                         proc1_$as_id, unmap_status);
    end;
  end;
end;

{ TODO(pascal) MST_$MAP_INITIAL_AREA's four unaddressed frame bytes

  Nothing addresses the four bytes below map_info, and no register-held
  local is left to have its home there.  The stand-in unused_8 keeps
  the image's frame. }
