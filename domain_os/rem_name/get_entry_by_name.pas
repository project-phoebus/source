{ REM_NAME_$GET_ENTRY_BY_NAME - ask a naming server for a directory's
  entry by its name.

  Image addresses:
    sau2  0x00E4A588  REM_NAME_$GET_ENTRY_BY_NAME

  - An ordinary entry (reply type 1) gets type 1, its UID and extra
    word; a link (2) type 3 and the nil UID; any other type 0.

  Status stored:
    rem_name_$send_request's status: the entry was returned, or the
      request failed
    name_$bad_pathname: name is longer than 32 characters
    name_$not_found: the reply's type is neither
}

{ TODO(pascal) six frame bytes of REM_NAME_$GET_ENTRY_BY_NAME hold
  nothing

  Below reply_len the SAU2 frame has 6 bytes that no instruction
  addresses (unused_6 holds them).  GET_INFO, LOCATE_SERVER,
  GET_ENTRY_BY_NODE_ID and GET_ENTRY_BY_UID have the same 6 bytes right
  below their reply_len: one declaration the five routines share, not
  seen in the code.  Not settled. }

procedure rem_name_$get_entry_by_name(net: integer32;
                                      node: integer32;
                                      in dir_uid: uid_$t;
                                      in name: univ rem_name_$name_t;
                                      name_len: pinteger;
                                      out entry: rem_name_$dir_entry_t;
                                      out status: status_$t);
  options(val_param);
var
  reply: rem_name_$reply_t;
  request: rem_name_$by_name_req_t;
  req: ^rem_name_$by_name_req_t;
  i: pinteger;
  reply_len: integer;
  unused_6: array[1..3] of integer;       { the TODO above }
begin
  if name_len > 32 then begin
    status.all := name_$bad_pathname;
    return;
  end;

  { the request }
  req := addr(request);
  req^.opcode := 16#10001;
  req^.dir_uid := dir_uid;
  req^.one := 1;
  req^.name_len := name_len;
  for i := 1 to name_len do
    req^.name[i] := name[i];

  if rem_name_$send_request(net, node, req^, 52 + name_len, 0, 2,
                            reply, rem_name_reply_size, reply_len,
                            status) then begin
    entry.name_len := reply.name_len;
    entry.name := reply.name;

    case reply.entry_type of
      entry_type_normal: begin
          entry.entry_type := entry_type_normal;
          entry.data := reply.data;
        end;
      entry_type_link: begin
          entry.entry_type := entry_type_link_alt;
          entry.uid := uid_$nil;
          entry.extra := 0;
        end;
      otherwise begin
          status.all := name_$not_found;
          entry.entry_type := 0;
        end;
    end;
  end;
end;
