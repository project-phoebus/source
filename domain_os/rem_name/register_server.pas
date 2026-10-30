{ REM_NAME_$REGISTER_SERVER - note that a naming server was heard from.

  Image addresses:
    sau2  0x00E4A4AE  REM_NAME_$REGISTER_SERVER

  - The server's network and node are never read.
  - The block is reached with no A5 load, unlike its neighbors; why is
    not known.

  Status stored: none.
}

procedure rem_name_$register_server(in net: integer32;
                                    in node: integer32);
var
  unused_8: array[0..1] of integer32;    { the stand-in }
begin
  rem_name_$time_heard_from_server := time_$clockh;
  rem_name_$heard_from_server := true;
end;
