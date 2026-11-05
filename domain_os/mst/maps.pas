{ MST_$MAPS - map an object into a given address space, searching from
  the top.

  Image addresses:
    sau2  0x00E43982  MST_$MAPS
    sau4  0x0F84BA58  MST_$MAPS
    sau6  0x7804ADCC  MST_$MAPS
    sau7  0x3C453B4A  MST_$MAPS
    sau8  0x03C4BB88  MST_$MAPS
    sau9  0x3C44AD4A  MST_$MAPS

  - A forwarding wrapper of mst_$alloc_segs, returning its pointer.

  Status stored:
    mst_$alloc_segs' status: in either case
}

function mst_$maps(asid: integer; direction: boolean; var uid: uid_$t;
                   start_va: integer32; length: integer32; area_id: integer;
                   area_size: integer32; access: boolean;
                   var map_info: integer32;
                   var status: status_$t): univ_ptr;
begin
  mst_$maps := mst_$alloc_segs(16#7FFFFFFF, uid, start_va,
                               length, area_size, asid, area_id,
                               mst_$touch_count, access, direction,
                               map_info, status);
end;
