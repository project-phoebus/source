{ FILE_$PRIV_UNLOCK - release a lock on an object, or every lock this
  address space holds on it.

  Image addresses:
    sau2  0x00E5FD32  FILE_$PRIV_UNLOCK

  - Under the lock-table lock the lock's entry is found (a remote
    requester's by key, a local caller's by its slot or a scan) and its
    reference count dropped; at zero it goes back to the free list.
  - Dropping the last writer's lock writes the object's pages back; a
    remote object's node is told (REM_FILE_$UNLOCK) after the lock is
    released.  Mode 0 repeats the search until it fails.
  - The result is the remote node's or AST_$TRUNCATE's answer, when the
    status is ok.

  Status stored:
    status_$ok: the lock was released (also "not locked" after at least
      one release)
    file_$object_not_locked_by_this_process: no such lock
    file_$invalid_arg: a slot above 150
    rem_file_$unlock's or the AST_ callees' status: those failed
}

function file_$priv_unlock(in file_uid: uid_$t; lock_slot: integer32;
                           lock_mode: integer; asid: integer;
                           by_key: boolean; key: integer;
                           rem_key: integer32; rem_node: integer32;
                           out dtv_out: time_$clock_t;
                           out status: status_$t): boolean;
label
  5, 6, 9;
var
  lock_info: file_$lock_info_t;
  cattr: ast_$common_attr_t;
  attr_val: file_$attr_value_t;
  desc: file_$lock_desc_t;
  entry_ctx: integer32;
  dts_scratch: time_$clock_t;
  status3: status_$t;
  status2: status_$t;
  local_status: status_$t;
  dtv_zero: integer32;
  entry_key: integer;
  log_by_key: integer;
  log_remote: integer;
  log_side: integer;
  prev_entry: integer;
  cur_entry: integer;
  hash: integer;
  dts_result: boolean;
  did_unlock: boolean;
  other_exclusive: boolean;
  not_pending: boolean;
  unlock_result: boolean;
  saw_other: boolean;
  slot: pinteger;
  entry_mode: integer;
  is_exclusive: boolean;
  retry_read: boolean;
  i: integer;
  walk: integer;
  next_walk: integer;
