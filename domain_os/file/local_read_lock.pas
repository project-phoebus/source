{ FILE_$LOCAL_READ_LOCK - read the local lock table's record of an
  object's lock.

  Image addresses:
    sau2  0x00E6050E  FILE_$LOCAL_READ_LOCK

  - Under the lock-table lock the object's first entry in its hash chain
    fills the caller's lock record: the UID, the context, the side and
    mode, the sequence, and the holder, owner and remote information.

  Status stored:
    status_$ok: an entry was found
    file_$object_not_locked_by_this_process: none was
}

procedure file_$local_read_lock(in file_uid: uid_$t;
                                out info: file_$lock_info_t;
                                out status_ret: status_$t);
var
  hash: integer;
  i: integer;
begin
  hash := uid_$hash(file_uid, 251);
  status_ret.all := file_$object_not_locked_by_this_process;

  { the bucket's chain }
  ml_$lock(ml_$file_lock_lock);
  i := file_$lot_hashtab[hash];
  while i > 0 do
    with file_$lock_entries[i] do begin
      i := next;
      if uid = file_uid then begin
        info.file_uid := uid;
        info.context := context;
        info.side := state.side;
        info.mode := state.mode;
        info.sequence := sequence;
        if state.remote then begin
          info.holder := node;
          info.owner_node := node_$me;
          info.remote_info := network_$me;
        end
        else begin
          info.holder.node_low := node_$me;
          info.holder.node_high := network_$me;
          info.owner_node := node.node_low;
          info.remote_info := node.node_high;
        end;
        status_ret.all := status_$ok;
        exit;
      end;
    end;

  ml_$unlock(ml_$file_lock_lock);
end;
