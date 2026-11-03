{ MST_$MAP_AREA - create a VM area and map it anywhere in the current
  address space, from the top.

  Image addresses:
    sau2  0x00E43B3A  MST_$MAP_AREA
    sau8  0x03C4BD3E  MST_$MAP_AREA
    sau9  0x3C44AEFC  MST_$MAP_AREA

  - AREA_$CREATE makes the area; its handle becomes an anonymous
    object's UID, which mst_$alloc_segs maps from the top (protection 7,
    touch count 1).
  - A failed map deletes the area; else the UID goes back.  The result
    is the mapped address.
  - When AREA_$CREATE fails the result is not written.

  Status stored:
    AREA_$CREATE's or mst_$alloc_segs' status: in either case
}

function mst_$map_area(in virt_size: integer32; in commit_size: integer32;
                       in reversed: boolean; out uid_out: uid_$t;
                       out status: status_$t): univ_ptr;
var
  { The image's offsets (the header). }
  uid: uid_$t;
  handle: integer32;
  del_status: status_$t;
  va: univ_ptr;
  map_info: integer32;
  start: integer32;
begin
  handle := area_$create(virt_size, commit_size, reversed,
                         status);
  if status.all <> status_$ok then
    return;
  uid.high := anon_$uid.high;
  uid.low := handle;
  start := 0;
  if reversed then
    start := 16#7FFFFFFF - (virt_size - 1);
  va := mst_$alloc_segs(16#7FFFFFFF, uid, start, virt_size,
                        0, proc1_$as_id, 7, 1, false, false,
                        map_info, status);
  if status.all <> status_$ok then
    area_$delete(area_$handle_t(handle), del_status)
  else
    uid_out := uid;
  mst_$map_area := va;
end;
