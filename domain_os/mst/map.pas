{ MST_$MAP - map an object anywhere in the current address space.

  Image addresses:
    sau2  0x00E4386C  MST_$MAP
    sau4  0x0F84B942  MST_$MAP
    sau8  0x03C4BA72  MST_$MAP
    sau9  0x3C44AC34  MST_$MAP

  - A forwarding wrapper of mst_$alloc_segs, returning its pointer; it
    searches top-down (the hint 16#7FFFFFFF), as MST_$MAP_TOP does.

  Status stored:
    mst_$alloc_segs' status: in either case
}

function mst_$map(in uid: uid_$t; in start: integer32;
                  in length: integer32; in mode: integer;
                  in extend: integer32; in concur: boolean;
                  out map_info: integer32;
                  out status_ret: status_$t): univ_ptr;
begin
  mst_$map := mst_$alloc_segs(16#7FFFFFFF, uid, start,
                              length, extend, proc1_$as_id, mode,
                              mst_$touch_count, concur, false,
                              map_info, status_ret);
end;
