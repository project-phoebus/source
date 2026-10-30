{ DIR_$SET_DAD - set a directory's parent pointer.

  Image addresses:
    sau2  0x00E52B66  DIR_$SET_DAD

  Status stored:
    file_$set_dirptr's status: always
}

procedure dir_$set_dad(in dir_uid: uid_$t; in parent_uid: uid_$t;
                       out status_ret: status_$t);
begin
  file_$set_dirptr(dir_uid, parent_uid, status_ret);
end;
