{ MST_$MAP_AT - map an object at a caller-supplied address in the
  current address space.

  Image addresses:
    sau2  0x00E42F54  MST_$MAP_AT
    sau4  0x0F84B04A  MST_$MAP_AT
    sau8  0x03C4B162  MST_$MAP_AT
    sau9  0x3C44A36A  MST_$MAP_AT

  - A forwarding wrapper of mst_$alloc_segs, with the current ASID, the
    global touch count and a false direction (private or global A).

  Status stored:
    mst_$alloc_segs' status: in either case
}

procedure mst_$map_at(in va: integer32; in uid: uid_$t; in start: integer32;
                      in length: integer32; in mode: integer;
                      in extend: integer32; in concur: boolean;
                      out map_info: integer32;
                      out status_ret: status_$t);
begin
  discard(mst_$alloc_segs(va, uid, start, length, extend,
                          proc1_$as_id, mode, mst_$touch_count, concur,
                          false, map_info, status_ret));
end;
