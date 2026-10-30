{ FILE_$UNLOCK_VOL - release every lock on a volume's objects.

  Image addresses:
    sau2  0x00E60D36  FILE_$UNLOCK_VOL

  - The volume's locks are walked (FILE_$READ_LOCK_ENTRYI from index 1)
    and each released as its remote requester would (FILE_$PRIV_UNLOCK
    by key); the releases' statuses are not read.

  Status stored:
    status_$ok: the walk ended ("no more lock table entries")
    file_$read_lock_entryi's status: the walk failed otherwise
}

procedure file_$unlock_vol(vol_uid: uid_$t; out status_ret: status_$t);
var
  lock_info: file_$lock_info_t;
  dtv_out: time_$clock_t;
  local_status: status_$t;
  iter_index: pinteger;
begin
  iter_index := 1;

  repeat
    file_$read_lock_entryi(vol_uid, iter_index, lock_info, status_ret);
    if status_ret.all <> status_$ok then
      exit;
    discard(file_$priv_unlock(lock_info.file_uid, 0, 0, 0, true,
                              lock_info.sequence, lock_info.context,
                              lock_info.owner_node, dtv_out,
                              local_status));
  until false;

  if status_ret.all = file_$obj_not_locked_by_this_process then
    status_ret.all := status_$ok;
end;
