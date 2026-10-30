{ MST_$MAPS_AT - map an object at an address in a given address space.

  Image addresses:
    sau2  0x00E42E54  MST_$MAPS_AT
    sau9  0x3C44A204  MST_$MAPS_AT

  - The slots go on to mst_$alloc_segs with the global touch count and
    a false direction (private or global A).

  Status stored:
    mst_$alloc_segs' status: in either case
}

procedure mst_$maps_at(addr_hint: integer32; asid: integer;
                       in uid: uid_$t; start_va: integer32;
                       length: integer32; prot: integer;
                       area_size: integer32; wired: boolean;
                       out map_info: integer32;
                       out status_ret: status_$t);
begin
  discard(mst_$alloc_segs(addr_hint, uid, start_va, length,
                          area_size, asid, prot, mst_$touch_count,
                          wired, false, map_info, status_ret));
end;
