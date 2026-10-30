{ REM_FILE_$UNLOCK - release a lock held on an object's home node.

  Image addresses:
    sau2  0x00E61D1C  REM_FILE_$UNLOCK

  - A reply of more than 8 bytes gives its times to AST_$SET_DTS (its
    status dropped): the modification time when nonzero, the access time
    when release_flag is set and a 22-byte reply carries it.
  - The result is the reply's answer, false for a shorter reply; the
    send's status is not tested.

  Status stored:
    rem_file_$send_request's status: always
}

function rem_file_$unlock(in location: file_$obj_loc_t;
                          unlock_mode: integer; rem_key: integer32;
                          lock_key: integer; rem_node: integer32;
                          release_flag: boolean;
                          out status: status_$t): boolean;
  options(val_param);
const
  ast_set_dts_dtv = 2;
  ast_set_dts_dtu = 8;
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  dts_status: status_$t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
  dts_flags: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_unlock;
  request.uid := location.uid;
  request.unlock_rem_key := rem_key;
  request.unlock_rem_node := rem_node;
  request.unlock_key := lock_key;
  request.unlock_mode := unlock_mode;
  request.unlock_version := rem_file_req_version;
  request.unlock_super := acl_$super_count[proc1_$current] > 0;
  request.unlock_release := release_flag;

  nil_word := 0;
  rem_file_$send_request(location.loc_info, request, 34, nil_word, 0,
                         reply, 190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if received_len > 8 then begin
    dts_flags := 0;
    if reply.dtv.high <> 0 then
      dts_flags := ast_set_dts_dtv;
    if release_flag and then reply.attrs_valid and then
       (received_len >= 22) then
      dts_flags := dts_flags ! ast_set_dts_dtu;
    if dts_flags <> 0 then
      discard(ast_$set_dts(dts_flags, location.uid, reply.dtv, reply.dtu,
                           dts_status));
    rem_file_$unlock := reply.unlock_result;
  end
  else
    rem_file_$unlock := false;
end;
