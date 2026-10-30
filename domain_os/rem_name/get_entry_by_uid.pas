{ REM_NAME_$GET_ENTRY_BY_UID - ask a naming server for a directory's
  entry by an object's UID.

  Image addresses:
    sau2  0x00E4A8CC  REM_NAME_$GET_ENTRY_BY_UID

  - Only an ordinary entry (reply type 1) is returned, type 1.

  Status stored:
    rem_name_$send_request's status: the entry was returned, or the
      request failed
    name_$not_found: the reply's type is not 1
}

procedure rem_name_$get_entry_by_uid(net: integer32;
                                     node: integer32;
                                     in dir_uid: uid_$t;
                                     in target_uid: uid_$t;
                                     out entry: rem_name_$dir_entry_t;
                                     out status: status_$t);
  options(val_param);
var
  reply: rem_name_$reply_t;
  request: rem_name_$by_uid_req_t;
  req: ^rem_name_$by_uid_req_t;
  reply_len: integer;
  unused_6: array[1..3] of integer;       { see the TODO(pascal) in
                                            rem_name/get_entry_by_name.pas }
begin
  { the request }
  req := addr(request);
  req^.opcode := 16#1001B;
  req^.dir_uid := dir_uid;
  req^.one := 1;
  req^.target_uid := target_uid;

  if rem_name_$send_request(net, node, req^, 58, 0, 16#1C, reply,
                            rem_name_reply_size, reply_len,
                            status) then begin
    entry.name_len := reply.name_len;
    entry.name := reply.name;

    case reply.entry_type of
      entry_type_normal: begin
          entry.entry_type := entry_type_normal;
          entry.data := reply.data;
        end;
      otherwise begin
          status.all := name_$not_found;
          entry.entry_type := 0;
        end;
    end;
  end;
end;
