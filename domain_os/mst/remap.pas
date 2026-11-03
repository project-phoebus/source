{ MST_$REMAP - unmap a range and map the same object again at an offset,
  unprivileged.

  Image addresses:
    sau2  0x00E439D4  MST_$REMAP
    sau4  0x0F84BAAA  MST_$REMAP
    sau8  0x03C4BBDA  MST_$REMAP
    sau9  0x3C44AD9C  MST_$REMAP

  - MST_$REMAP_PRIVI with no flags, its pointer returned.

  Status stored:
    MST_$REMAP_PRIVI's status: in either case
}

function mst_$remap(in va: integer32; in unmap_len: integer32;
                    in offset: integer32; in length: integer32;
                    out map_info: integer32;
                    var status: status_$t): univ_ptr;
begin
  mst_$remap := mst_$remap_privi(0, va, unmap_len, offset,
                                 length, map_info, status);
end;
