{ file_$verify_lock_holder - check that a lock record's owner still holds
  the lock, and clear the lock where it does not.

  Image addresses:
    sau2  0x00E60732  file_$verify_lock_holder

  - An owner other than the holder is asked whether it holds the lock
    (FILE_$LOCAL_LOCK_VERIFY here, REM_FILE_$LOCAL_VERIFY elsewhere); if
    not, the lock is released where it is held (FILE_$PRIV_UNLOCK by
    key, or REM_FILE_$UNLOCK at the holder).

  Status stored:
    status_$ok: the owner holds the lock, or the release failed
    file_$object_not_locked_by_this_process: the lock was released
}

procedure file_$verify_lock_holder(in lock_info: file_$lock_info_t;
                                   out status_ret: status_$t);
var
  node_info: hint_$addr_t;
  desc: file_$obj_loc_t;
  dtv: time_$clock_t;
  verify_status: status_$t;
  owner: integer32;
begin
  owner := lock_info.owner_node & 16#FFFFF;
  if owner <> lock_info.holder.node_low then begin

    { ask the owner }
    if owner = node_$me then
      file_$local_lock_verify(lock_info, verify_status)
    else begin
      node_info.node_id := owner;
      node_info.flags := lock_info.remote_info;
      rem_file_$local_verify(node_info.flags, lock_info, verify_status);
    end;

    { release a lock its owner gave up }
    if verify_status.all = file_$object_not_locked_by_this_process then begin
      if lock_info.holder.node_low = node_$me then
        discard(file_$priv_unlock(lock_info.file_uid, 0, lock_info.mode, 0,
                                  true, lock_info.sequence,
                                  lock_info.context, lock_info.owner_node,
                                  dtv, verify_status))
      else begin
        desc.node := lock_info.holder.node_low;
        desc.loc_info := lock_info.holder.node_high;
        desc.uid := lock_info.file_uid;
        discard(rem_file_$unlock(desc, lock_info.mode, lock_info.context,
                                 lock_info.sequence, lock_info.owner_node,
                                 false, verify_status));
      end;
      if verify_status.all = status_$ok then begin
        status_ret.all := file_$object_not_locked_by_this_process;
        return;
      end;
    end;
  end;

  status_ret.all := status_$ok;
end;
