{ MST_$SET_GUARD - MST_$UNMAP_PRIVI in the current address space, mode
  mst_unmap_match_uid ! mst_unmap_keep_entry.

  Image addresses:
    sau2  0x00E4487C  MST_$SET_GUARD
    sau8  0x03C4CE14  MST_$SET_GUARD
    sau9  0x3C44BF92  MST_$SET_GUARD

  - One call of MST_$UNMAP_PRIVI, the UID's slot pushed as it is.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$set_guard(in uid: uid_$t; in start: integer32;
                         in length: integer32; out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_match_uid ! mst_unmap_keep_entry, uid,
                   start, length, proc1_$as_id, status_ret);
end;
