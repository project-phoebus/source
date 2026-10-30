{ REM_NAME_$LOCATE_SERVER - find a naming server, on this node first,
  then by broadcast.

  Image addresses:
    sau2  0x00E4A722  REM_NAME_$LOCATE_SERVER

  - The naming server on this node, when it runs there, is asked first;
    a 40-byte answer settles it.  Else the request is broadcast.
  - The server's node (the answer's longword at 0x1E, 20 bits) and
    network 0 go to the caller and to REM_NAME_$CURR_NODE and _$CURR_NET.
  - The status goes to REM_NAME_$LAST_STATUS, but for a failed
    broadcast.

  Status stored:
    rem_name_$send_request's status: a server answered, or the broadcast
      failed
    status_$naming_helper_sent_packets_with_errors: the broadcast's
      answer is under 40 bytes
}

procedure rem_name_$locate_server(out node_ret: integer32;
                                  out net_ret: integer32;
                                  out status: status_$t);
label
  found, done;
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
  req^.opcode := 16#1001D;
  req^.one := 1;

  { the server on this node }
  if rem_name_server_local then
    if rem_name_$send_request(0, node_$me, req^, 50, 0, 16#1E, reply,
                              rem_name_reply_size, reply_len,
                              status) then
      if reply_len = 40 then
        goto found;

  { a broadcast }
  if not rem_name_$send_request(0, 16#FFFFFF, req^, 50, 16#80, 16#1E,
                                reply, rem_name_reply_size, reply_len,
                                status) then
    return;
  if reply_len < 40 then begin
    status.all := status_$naming_helper_sent_packets_with_errors;
    goto done;
  end;

found:
  net_ret := 0;
  node_ret := reply.server_node & 16#FFFFF;
  rem_name_$curr_net := 0;
  rem_name_$curr_node := reply.server_node & 16#FFFFF;

done:
  rem_name_$last_status := status;
end;
