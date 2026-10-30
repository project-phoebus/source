{ DIR_$RESOLVE - resolve a pathname through DIR_$DO_OP.

  Image addresses:
    sau2  0x00E4D356  DIR_$RESOLVE

  - Operation-16#58 requests, round by round: each carries the current
    directory, the resolved UID and four position words, and a reply
    marked "more" gives them back; rounds repeat while it says "loop".
  - The link count is cleared first.

  Status stored:
    the last reply's status: a pathname was sent
    name_$bad_pathname: a pathname of length 0 or over 1023
}

{ TODO(pascal) DIR_$RESOLVE's request local is 0x100 bytes longer than
  its operation's

  The image's frame gives the request 0x1B0 bytes (it and the reply
  both 8-aligned); its header and resolve body (dir/dir.ins.pas
  dir_$req_hdr_t, dir_$req_resolve_t) make 0xB0, the size DIR_$DO_OP is
  given, dir_$op_tab[44].base_size = 16#22 past the header.  No
  instruction of DIR_$RESOLVE, DIR_$DO_OP's 16#58 arm or
  dir_$do_op_resolve addresses request bytes from +0xB0 to +0x1AF.  The
  stand-in unused_b0 (256 bytes, the size of a name_$long_name_t) holds
  the place; whether the original's request record had a variant or a
  field there (DIR_$GET_ENTRYU's nested routine's request is exactly its
  header and body, 0x190 bytes) is not known. }

procedure dir_$resolve(in path: univ name_$long_pname_t; in path_len: pinteger;
                       in out dir_uid: uid_$t; in out resolved_uid: uid_$t;
                       in out param5: dir_$path_index_t;
                       in out param6: pinteger;
                       in out param7: dir_$path_index_t;
                       in out param8: pinteger;
                       var link_buf: univ name_$long_pname_t;
                       out link_count: integer; out status_ret: status_$t);
var
  response: dir_$resolve_reply_t;
  request: dir_$resolve_req_t;
  received_len: integer;
begin
  link_count := 0;

  if (path_len = 0) or else (path_len > 1023) then begin
    status_ret.all := name_$bad_pathname;
    return;
  end;

  request.hdr.op := dir_op_resolve;
  request.hdr.version := dir_$op_tab[44].version;
  request.body.link_buf := addr(link_buf);
  request.body.path_len := path_len;
  request.body.path_ptr := addr(path);

  repeat
    request.hdr.uid := dir_uid;
    request.body.state.start_uid := dir_uid;
    request.body.state.resolved_uid := resolved_uid;
    request.body.state.param5 := param5;
    request.body.state.param6 := param6;
    request.body.state.param7 := param7;
    request.body.state.param8 := param8;
    response.more := false;

    dir_$do_op(request, dir_$op_tab[44].base_size, 16#34, response,
               received_len);

    status_ret := response.hdr.status;
    if not response.more then
      return;

    dir_uid := response.state.start_uid;
    resolved_uid := response.state.resolved_uid;
    link_count := response.link_count;
    param5 := response.state.param5;
    param6 := response.state.param6;
    param7 := response.state.param7;
    param8 := response.state.param8;

  until not response.loop;
end;
