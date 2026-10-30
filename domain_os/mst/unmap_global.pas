{ MST_$UNMAP_GLOBAL - MST_$UNMAP_PRIVI in the current address space,
  mode mst_unmap_match_uid ! mst_unmap_global.

  Image addresses:
    sau2  0x00E44764  MST_$UNMAP_GLOBAL
    sau9  0x3C44BE84  MST_$UNMAP_GLOBAL

  - One call of MST_$UNMAP_PRIVI, the UID's slot pushed as it is; bit 3
    of the mode is never tested by it.

  Status stored:
    MST_$UNMAP_PRIVI's status: in either case
}

procedure mst_$unmap_global(in uid: uid_$t; in start: integer32;
                            in length: integer32; out status_ret: status_$t);
begin
  mst_$unmap_privi(mst_unmap_match_uid ! mst_unmap_global, uid,
                   start, length, proc1_$as_id, status_ret);
end;
