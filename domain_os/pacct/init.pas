{ PACCT_$INIT - accounting off at boot.

  Image addresses:
    sau2  0x00E31CE8  PACCT_$INIT

  - The owner becomes UID_$NIL, and the mapped window and the room left
    in it are cleared.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure pacct_$init;
begin
  pacct_owner := uid_$nil;
  pacct_map_ptr := 0;
  pacct_buf_remaining := 0;
end;
