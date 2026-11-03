{ MST_$MAP_AREA_AT - create a VM area and map it at a given address.

  Image addresses:
    sau2  0x00E43C04  MST_$MAP_AREA_AT
    sau8  0x03C4BE08  MST_$MAP_AREA_AT
    sau9  0x3C44AFC6  MST_$MAP_AREA_AT

  - MST_$MAP_AREA with the caller's address as the hint, and no result.

  Status stored:
    AREA_$CREATE's or mst_$alloc_segs' status: in either case
}

procedure mst_$map_area_at(in va: integer32; in virt_size: integer32;
                           in commit_size: integer32;
                           in reversed: boolean;
                           out area_uid: uid_$t;
                           out status_ret: status_$t);
var
  { The image's offsets (the header). }
  uid: uid_$t;
  handle: integer32;
  del_status: status_$t;
  map_info: integer32;
  start: integer32;
begin
  handle := area_$create(virt_size, commit_size, reversed,
                         status_ret);
  if status_ret.all <> status_$ok then
    return;
  uid.high := anon_$uid.high;
  uid.low := handle;
  start := 0;
  if reversed then
    start := 16#7FFFFFFF - (virt_size - 1);
  discard(mst_$alloc_segs(va, uid, start, virt_size, 0,
                          proc1_$as_id, 7, 1, false, false,
                          map_info, status_ret));
  if status_ret.all <> status_$ok then
    area_$delete(area_$handle_t(handle), del_status)
  else
    area_uid := uid;
end;
