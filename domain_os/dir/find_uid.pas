{ DIR_$FIND_UID - find the name of a directory's entry for a UID.

  Image addresses:
    sau2  0x00E4E87C  DIR_$FIND_UID

  - The whole UID is matched; the extra longword is dropped.

  Status stored:
    dir_$find_uid_internal's status: always
}

procedure dir_$find_uid(in dir_uid: uid_$t; in target_uid: uid_$t;
                        in name_buf_len: integer;
                        out name_buf: univ name_$long_name_t;
                        out name_len_ret: integer;
                        var status_ret: status_$t);
var
  discarded_net: integer32;
begin
  dir_$find_uid_internal(dir_uid, target_uid, false, name_buf_len, name_buf,
                         name_len_ret, discarded_net, status_ret);
end;
