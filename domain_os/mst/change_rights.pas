{ MST_$CHANGE_RIGHTS - remap a range of the current address space with
  new access rights.

  Image addresses:
    sau2  0x00E42FB0  MST_$CHANGE_RIGHTS
    sau4  0x0F84B0A6  MST_$CHANGE_RIGHTS
    sau8  0x03C4B1BE  MST_$CHANGE_RIGHTS
    sau9  0x3C44A3C6  MST_$CHANGE_RIGHTS

  - The address's MSTE gives the object, its offset, the wired flag and
    the touch count; the range is unmapped (if mapped to that object)
    and mapped again with the new rights.
  - If either step fails, it is mapped again with the old rights as the
    super-user.
  - The offset is formed in word arithmetic, keeping only bit 0 of the
    area segment.

  Status stored:
    status_$ok: remapped
    MST_$VA_TO_PTE's status: no MSTE (its code not 0)
    the unmap's or the new mapping's status: that step failed
}

procedure mst_$change_rights(in va: integer32; in length: integer32;
                             in rights: integer;
                             out status: status_$t);
var
  uid: uid_$t;
  map_info: integer32;
  entry: mst_entry_ptr_t;
  restore_status: status_$t;
  touch_count: pinteger;
  offset: pinteger;
  prot: pinteger;
  access: boolean;
  unused_20: integer32;                   { stand-in }
begin
  mst_$va_to_pte(proc1_$as_id, va, prot, entry, status);
  if status.code = 0 then begin
    uid := entry^.uid;
    offset := lshft(entry^.area_id, 15) + (va & 16#7FFF);
    access := 15 in entry^.flags.bits;
    touch_count := entry^.page_info.n_pages_m1 + 1;
    mst_$unmap_privi(mst_unmap_match_uid, uid, va, length,
                     proc1_$as_id, status);
    if status.all = status_$ok then begin
      discard(mst_$alloc_segs(va, uid, offset, length, 0, proc1_$as_id,
                              rights, touch_count, access, false,
                              map_info, status));
      if status.all = status_$ok then
        return;
    end;
    acl_$enter_super;
    discard(mst_$alloc_segs(va, uid, offset, length, 0, proc1_$as_id,
                            prot, touch_count, access, false, map_info,
                            restore_status));
    acl_$exit_super;
  end;
end;

{ TODO(pascal) MST_$CHANGE_RIGHTS's four unaddressed frame bytes

  Nothing addresses the frame's last four bytes; the stand-in unused_20
  keeps the image's frame.  What the original declared there is not
  known. }
