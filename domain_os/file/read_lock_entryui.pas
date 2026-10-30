{ FILE_$READ_LOCK_ENTRYUI - the lock record of an object, wherever its
  lock is held.

  Image addresses:
    sau2  0x00E6046E  FILE_$READ_LOCK_ENTRYUI

  - The object is located (FILE_$LOCATEI); its lock record is read from
    the local lock table or the object's node, and checked against its
    holder (file_$verify_lock_holder), read again while the holder no
    longer holds it.

  Status stored:
    file_$locatei's status: the object could not be located
    the last read's or check's status: otherwise
}

procedure file_$read_lock_entryui(in file_uid: uid_$t;
                                  out info: file_$lock_info_t;
                                  out status_ret: status_$t);
var
  buf: file_$lock_info_t;
  loc: hint_$addr_t;
  local_status: status_$t;
begin
  file_$locatei(file_uid, loc, status_ret);
  if status_ret.all <> status_$ok then
    return;

  { read until the holder confirms it }
  repeat
    if loc.node_id <> node_$me then
      rem_file_$local_read_lock(loc.flags, file_uid, buf, local_status)
    else
      file_$local_read_lock(file_uid, buf, local_status);
    if local_status.all <> status_$ok then
      exit;
    file_$verify_lock_holder(buf, local_status);
  until local_status.all <> file_$object_not_locked_by_this_process;

  status_ret := local_status;
  info := buf;
end;
