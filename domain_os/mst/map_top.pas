{ MST_$MAP_TOP - map an object in the current address space, from the
  top.

  Image addresses:
    sau2  0x00E438CC  MST_$MAP_TOP
    sau8  0x03C4BAD2  MST_$MAP_TOP
    sau9  0x3C44AC94  MST_$MAP_TOP

  - A forwarding wrapper of mst_$alloc_segs, returning its pointer; it
    searches top-down (the hint 16#7FFFFFFF).

  Status stored:
    mst_$alloc_segs' status: in either case
}

function mst_$map_top(in uid: uid_$t; in start: integer32;
                      in length: integer32; in mode: integer;
                      in extend: integer32; in concur: boolean;
                      out map_info: integer32;
                      out status_ret: status_$t): univ_ptr;
begin
  mst_$map_top := mst_$alloc_segs(16#7FFFFFFF, uid, start,
                                  length, extend, proc1_$as_id, mode,
                                  mst_$touch_count, concur, false,
                                  map_info, status_ret);
end;
