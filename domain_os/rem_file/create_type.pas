{ REM_FILE_$CREATE_TYPE - create a typed object on the node that holds its
  parent.

  Image addresses:
    sau2  0x00E6171A  REM_FILE_$CREATE_TYPE

  - Two requests: a new UID, then the creation.  On success, or a
    duplicate UID, the reply's location (with the caller's address) is
    the new object's, marked remote, and its attributes are handed back.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$create_type(in loc: file_$obj_loc_t;
                                file_type: integer;
                                in type_uid: uid_$t;
                                size: integer32; flags: integer;
                                in owner: rem_file_$owner_info_t;
                                out attrs: file_$attributes_t;
                                out new_loc: file_$obj_loc_t;
                                out status: status_$t);
  options(val_param);
var
  unused_28: array[1..40] of char;        { stand-in }
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

  { phase 2, the creation }
  request.hdr.opcode := rem_file_op_create_type;
  request.hdr.magic := rem_file_req_magic;
  request.uid := loc.uid;
  request.session_uid := reply.reply_uid;
  request.type_uid := type_uid;
  request.parent_uid2 := loc.uid;
  request.owner := owner;
  request.create_type := file_type;
  request.create_flags := flags;
  request.create_size := size;

  nil_word := 0;
  rem_file_$send_request(loc.loc_info, request, 92, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if (status.all = status_$ok) or else
     (status.all = status_$vtoc_duplicate_uid) then begin
    reply.reply_loc_addr := rem_file_$loc_view_t(loc).addr;
    new_loc := reply.reply_loc;
    new_loc.flags := new_loc.flags + [7];
    attrs := reply.reply_attrs;
  end;
end;
