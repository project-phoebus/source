{ MST_$UNMAPS - MST_$UNMAP_PRIVI in the current address space, mode
  0.

  Image addresses:
    sau2  0x00E4479A  MST_$UNMAPS
    sau8  0x03C4CD32  MST_$UNMAPS
    sau9  0x3C44BEBA  MST_$UNMAPS

  - One call of MST_$UNMAP_PRIVI with UID_$NIL in place of a UID.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmaps(in start: integer32; in length: integer32;
                      out status_ret: status_$t);
begin
  mst_$unmap_privi(0, uid_$nil,
                   start, length, proc1_$as_id, status_ret);
end;
