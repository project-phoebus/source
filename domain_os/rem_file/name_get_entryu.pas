{ REM_FILE_$NAME_GET_ENTRYU - look a name up in a directory on another
  node.

  Image addresses:
    sau2  0x00E6209A  REM_FILE_$NAME_GET_ENTRYU

  - The request carries the caller's current SIDs and project list (at
    most 8).
  - The entry's extra longword is cleared for an old server's 34-byte
    reply.

  Status stored:
    rem_file_$send_request's status: the request was sent
    acl_$get_re_sids's or acl_$get_proj_list's status: the caller's SIDs
      or projects could not be had
}

procedure rem_file_$name_get_entryu(var addr_info: integer32;
                                    in dir_uid: uid_$t;
                                    in name: univ name_$name_t;
                                    name_len: pinteger;
                                    out entry:
                                      univ rem_file_$name_get_entryu_result_t;
                                    out status: status_$t);
var
  local_sids: acl_sid_block_t;
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.ent_name[1] := ' ';
  request.ent_name[2] := ' ';
  request.ent_name[3] := ' ';
  request.ent_name[4] := ' ';

  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_name_get_entryu;
  request.uid := dir_uid;
  request.ent_name := name;
  request.ent_name_len := name_len;
  request.ent_version := rem_file_req_version;

  request.ent_super := acl_$super_count[proc1_$current] > 0;
  request.ent_zero_32 := 0;

  acl_$get_re_sids(local_sids, request.ent_re_sids, status);
  if status.all <> status_$ok then
    return;

  acl_$get_proj_list(request.ent_proj, 8, request.ent_proj_count, status);
  if status.all <> status_$ok then
    return;

  request.ent_zero_9a := 0;
  request.ent_zero_9e := 0;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 162, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all <> status_$ok then
    return;

  entry.entry_uid := reply.ent_uid;
  entry.entry_type := reply.ent_type;
  if received_len = 34 then
    entry.extra_info := 0
  else
    entry.extra_info := reply.ent_extra;
end;
