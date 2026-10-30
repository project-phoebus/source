{ AUDIT_$LOG_EVENT_S - log an event with a given SID block.

  Image addresses:
    sau2  0x00E70E40  AUDIT_$LOG_EVENT_S

  - Only when logging is on and the current process is not suspended;
    it is suspended for the duration.  The data length is clamped to
    2048.
  - Under the lock, the event is logged when the list's flag member 0
    is set or the trail is corrupted, else when its UID is in the list's
    hash table.
  - The record goes into the mapped log buffer, which is written back
    and mapped further on when too small.  A failure closes and reopens
    the log, and crashes the system if that fails too.
  - The record size is computed from the caller's data_len; the copy is
    clamped to 2048 bytes.

  Status stored: none.
}

{ TODO(pascal) actual_len's type: an unsigned compare and a signed widening

  The SAU2 image's clamp compares actual_len with the caller's length
  unsigned at word size: both operands unsigned (an integer against a
  0..65535 is compared in 32 bits).  The widening for OS_$DATA_COPY's
  integer32 length is a sign extension, where a pinteger is widened with
  zeros (the record size's here).  The subrange
  0..audit_max_data_size fits both if the compiler treats a nonnegative
  subrange below 16#8000 as unsigned in compares and widens it by sign (not
  a known form); pinteger and integer each fit one site only. }

procedure audit_$log_event_s(in event_uid: uid_$t; in event_flags: pinteger;
                             in sid: acl_sid_block_t; in status: status_$t;
                             in data: univ audit_$event_data_t;
                             in data_len: pinteger);
label
  10;
var
  local_status: status_$t;
  actual_len: 0..audit_max_data_size;
  record_size: integer;
  rec: audit_$event_rec_ptr_t;
  node: audit_$hash_node_ptr_t;
  should_log: boolean;
begin
  if audit_$enabled and then (audit_$suspend_count[proc1_$current] = 0)
  then begin
    audit_$suspend_count[proc1_$current] :=
      audit_$suspend_count[proc1_$current] + 1;
    actual_len := audit_max_data_size;
    if actual_len > data_len then
      actual_len := data_len;
    local_status.all := status_$ok;
    ml_$exclusion_start(audit_$wired^.lock);

    { whether the event is logged }
    should_log := (audit_flag_selective in audit_$flags) or audit_$corrupted;
    if not should_log then
      if audit_$list_count = 0 then
        goto 10;
    if not should_log then begin
      node := audit_$hash_buckets[uid_$hash(event_uid, 37)];
      while node <> nil do begin
        if node^.uid = event_uid then
          exit;
        node := node^.next;
      end;
      if node = nil then
        goto 10;
    end;

    { the record's size, the room left }
    record_size := 71 + data_len;
    if odd(record_size) then
      record_size := record_size + 1;
    if record_size > audit_$bytes_remaining then begin
      { the next part of the log mapped }
      audit_$file_offset := audit_$file_offset + audit_$write_ptr -
                            audit_$buffer_base;
      acl_$enter_super;
      audit_$dirty := false;
      file_$fw_file(audit_$log_file_uid, local_status);
      if local_status.all = status_$ok then begin
        mst_$unmap_privi(1, uid_$nil, audit_$buffer_base, audit_$buffer_size,
                         0, local_status);
        if local_status.all = status_$ok then
          audit_$buffer_base := integer32(mst_$maps(0, true,
            audit_$log_file_uid, audit_$file_offset, 16#8000, 16#16, 0,
            true, audit_$buffer_size, local_status));
      end;
      acl_$exit_super;
      if local_status.all <> status_$ok then
        goto 10;
      audit_$write_ptr := audit_$buffer_base;
      audit_$bytes_remaining := audit_$buffer_size;
    end;

    { the record }
    rec := audit_$event_rec_ptr_t(audit_$write_ptr);
    rec^.record_size := record_size;
    rec^.version := 1;
    rec^.sid := sid;
    rec^.event_flags := event_flags;
    rec^.node_id.node := node_$me;
    rec^.event_uid := event_uid;
    rec^.status := status;
    time_$clock(rec^.timestamp);
    if proc1_$as_id <> 0 then
      proc2_$get_my_upids(rec^.upid, rec^.upgid, rec^.uppid)
    else begin
      rec^.upid := proc1_$current;
      rec^.uppid := 0;
      rec^.upgid := 0;
    end;
    os_$data_copy(data, rec^.data, actual_len);
    rec^.data[actual_len] := chr(0);
    audit_$write_ptr := audit_$write_ptr + rec^.record_size;
    audit_$bytes_remaining := audit_$bytes_remaining - rec^.record_size;
    audit_$dirty := true;

    { a failure reopens the log }
10:
    if local_status.all <> status_$ok then begin
      acl_$enter_super;
      audit_$close_log(local_status);
      audit_$open_log(local_status);
      acl_$exit_super;
      if local_status.all <> status_$ok then
        crash_system(local_status);
    end;

    ml_$exclusion_stop(audit_$wired^.lock);
    audit_$suspend_count[proc1_$current] :=
      audit_$suspend_count[proc1_$current] - 1;
  end;
end;
