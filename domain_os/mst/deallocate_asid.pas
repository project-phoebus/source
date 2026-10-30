{ MST_$DEALLOCATE_ASID - free an address space ID.

  Image addresses:
    sau2  0x00E42E3C  MST_$DEALLOCATE_ASID
    sau9  0x3C44A1EC  MST_$DEALLOCATE_ASID

  - One call of MST_$FREE_ASID with the same two arguments.

  Status stored:
    MST_$FREE_ASID's status: in either case
}

procedure mst_$deallocate_asid(asid: integer; out status_ret: status_$t);
begin
  mst_$free_asid(asid, status_ret);
end;
