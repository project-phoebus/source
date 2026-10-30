{ DIR_$ROOT_ADDU - add an entry to a directory with the caller's flags.

  Image addresses:
    sau2  0x00E52B8C  DIR_$ROOT_ADDU

  - DIR_$ADDU's call with the caller's flags longword for its 0 (a
    non-zero one makes the old-format fallback DIR_$OLD_ROOT_ADDU).

  Status stored:
    dir_$add_entry_internal's status: always
}

procedure dir_$root_addu(in dir_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: integer; in file_uid: uid_$t;
                         in flags: integer32; out status_ret: status_$t);
begin
  dir_$add_entry_internal(dir_uid, name, name_len, file_uid, flags,
                          status_ret);
end;
