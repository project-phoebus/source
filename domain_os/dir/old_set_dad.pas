{ DIR_$OLD_SET_DAD - set an old-format directory's parent.

  Image addresses:
    sau2  0x00E55BF6  DIR_$OLD_SET_DAD

  - The directory is locked for writing; its page 0's parent UID is
    cleared, then the parent recorded as the object's directory pointer.
  - Super-user mode, which name_$lock_dir enters, is left on every path.

  Status stored:
    file_$set_dirptr's status: the parent was recorded
    name_$lock_dir's or name_$unlock_dir's status: a step failed
}

procedure dir_$old_set_dad(in dir_uid: uid_$t; in dad_uid: uid_$t;
                           out status_ret: status_$t);
var
  handle: dir_$old_dir_ptr_t;
begin
  name_$lock_dir(dir_uid, handle, 4, 0, status_ret);

  with handle^ do
    if status_ret.all = status_$ok then begin
      parent_uid := uid_$nil;
      name_$unlock_dir(status_ret);
      if status_ret.all = status_$ok then
        file_$set_dirptr(dir_uid, dad_uid, status_ret);
    end;

  acl_$exit_super;
end;
