{ FILE_$PRIV_LOCK - take, change or record a lock on an object.

  Image addresses:
    sau2  0x00E5F0EE  FILE_$PRIV_LOCK
    sau2  0x00E5EB98  priv_lock_alloc_entry (nested)
    sau2  0x00E5ED58  priv_lock_link_entry (nested)
    sau2  0x00E5ED92  priv_lock_check_rights (nested)
    sau2  0x00E5EE88  priv_lock_remote_lock (nested)
    sau2  0x00E5EF08  priv_lock_free_entry (nested)
    sau2  0x00E5EF76  priv_lock_check_conflicts (nested)

  - The request's side and mode are mapped through
    file_$lock_mode_table.  A change (flags bit 6) finds the existing
    entry, checks it, renegotiates a remote one and gives it the new mode.
  - A new lock walks the object's location hints: on this node the
    rights and the other locks are checked and an entry linked.
  - On another node that node is asked (twice, the second time in the
    other protocol flavor).
  - "Object is in use" by a lock this process does not hold sends the
    request round again.  A failure frees a half-made entry.
  - REM_FILE_$LOCK writes a word through rights_out's address on an
    extended reply.

  Status stored:
    status_$ok: the lock was taken, changed or recorded
    file_$local_lock_table_full: the table is marked full, or no entry
      or slot is free
    file_$illegal_lock_request: an illegal side and mode
    file_$incompatible_request: an incompatible remote change
    status_$file_volume_has_been_mounted_read_only or
      status_$naming_vol_mounted_read_only: a read-only volume refuses
    status_$no_rights or status_$insufficient_rights: the rights do not
      allow the mode
    status_$naming_bad_directory: a directory locked for delete is not
      empty
    file_$op_cannot_perform_here: a local-only request for an object
      that moved
    file_$object_in_use: another lock conflicts
    file_$object_not_found: no usable hint
    the callees' statuses: an ACL, AST_ or remote call failed
}

{ TODO(pascal) new_entry widened with two signs

  FILE_$PRIV_LOCK's frame word new_entry is sign-extended for the lock
  entry's index in the parent (five sites), and compared signed in
  priv_lock_alloc_entry; but zero-extended in the nested
  priv_lock_alloc_entry and priv_lock_free_entry.  One variable has one
  type; integer here.  Either the compiler widens an up-level word index
  with zeros whatever its type (no other site seen:
  priv_lock_check_conflicts' own index is sign-extended, and its
  up-level hash is a word index), or the nested routines name something
  else: one field, two signs. }

procedure file_$priv_lock(in file_uid: uid_$t; asid: integer;
                          side: pinteger; lock_mode: pinteger;
                          local_only: boolean; flags: integer;
                          key: integer; rem_key: integer32;
                          rem_node: integer32; rem_extra: integer32;
                          in acl_ctx: univ integer32; rem_wait: integer;
                          in out slot_io: linteger;
                          out rights_out: integer;
                          out status: status_$t);
label
  1, 3, 4;
