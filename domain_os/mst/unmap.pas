{ MST_$UNMAP - unmap a range of the current address space's segments
  mapped to an object.

  Image addresses:
    sau2  0x00E4472E  MST_$UNMAP
    sau9  0x3C44BE4E  MST_$UNMAP

  - One call of MST_$UNMAP_PRIVI, mode 2 (every segment must be mapped
    to the UID), in the current address space.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmap(in uid: uid_$t; in start: integer32;
                     in map_info: integer32; out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_match_uid, uid, start, map_info,
                   proc1_$as_id, status_ret);
end;
