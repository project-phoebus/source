{ REM_FILE_$LOCAL_READ_LOCK - read an object's lock record from another
  node.

  Image addresses:
    sau2  0x00E61E9A  REM_FILE_$LOCAL_READ_LOCK

  - The lock record is handed back on success; an old server's shorter
    reply (34 or 38 bytes) has the record's tail cleared, whatever the
    status.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$local_read_lock(in addr_info: integer32;
                                    in file_uid: uid_$t;
                                    out lock_entry: file_$lock_info_t;
                                    out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_local_read_lock;
  request.uid := file_uid;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 12, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all = status_$ok then
    lock_entry := reply.reply_lock;

  if received_len = 34 then begin
    lock_entry.holder.node_high := 0;
    lock_entry.remote_info := 0;
  end;
  if received_len = 38 then
    lock_entry.remote_info := 0;
end;
