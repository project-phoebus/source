{ REM_FILE_$CREATE_TYPE_PRESR10 - create an object on a pre-SR10 node.

  Image addresses:
    sau2  0x00E61868  REM_FILE_$CREATE_TYPE_PRESR10

  - As REM_FILE_$CREATE_TYPE, a new UID and then the creation, in the
    old form; the new UID is handed back before the second request.

  Status stored:
    status_$ok: the creation answered a duplicate UID
    rem_file_$send_request's status: otherwise
}

procedure rem_file_$create_type_presr10(in loc: file_$obj_loc_t;
                                        file_type: integer;
                                        is_dir: integer;
                                        out file_uid: uid_$t;
                                        out status: status_$t);
  options(val_param);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  { phase 1, a new UID }
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_generate_uid;
  nil_word := 0;
  rem_file_$send_request(loc.loc_info, request, 16, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all <> status_$ok then
    return;

  { phase 2 }
  request.hdr.magic := rem_file_req_magic;
  request.uid := loc.uid;
  request.hdr.opcode := rem_file_op_create_type_presr10;
  request.presr10_session := reply.reply_uid;
  request.presr10_type := file_type;
  request.presr10_version := rem_file_req_version;
  request.presr10_super := acl_$super_count[proc1_$current] > 0;
  request.presr10_index := is_dir - 1;

  file_uid := reply.reply_uid;

  rem_file_$send_request(loc.loc_info, request, 28, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all = status_$vtoc_duplicate_uid then
    status.all := status_$ok;
end;
