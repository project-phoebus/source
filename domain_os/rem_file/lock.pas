{ REM_FILE_$LOCK - lock an object on its home node.

  Image addresses:
    sau2  0x00E61AAE  REM_FILE_$LOCK

  - extended selects the extended request: the object's location record
    and the caller's extended SID, the flags' member 8 set in a
    subsystem; the plain one has the version and the super-user flag.
  - Granted, the extended form's reply gives the lock result, the
    object's location (marked remote) and the key; the plain form's its
    handle and word, which an old server's reply does not carry whole.
  - The reply's packet id is handed back whatever the outcome.

  Status stored:
    rem_file_$send_request's status: the request was sent
    acl_$get_exsid's status: the extended SID could not be had
}

procedure rem_file_$lock(in out loc: file_$obj_loc_t; lock_mode: integer;
                         lock_type: integer; flags: integer;
                         wait_flag: integer; extended: boolean;
                         lock_key: integer32; var lock_key_out: integer;
                         out packet_id_out: integer;
                         var lock_result: file_$attributes_t;
                         out status: status_$t);
  options(val_param);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  packet_id: pinteger;
  nil_word: integer;
  request_len: integer;
  received_len: integer;
begin
  if extended then begin
    { the extended request }
    request.hdr.magic := rem_file_req_magic;
    request.hdr.opcode := rem_file_op_lock_ext;
    request.uid := loc.uid;
    request.ext_loc := loc;
    request.lock_key := lock_key;
    request.lock_node := node_$me;
    request.lock_mode := lock_mode;
    request.lock_type := lock_type;
    request.lock_flags := rem_file_$flags_t(flags);
    if acl_$in_subsys then
      request.lock_flags := request.lock_flags + [8];
    request.ext_wait := wait_flag;
    request.ext_one := 1;

    acl_$get_exsid(request.ext_exsid, status);
    if status.all <> status_$ok then
      return;

    request_len := 162;
  end
  else begin
    { the plain request }
    request.hdr.magic := rem_file_req_magic;
    request.hdr.opcode := rem_file_op_lock;
    request.uid := loc.uid;
    request.lock_key := lock_key;
    request.lock_node := node_$me;
    request.lock_mode := lock_mode;
    request.lock_type := lock_type;
    request.lock_version := rem_file_req_version;
    request.lock_super := acl_$super_count[proc1_$current] > 0;
    request.lock_one := 1;
    request_len := 34;
  end;

  nil_word := 0;
  rem_file_$send_request(loc.loc_info, request, request_len, nil_word, 0,
                         reply, 190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  packet_id_out := packet_id;
  if status.all <> status_$ok then
    return;

  if extended then begin
    lock_result := reply.reply_attrs;
    reply.reply_loc_addr := rem_file_$loc_view_t(loc).addr;
    loc := reply.reply_loc;
    loc.flags := loc.flags + [7];
    lock_key_out := reply.reply_key;
  end
  else begin
    lock_result.lock_handle := reply.lock_handle;
    if received_len = 18 then
      lock_result.lock_word := 0
    else if received_len = 14 then
      lock_result.lock_word := lshft(reply.lock_word, 8) & 16#F800
    else
      lock_result.lock_word := reply.lock_word;
  end;
end;
