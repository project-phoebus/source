{ MST_$UNMAPS_AND_FREE_AREA - MST_$UNMAP_PRIVI in the current address
  space, mode mst_unmap_areas_only.

  Image addresses:
    sau2  0x00E44806  MST_$UNMAPS_AND_FREE_AREA
    sau8  0x03C4CD9E  MST_$UNMAPS_AND_FREE_AREA
    sau9  0x3C44BF26  MST_$UNMAPS_AND_FREE_AREA

  - One call of MST_$UNMAP_PRIVI with UID_$NIL in place of a UID.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmaps_and_free_area(in start: integer32; in length: integer32;
                                    out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_areas_only, uid_$nil,
                   start, length, proc1_$as_id, status_ret);
end;
