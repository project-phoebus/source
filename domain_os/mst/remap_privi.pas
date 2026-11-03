{ MST_$REMAP_PRIVI - unmap a range and map the object that backed its
  first segment again, privileged or not.

  Image addresses:
    sau2  0x00E43A0C  MST_$REMAP_PRIVI
    sau8  0x03C4BC12  MST_$REMAP_PRIVI
    sau9  0x3C44ADD4  MST_$REMAP_PRIVI

  - The address's MSTE gives the object, the wired flag, the touch count
    and the protection.  Privileged (flag bit 0), the range is unmapped
    in any segment mapped to the object; unprivileged, only where it is.
  - The object is mapped again from the top as the super-user (ASID 0
    for global B when privileged); the result is its address.
  - The first status test checks only the code word.

  Status stored:
    MST_$VA_TO_PTE's status: no MSTE (its code not 0)
    the unmap's or mst_$alloc_segs' status: otherwise
}

function mst_$remap_privi(in flags: integer; in va: integer32;
                          in unmap_len: integer32; in offset: integer32;
                          in length: integer32; out map_info: integer32;
                          var status: status_$t): univ_ptr;
var
  uid: uid_$t;
  entry: mst_entry_ptr_t;
  asid: integer;
  mode: integer;
  touch_count: pinteger;
  prot: pinteger;
  privileged: boolean;
  wired: boolean;
  unused_20: integer32;                   { stand-in, see the TODO }
begin
  mst_$remap_privi := nil;
  map_info := 0;
  mst_$va_to_pte(proc1_$as_id, va, prot, entry, status);
  if status.code <> 0 then
    return;
  uid := entry^.uid;
  wired := 15 in entry^.flags.bits;
  touch_count := entry^.page_info.n_pages_m1 + 1;
  privileged := mst_remap_privileged in
                mst_remap_flags_t(flags);
  if privileged then begin
    if linteger(rshft(va, 15)) < mst_$seg_global_b then
      asid := proc1_$as_id
    else
      asid := 0;
    mode := mst_unmap_any_seg + mst_unmap_match_uid;
  end
  else begin
    asid := proc1_$as_id;
    mode := mst_unmap_match_uid;
  end;
  mst_$unmap_privi(mode, uid, va, unmap_len, proc1_$as_id,
                   status);
  if status.all <> status_$ok then
    return;
  acl_$enter_super;
  mst_$remap_privi := mst_$alloc_segs(16#7FFFFFFF, uid,
                                      offset, length, 0, asid, prot,
                                      touch_count, wired, privileged,
                                      map_info, status);
  acl_$exit_super;
end;

{ TODO(pascal) MST_$REMAP_PRIVI's last frame longword holds nothing

  The image's frame ends with 4 bytes below wired that no instruction
  addresses, and they are not the result's.  The stand-in unused_20,
  the last local, holds the place. }