var
  hints: hint_$addr_list_t;
  desc: file_$lock_desc_t;
  attrs: file_$lock_attrs_t;
  lock_info: file_$lock_info_t;
  node_id: linteger;
  local_status: status_$t;
  log_from_remote: integer;
  log_remote: integer;
  found_slot: pinteger;
  new_slot: pinteger;
  remote_mode: integer;
  req_mode: pinteger;
  mapped_mode: integer;
  new_entry: integer;
  found_entry: integer;
  hash: integer;
  cache_flag: boolean;
  dir_not_empty: boolean;
  saw_other_lock: boolean;
  own_remote_lock: boolean;
  from_remote: boolean;
  uid_is_null: boolean;
  add_cache_flag: boolean;
  claimed: boolean;
  hint_count: integer;
  hint_idx: integer;
  compat_mask: file_$lock_mode_set_t;
  attempt: integer;
  i: pinteger;
  slot_entry: pinteger;

  { priv_lock_alloc_entry: take the free list's head for the
    request (new_entry); unless skip_fill, fill it from the request and
    the location (the UID, the remote key and node or this node's
    location, the rights bits, side and mode, remote, pending, flag0);
    for a local request with add_to_proc, record it in the address
    space's first empty slot (new_slot, slot_io) and raise the slot
    count.  "local lock table is full" when no entry or no slot is free. }
  function priv_lock_alloc_entry(add_to_proc: boolean;
                                 skip_fill: boolean): integer32;
  var
    i: pinteger;
  begin
    priv_lock_alloc_entry := status_$ok;
    new_entry := file_$lot_free;
    if new_entry = 0 then begin
      priv_lock_alloc_entry := file_$local_lock_table_full;
      return;
    end;

    file_$lot_free := file_$lock_entries[new_entry].next;
    if new_entry > file_$lot_high then
      file_$lot_high := new_entry;

    { the entry }
    if not skip_fill then
      with file_$lock_entries[new_entry] do begin
        uid := file_uid;
        if from_remote then begin
          context := rem_key;
          sequence := key;
          node.node_low := rem_node;
          node.node_high := rem_extra;
        end
        else begin
          node.node_low := desc.loc.node;
          node.node_high := desc.loc.loc_info;
          context := 0;
          sequence := 0;
        end;
        state.refcount := 0;
        state.read_only := ((attrs.vol_flags & 2) <> 0) and not uid_is_null;
        state.loc_rights := desc.bits.rights_bits;
        state.side := side;
        state.mode := lock_mode;
        state.remote := desc.bits.remote;
        state.pending := true;
        state.flag0 := (flags & 16#20) <> 0;
      end;

    { the address space's slot }
    if (not from_remote) and add_to_proc then begin
      for i := 1 to 150 do
        if file_$lock_table[asid, i] = 0 then begin
          new_slot := i;
          file_$lock_table[asid, i] := new_entry;
          if i > file_$lock_table2[asid] then
            file_$lock_table2[asid] := i;
          slot_io := i;
          return;
        end;
      priv_lock_alloc_entry := file_$local_lock_table_full;
    end;
  end;

  { priv_lock_link_entry: one holder, at the head of the
    object's hash chain. }
  procedure priv_lock_link_entry(var entry: file_$lot_entry_t);
  begin
    entry.state.refcount := 1;
    entry.next := file_$lot_hashtab[hash];
    file_$lot_hashtab[hash] := new_entry;
  end;

  { priv_lock_check_rights: the rights the requester has to
    the object.  A pseudo-object gives 16#F, flags bit 3 16#10; else the
    ACL decides, through the requester's SIDs for a remote request
    (ACL_$RIGHTS_CHECK) or this process's (ACL_$RIGHTS).  An ACL status
    other than ok, "no right" or "insufficient rights" becomes the FILE_
    status (os_proc_shutwired); otherwise, with flags bit 2, no rights or
    rights short of the mode's are refused. }
  procedure priv_lock_check_rights(out status: status_$t;
                                   out rights_out: integer);
  var
    need: integer;
  begin
    status.all := status_$ok;
    if uid_is_null then begin
      rights_out := 16#F;
      return;
    end;
    if (flags & 8) <> 0 then begin
      rights_out := 16#10;
      return;
    end;

    need := file_$lock_compat_table[lock_mode];
    if (flags & 2) <> 0 then
      rights_out := acl_$rights_check(file_$exsid_ptr_t(acl_ctx)^,
                                      file_uid, -1, 0,
                                      (flags & 16#100) <> 0, status)
    else
      rights_out := acl_$rights(file_uid, false, -1, 0, status);

    if (status.all = status_$insufficient_rights_to_perform_operation) or
       else (status.all = status_$ok) or
       else (status.all = status_$no_right_to_perform_operation) then begin
      status.all := status_$ok;
      if (flags & 4) <> 0 then
        if rights_out = 0 then
          status.all := status_$no_rights
        else if (need & rights_out) <> need then
          status.all := status_$insufficient_rights;
    end
    else
      os_proc_shutwired(status);
  end;

  { priv_lock_remote_lock: ask the object's node for the lock
    (REM_FILE_$LOCK, the table lock released for the round trip; every
    caller takes it again), a fresh request key first unless is_new;
    on success the entry keeps the node's key. }
  procedure priv_lock_remote_lock(var entry: file_$lot_entry_t;
                                  mode: integer; side: integer;
                                  flags: integer; is_new: boolean);
  var
    key_out: integer;
  begin
    if not is_new then begin
      file_$lot_seqn := file_$lot_seqn + 1;
      entry.context := file_$lot_seqn;
    end;

    ml_$unlock(ml_$file_lock_lock);
    rem_file_$lock(desc.loc, side, mode, flags, rem_wait,
                   1 in entry.flags_set, entry.context, rights_out,
                   key_out, attrs.attrs, status);

    if status.all = status_$ok then
      entry.sequence := key_out;
  end;

  { priv_lock_free_entry: give back the entry and the slot
    priv_lock_alloc_entry took, if any. }
  procedure priv_lock_free_entry;
  begin
    if new_entry <> 0 then begin
      with file_$lock_entries[new_entry] do begin
        next := file_$lot_free;
        state.refcount := 0;
      end;
      file_$lot_free := new_entry;
      if new_slot <> 0 then
        file_$lock_table[asid, new_slot] := 0;
      new_entry := 0;
      new_slot := 0;
    end;
  end;

  { priv_lock_check_conflicts: the other locks on the object.
    The remote requester's own entry ends the walk (own_remote_lock);
    with skip_found the entry being changed is passed over; a held lock
    whose mapped mode the request's conflict row lacks, or one of modes
    2 or 6 on another node, is "object is in use".  Then, for an object
    on this node, the holder node attribute is set: this node for modes
    5 and 2, none otherwise (left alone when an exclusive lock, mode 4 or
    11, is held, unless the directory is not empty). }
  function priv_lock_check_conflicts(skip_found: boolean): integer32;
  var
    holder: file_$attr_value_t;
    allowed: file_$lock_mode_set_t;
    idx: integer;
    held_mode: integer;
    saw_exclusive: boolean;
  begin
    saw_other_lock := false;
    saw_exclusive := false;
    own_remote_lock := false;
    allowed := file_$lock_conflict_table[mapped_mode];
    priv_lock_check_conflicts := status_$ok;

    { the object's chain }
    idx := file_$lot_hashtab[hash];
    while idx > 0 do
      with file_$lock_entries[idx] do begin
        if uid = file_uid then begin
          if from_remote then
            if (sequence = key) and then (context = rem_key) and then
               (node.node_low = rem_node) then begin
              own_remote_lock := true;
              return;
            end;
          if not (skip_found and then (idx = found_entry)) then begin
            saw_other_lock := true;
            held_mode := state.mode;
            if (held_mode = 4) or else (held_mode = 11) then
              saw_exclusive := true;
            held_mode := file_$lock_mode_table[state.side, held_mode];
            if not (held_mode in allowed) then begin
              priv_lock_check_conflicts := file_$object_in_use;
              return;
            end;
            if (node.node_low & 16#FFFFF) <> node_id then
              if (mapped_mode = 2) or (held_mode = 2) then begin
                priv_lock_check_conflicts := file_$object_in_use;
                return;
              end
              else if (mapped_mode = 6) and then (held_mode = 6) then begin
                priv_lock_check_conflicts := file_$object_in_use;
                return;
              end;
          end;
        end;
        idx := next;
      end;

    if uid_is_null then
      return;
    if desc.bits.remote then
      return;
    if dir_not_empty then
      holder.long_val := 0
    else if (mapped_mode = 5) or else (mapped_mode = 2) then
      holder.long_val := node_id
    else if saw_exclusive then
      return
    else
      holder.long_val := 0;

    ast_$set_attribute(file_uid, 11, holder, status);
    priv_lock_check_conflicts := status.all;
  end;

begin
  if file_$lot_full then begin
    status.all := file_$local_lock_table_full;
    return;
  end;

  { the mapped mode }
  if not (lock_mode in [0..11]) or else (lock_mode > 20) or else
     ((side <> 0) and then (side <> 1)) then
    mapped_mode := 0
  else
    mapped_mode := file_$lock_mode_table[side, lock_mode];
  if mapped_mode = 0 then begin
    status.all := file_$illegal_lock_request;
    return;
  end;

  from_remote := (flags & 2) <> 0;
  dir_not_empty := false;
  if from_remote then
    node_id := rem_node & 16#FFFFF
  else
    node_id := node_$me;
  hash := uid_$hash(file_uid, 251);

1:
  new_entry := 0;
  new_slot := 0;
  claimed := false;
  desc.loc.uid := file_uid;
  desc.bits.scratch := false;
  uid_is_null := file_$uid_view_t(file_uid).b0 = 0;

  if ((flags & 16#40) <> 0) or else
     (lock_mode in file_$lock_illegal_mask) then begin
    { ---- : a change of a lock held ---- }
    req_mode := file_$lock_req_table[lock_mode];
    compat_mask := file_$lock_cvt_table[lock_mode];

    if (not uid_is_null) and then (req_mode <> 4) and then
       (req_mode <> 11) then begin
      ast_$purify(file_uid, -16#8000, 0, 0, 0, status);
      if status.all <> status_$ok then
        return;
    end;

    { the entry }
    ml_$lock(ml_$file_lock_lock);
    found_entry := 0;
    if from_remote then begin
      found_entry := file_$lot_hashtab[hash];
      while found_entry > 0 do
        with file_$lock_entries[found_entry] do begin
          if (node.node_low = rem_node) and then (context = rem_key) and then
             (uid = file_uid) and then not state.remote and then
             (((flags & 16#40) <> 0) or else (state.side = side)) then begin
            if sequence = key then begin
              status.all := status_$ok;
              goto 3;
            end;
            if state.mode in compat_mask then
              exit;
          end;
          found_entry := next;
        end;
    end
    else if (slot_io = 0) or else (slot_io > 16#96) then begin
      if (flags & 16#40) = 0 then begin
        found_slot := 0;
        for i := 1 to file_$lock_table2[asid] do
          if file_$lock_table[asid, i] <> 0 then begin
            slot_entry := file_$lock_table[asid, i];
            with file_$lock_entries[slot_entry] do
              if (state.mode in compat_mask) and then (uid = file_uid)
                 and then (state.side = side) then begin
                found_entry := slot_entry;
                found_slot := i;
                slot_io := i;
                exit;
              end;
          end;
      end;
    end
    else begin
      found_slot := slot_io;
      found_entry := file_$lock_table[asid, found_slot];
      with file_$lock_entries[found_entry] do
        if not ((state.mode in compat_mask) and then (uid = file_uid) and
                then (((flags & 16#40) <> 0) or else
                      (state.side = side))) then begin
          found_entry := 0;
          found_slot := 0;
        end;
    end;

    if found_entry = 0 then begin
      status.all := file_$illegal_lock_request;
      goto 3;
    end;

    with file_$lock_entries[found_entry] do begin
      if ((flags & 16#40) <> 0) and then state.remote and then
         not state.pending then begin
        status.all := file_$incompatible_request;
        goto 3;
      end;
      if state.read_only and then not state.remote and then
         ((file_$lock_compat_table[lock_mode] & 2) <> 0) then begin
        status.all := status_$file_volume_has_been_mounted_read_only;
        goto 3;
      end;
      if (flags & 8) = 0 then
        if (state.rights & file_$lock_compat_table[lock_mode]) <>
           file_$lock_compat_table[lock_mode] then begin
          status.all := status_$insufficient_rights;
          goto 3;
        end;

      desc.loc.loc_info := node.node_high;
      desc.loc.node := node.node_low;
      desc.bits.remote := state.remote;

      if state.refcount > 1 then begin
        { a shared entry split off }
        rights_out := state.rights;
        status.all := priv_lock_alloc_entry(false, true);
        if status.all <> status_$ok then
          goto 3;
        file_$lock_entries[new_entry] := file_$lock_entries[found_entry];
        if state.remote then begin
          priv_lock_remote_lock(file_$lock_entries[new_entry], req_mode, side,
                                flags & (-16#41), false);
          ml_$lock(ml_$file_lock_lock);
          if status.all <> status_$ok then
            goto 3;
        end;
        state.refcount := state.refcount - 1;
        found_entry := new_entry;
        file_$lock_table[asid, found_slot] := found_entry;
        priv_lock_link_entry(file_$lock_entries[new_entry]);
        new_entry := 0;
      end
      else if state.remote then begin
        priv_lock_remote_lock(file_$lock_entries[found_entry], lock_mode, side,
                              flags, true);
        ml_$lock(ml_$file_lock_lock);
        if status.all <> status_$ok then
          goto 3;
      end;
    end;

    with file_$lock_entries[found_entry] do begin
      if not state.remote then begin
        status.all := priv_lock_check_conflicts(true);
        if status.all <> status_$ok then
          goto 3;
        sequence := key;
      end;
      state.mode := req_mode;
      if (flags & 16#40) <> 0 then
        state.side := side;
    end;
    ml_$unlock(ml_$file_lock_lock);
  end
  else begin
    { ---- : a new lock ---- }
    if uid_is_null then begin
      hint_count := 1;
      hints[1].flags := 0;
      hints[1].node_id := file_uid.low & 16#FFFFF;
      if (file_uid.low & 16#FFFFF) = 0 then
        hints[1].node_id := node_$me;
    end
    else if local_only then begin
      hint_count := 1;
      hints[1].flags := 0;
      hints[1].node_id := node_$me;
    end
    else
      hint_count := hint_$get_hints(file_uid, hints);

    { the hints }
    hint_idx := 0;
    while hint_idx < hint_count do begin
      hint_idx := hint_idx + 1;
      if hints[hint_idx].node_id = node_$me then begin
        { the object here }
        if not uid_is_null then begin
          desc.bits.scratch := false;
          ast_$get_attributes(desc.loc, 16#80, attrs.attrs, local_status);
          if local_status.all <> status_$ok then
            next;
          if ((attrs.obj_type = 1) or else (attrs.obj_type = 2)) and then
             (attrs.not_empty <> 0) then begin
            dir_not_empty := true;
            if (lock_mode = 1) and then ((flags & 16#80) <> 0) then begin
              status.all := status_$naming_bad_directory;
              goto 4;
            end;
          end;
          if ((attrs.vol_flags & 2) <> 0) and then
             ((file_$lock_compat_table[lock_mode] & 2) <> 0) then begin
            if (attrs.obj_type = 1) or else (attrs.obj_type = 2) then
              status.all := status_$naming_vol_mounted_read_only
            else
              status.all := status_$file_volume_has_been_mounted_read_only;
            goto 4;
          end;
          if (hint_idx <> 1) or else desc.bits.remote then
            hint_$addi(file_uid, desc.hint);
        end
        else begin
          desc.bits.remote := false;
          desc.hint := hints[1];
        end;

        { the AOTE says it moved }
        if desc.bits.remote then begin
          if local_only then begin
            status.all := file_$op_cannot_perform_here;
            goto 4;
          end;
          hints[1] := desc.hint;
          hint_idx := 0;
          next;
        end;

        { a local lock }
        claimed := true;
        priv_lock_check_rights(status, rights_out);
        ml_$lock(ml_$file_lock_lock);
        if status.all <> status_$ok then
          goto 3;
        file_$uid_lock_acquire(file_uid);
        file_$uid_lock_release(file_uid);
        status.all := priv_lock_alloc_entry(claimed, false);
        if status.all <> status_$ok then
          goto 3;
        file_$lock_entries[new_entry].state.rights := rights_out;
        status.all := priv_lock_check_conflicts(false);
        if own_remote_lock then
          goto 3;
        if status.all <> status_$ok then
          goto 3;
        priv_lock_link_entry(file_$lock_entries[new_entry]);
        ml_$unlock(ml_$file_lock_lock);
        exit;
      end
      else begin
        { the object on another node }
        ml_$lock(ml_$file_lock_lock);
        file_$uid_lock_acquire(file_uid);
        file_$uid_lock_release(file_uid);
        desc.hint := hints[hint_idx];
        desc.bits.scratch := false;
        desc.bits.remote := true;
        status.all := priv_lock_alloc_entry(true, false);
        if status.all <> status_$ok then
          goto 3;
        file_$lot_pending := file_$lot_pending + 1;
        ml_$unlock(ml_$file_lock_lock);

        { the request, in two flavors }
        with file_$lock_entries[new_entry] do begin
          hint_$lookup_cache(desc.hint.node_id, cache_flag);
          state.pending := not cache_flag;
          for attempt := 1 to 2 do begin
            if not state.pending then begin
              priv_lock_check_rights(status, rights_out);
              if status.all <> status_$ok then
                exit;
              remote_mode := file_$lock_mode_map[lock_mode];
            end
            else
              remote_mode := lock_mode;
            ml_$lock(ml_$file_lock_lock);
            priv_lock_remote_lock(file_$lock_entries[new_entry], remote_mode,
                                  side, flags, false);
            if status.all <> file_$bad_reply_received_from_remote_node then
              exit;
            if attempt = 2 then
              exit;
            add_cache_flag := state.pending;
            hint_$add_cache(desc.hint.node_id, add_cache_flag);
            state.pending := not state.pending;
          end;
        end;

        { a failure }
        if status.all <> status_$ok then begin
          if (status.all = file_$comms_problem_with_remote_node) or else
             (status.all = file_$op_cannot_perform_here) or else
             (status.modc = 16#11) or else
             (status.all = file_$object_not_found) then begin
            ml_$lock(ml_$file_lock_lock);
            file_$lot_pending := file_$lot_pending - 1;
            priv_lock_free_entry;
            ml_$unlock(ml_$file_lock_lock);
            next;
          end;
          ml_$lock(ml_$file_lock_lock);
          file_$lot_pending := file_$lot_pending - 1;
          goto 3;
        end;

        { the lock granted }
        if hint_idx <> 1 then
          hint_$addi(file_uid, desc.hint);
        claimed := true;
        ml_$lock(ml_$file_lock_lock);
        file_$lot_pending := file_$lot_pending - 1;
        discard(priv_lock_check_conflicts(false));
        file_$lock_entries[new_entry].state.rights := rights_out;
        priv_lock_link_entry(file_$lock_entries[new_entry]);
        ml_$unlock(ml_$file_lock_lock);
        if saw_other_lock then
          exit;
        if (flags & 1) = 0 then
          ast_$cond_flush(file_uid, attrs.dtm, local_status);
        if uid_is_null then
          exit;
        if not file_$lock_entries[new_entry].state.pending then
          exit;
        ast_$load_aote(attrs.attrs, desc.loc);
        exit;
      end;
    end;

    if not claimed then begin
      status.all := file_$object_not_found;
      return;
    end;
  end;

  { the log }
  if netlog_$ok_to_log then begin
    if desc.bits.remote then
      log_remote := 1
    else
      log_remote := 0;
    if from_remote then
      log_from_remote := 1
    else
      log_from_remote := 0;
    netlog_$log_it(16#12, file_uid, 0, 0, side, lock_mode, log_remote,
                   log_from_remote);
  end;
  return;

3:
  priv_lock_free_entry;
  ml_$unlock(ml_$file_lock_lock);

  { in use, but not by this process's locks }
4:
  if status.all <> file_$object_in_use then
    return;
  file_$read_lock_entryui(file_uid, lock_info, local_status);
  if local_status.all = file_$object_not_locked_by_this_process then
    goto 1;
end;
