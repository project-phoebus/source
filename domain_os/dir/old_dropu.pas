{ DIR_$OLD_DROPU - remove an entry from an old-format directory, handing
  back the object's UID.

  Image addresses:
    sau2  0x00E56A9A  DIR_$OLD_DROPU

  - name_$old_delete_entryu with the rights check and the no-lock flag
    off and the link flag on, as DIR_$DROPU passes its own on.

  Status stored:
    name_$old_delete_entryu's status: always
}

procedure dir_$old_dropu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                         in name_len: pinteger; out file_uid: uid_$t;
                         out status_ret: status_$t);
begin
  name_$old_delete_entryu(dir_uid, name, name_len, false, false, true,
                          file_uid, status_ret);
end;
