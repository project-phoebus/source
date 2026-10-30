{ NAME_$CLEANUP - clean up after a failed naming operation.

  Image addresses:
    sau2  0x00E5860E  NAME_$CLEANUP

  - DIR_$CLEANUP and nothing else.

  Status stored: none.
}

procedure name_$cleanup;
begin
  dir_$cleanup;
end;
