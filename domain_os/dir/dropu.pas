{ DIR_$DROPU - drop a name from a directory.

  Image addresses:
    sau2  0x00E516C2  DIR_$DROPU

  - DIR_$DROP_HARD_LINKU with no drop flags; the UID result is UID_$NIL
    whatever the outcome.

  Status stored:
    dir_$drop_hard_linku's status: always
}

procedure dir_$dropu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                     in name_len: integer; out file_uid: uid_$t;
                     out status_ret: status_$t);
begin
  dir_$drop_hard_linku(dir_uid, name, name_len, [], status_ret);

  file_uid := uid_$nil;
end;
