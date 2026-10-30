{ REM_NAME_$GET_INFO - ask a naming server for an object's 22 bytes of
  information.

  Image addresses:
    sau2  0x00E4A690  REM_NAME_$GET_INFO

  Status stored:
    rem_name_$send_request's status: the information was returned, or
      the request failed
    status_$naming_helper_sent_packets_with_errors: the reply is not 40
      bytes long
}

procedure rem_name_$get_info(net: integer32;
                             node: integer32;
                             in uid: uid_$t;
                             out info: rem_name_$info_t;
                             out status: status_$t);
  options(val_param);
var
  reply: rem_name_$reply_t;
  request: rem_name_$req_t;
  req: ^rem_name_$req_t;
  reply_len: integer;
  unused_6: array[1..3] of integer;       { see the TODO(pascal) in
                                            rem_name/get_entry_by_name.pas }
begin
  { the request }
  req := addr(request);
  req^.opcode := 16#10019;
  req^.uid := uid;
  req^.one := 1;

  if rem_name_$send_request(net, node, req^, 50, 0, 16#1A, reply,
                            rem_name_reply_size, reply_len, status) then
    if reply_len = 40 then
      info := reply.info
    else
      status.all := status_$naming_helper_sent_packets_with_errors;
end;
