{ MST_$MAP_GLOBAL - map an object in global A space.

  Image addresses:
    sau2  0x00E4392C  MST_$MAP_GLOBAL
    sau9  0x3C44ACF4  MST_$MAP_GLOBAL

  - A forwarding wrapper of mst_$alloc_segs, returning its pointer; it
    maps in global A from the bottom.

  Status stored:
    mst_$alloc_segs' status: in either case
}

function mst_$map_global(in uid: uid_$t; in start: integer32;
                         in length: integer32; in mode: integer;
                         in extend: integer32; in concur: boolean;
                         out map_info: integer32;
                         out status_ret: status_$t): univ_ptr;
begin
  mst_$map_global := mst_$alloc_segs(0, uid, start, length,
                                     extend, 0, mode, 1, concur, false,
                                     map_info, status_ret);
end;
