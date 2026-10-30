{ DIR_$OLD_CLEANUP - release the current process's old-format directory
  lock, if it holds one.

  Image addresses:
    sau2  0x00E54B2A  DIR_$OLD_CLEANUP

  - name_$unlock_dir's status is not looked at.

  Status stored: none.
}

procedure dir_$old_cleanup;
var
  status: status_$t;
begin
  if name_$lock_uid[proc1_$current].high <> 0 then
    name_$unlock_dir(status);
end;
