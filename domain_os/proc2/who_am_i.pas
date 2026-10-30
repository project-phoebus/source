{ PROC2_$WHO_AM_I - return the current process's UID.

  Image addresses:
    sau2  0x00E73862  PROC2_$WHO_AM_I

  - The current level-1 process's entry's UID; no lock is taken.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$who_am_i(out puid: uid_$t);
var
  idx: integer;
begin
  idx := proc2_$pid_to_index[proc1_$current];
  puid := proc2_$info_table[idx].uid;
end;