begin
  local_status.all := status_$ok;
  dtv_out.high := 0;
  unlock_result := false;
  did_unlock := false;

  hash := uid_$hash(file_uid, 251);

  { mode 8 for a local caller, and mode 9, only
    log }
  if ((lock_mode = 8) and not by_key) or else (lock_mode = 9) then
    goto 9;

  repeat
    cur_entry := 0;
    slot := lock_slot;
    ml_$lock(ml_$file_lock_lock);

    if not by_key then begin
      if slot = 0 then begin
        { find the UID and mode in the address
          space's slots }
        for i := 1 to file_$lock_table2[asid] do begin
          cur_entry := file_$lock_table[asid, i];
          if cur_entry <> 0 then
            with file_$lock_entries[cur_entry] do
              if state.flag0 or (lock_mode = 0) then
                if uid = file_uid then
                  if (state.mode = lock_mode) or else (lock_mode = 0) then
                    begin
                    slot := i;
                    exit;
                  end;
        end;
        if slot = 0 then begin
          local_status.all := file_$object_not_locked_by_this_process;
          goto 5;
        end;
      end
      else if slot > 150 then begin
        local_status.all := file_$invalid_arg;
        goto 5;
      end
      else begin
        { the slot the caller names }
        cur_entry := file_$lock_table[asid, slot];
        if cur_entry = 0 then begin
          local_status.all := file_$object_not_locked_by_this_process;
          goto 5;
        end;
        with file_$lock_entries[cur_entry] do begin
          if uid <> file_uid then begin
            local_status.all := file_$object_not_locked_by_this_process;
            goto 5;
          end;
          if lock_mode <> 0 then
            if (state.mode <> lock_mode) or else state.flag0 then begin
              local_status.all := file_$object_not_locked_by_this_process;
              goto 5;
            end;
        end;
      end;

      file_$lock_table[asid, slot] := 0;
    end
    else begin
      { a remote requester's lock, on the hash
        chain }
      cur_entry := file_$lot_hashtab[hash];
      while cur_entry > 0 do
        with file_$lock_entries[cur_entry] do begin
          if (state.mode = lock_mode) or (lock_mode = 0) then
            if (sequence = key) or (key = 0) then
              if (node.node_low = rem_node) and then (context = rem_key) and then
                 not state.remote and then (uid = file_uid) and then
                 (state.refcount <> 0) then
                exit;
          cur_entry := next;
        end;

      if cur_entry = 0 then begin
        if lock_mode = 8 then
          local_status.all := file_$object_not_locked_by_this_process
        else
          local_status.all := status_$ok;
        ml_$unlock(ml_$file_lock_lock);
        goto 9;
      end;

      { mode 8 marks the object delete-pending }
      if lock_mode = 8 then begin
        desc.loc.uid := file_uid;
        ast_$get_common_attributes(desc.loc, 16#10, cattr, local_status);
        if (local_status.all = status_$ok) and then
           (ord(cattr.obj_type) = 0) then begin
          attr_val.word_val := 1;
          ast_$set_attribute(file_uid, 7, attr_val, local_status);
        end;
        ml_$unlock(ml_$file_lock_lock);
        goto 9;
      end;
    end;

    { release the entry }
    did_unlock := true;
    dts_result := ast_$set_dts(16#10, file_uid, dts_scratch, dts_scratch,
                               status2);

    with file_$lock_entries[cur_entry]: found do begin
      desc.loc.uid := file_uid;
      desc.loc.loc_info := found.node.node_high;
      desc.loc.node := found.node.node_low;
      desc.bits.remote := found.state.remote;
      desc.bits.scratch := true;
      not_pending := not found.state.pending;
      entry_key := found.sequence;
      entry_ctx := found.context;
      entry_mode := found.state.mode;
      log_side := found.state.side;
      is_exclusive := (entry_mode = 4) or (entry_mode = 11);

      found.state.refcount := found.state.refcount - 1;
      if found.state.refcount <> 0 then
        goto 5;

      { unlink it, noting the other locks }
      walk := file_$lot_hashtab[hash];
      prev_entry := 0;
      other_exclusive := false;
      saw_other := false;
      while walk > 0 do
        with file_$lock_entries[walk]: e do begin
          next_walk := e.next;
          if e.uid = file_uid then
            if walk = cur_entry then begin
              if prev_entry = 0 then
                file_$lot_hashtab[hash] := found.next
              else
                file_$lock_entries[prev_entry].next := found.next;
              found.next := file_$lot_free;
              file_$lot_free := cur_entry;
            end
            else begin
              saw_other := true;
              if (e.state.mode = 4) or else (e.state.mode = 11) then
                other_exclusive := true;
            end;
          prev_entry := walk;
          walk := next_walk;
        end;
    end;

    { the last writer's lock of a real object }
    if (is_exclusive and not other_exclusive) and then
       (file_$uid_view_t(file_uid).b0 <> 0) then begin
      ast_$purify(file_uid, -16#8000, 0, 0, 0, local_status);
      if saw_other and then not desc.bits.remote then begin
        attr_val.long_val := 0;
        ast_$set_attribute(file_uid, 11, attr_val, status2);
      end;
    end;

    { a remote requester's writer lock }
    if (is_exclusive and by_key) and then
       (file_$uid_view_t(file_uid).b0 <> 0) then begin
      dtv_zero := 0;
      ast_$get_dtv(file_uid, dtv_zero, dtv_out, status2);
      if status2.all <> status_$ok then
        dtv_out.high := 0;
    end;

    ml_$unlock(ml_$file_lock_lock);

    if desc.bits.remote then begin
      { tell the object's node }
      retry_read := false;
      if not_pending then
        if not saw_other then begin
          ast_$get_common_attributes(desc.loc, 16#30, cattr, status2);
          if (status2.all = status_$ok) and then (cattr.refcount = 0) then
            begin
            rem_file_$local_read_lock(desc.loc.loc_info, desc.loc.uid,
                                      lock_info, status2);
            if status2.all = file_$object_not_locked_by_this_process then
              retry_read := true;
          end;
        end;
      if not_pending then
        entry_mode := file_$lock_mode_map[entry_mode];

      unlock_result := rem_file_$unlock(desc.loc, entry_mode, entry_ctx,
                                        entry_key, node_$me, dts_result,
                                        status3);

      if local_status.all = status_$ok then
        local_status := status3;
      if status3.all = status_$ok then
        if retry_read then
          ast_$truncate(file_uid, 0, 1, unlock_result, status2)
        else if unlock_result then begin
          dts_scratch.high := 0;
          ast_$cond_flush(file_uid, dts_scratch, status2);
        end;
    end
    else if not saw_other and then
            (file_$uid_view_t(file_uid).b0 <> 0) then
      { a local object nobody else holds }
      ast_$truncate(file_uid, 0, 1, unlock_result, local_status);
    goto 6;

5:  ml_$unlock(ml_$file_lock_lock);

    { mode 0 releases every lock on the object }
6:
  until (local_status.all <> status_$ok) or else (lock_mode <> 0);

9:
  if netlog_$ok_to_log and then (local_status.all = status_$ok) then begin
    if desc.bits.remote then
      log_remote := 1
    else
      log_remote := 0;
    if by_key then
      log_by_key := 1
    else
      log_by_key := 0;
    netlog_$log_it(16#13, file_uid, 0, 0, log_side, lock_mode, log_remote,
                   log_by_key);
  end;

  if (local_status.all = file_$object_not_locked_by_this_process) and then
     did_unlock then
    status.all := status_$ok
  else
    status := local_status;
  file_$priv_unlock := (status.all = status_$ok) and unlock_result;
end;
