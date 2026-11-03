{ MST_$UNMAP_AND_FREE_AREA - MST_$UNMAP_PRIVI in the current address
  space, mode mst_unmap_match_uid ! mst_unmap_areas_only.

  Image addresses:
    sau2  0x00E447D0  MST_$UNMAP_AND_FREE_AREA
    sau4  0x0F84CBDE  MST_$UNMAP_AND_FREE_AREA
    sau8  0x03C4CD68  MST_$UNMAP_AND_FREE_AREA
    sau9  0x3C44BEF0  MST_$UNMAP_AND_FREE_AREA

  - One call of MST_$UNMAP_PRIVI, the UID's slot pushed as it is.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmap_and_free_area(in uid: uid_$t; in start: integer32;
                                   in length: integer32; out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_match_uid ! mst_unmap_areas_only, uid,
                   start, length, proc1_$as_id, status_ret);
end;
