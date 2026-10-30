{ FILE_$FORCE_UNLOCK - release a remote node's lock on a local object.

  Image addresses:
    sau2  0x00E60DB0  FILE_$FORCE_UNLOCK

  - A lock held on this node for another node is released as its
    requester would release it (FILE_$PRIV_UNLOCK by key, with the
    lock's sequence, context and owner node).

  Status stored:
    status_$ok: the lock was released, or the object was not locked
    file_$op_cannot_perform_here: any other lock
    file_$read_lock_entryui's or file_$priv_unlock's status: those
      failed
}

procedure file_$force_unlock(file_uid: uid_$t; out status_ret: status_$t);
var
  lock_info: file_$lock_info_t;
  dtv_out: time_$clock_t;
begin
  file_$read_lock_entryui(file_uid, lock_info, status_ret);

  if status_ret.all = status_$ok then
    if (lock_info.holder.node_low <> node_$me) or else
       ((lock_info.owner_node & 16#FFFFF) = node_$me) then
      status_ret.all := file_$op_cannot_perform_here
    else
      discard(file_$priv_unlock(file_uid, 0, 0, 0, true,
                                lock_info.sequence, lock_info.context,
                                lock_info.owner_node, dtv_out,
                                status_ret));

  if status_ret.all = file_$object_not_locked_by_this_process then
    status_ret.all := status_$ok;
end;
