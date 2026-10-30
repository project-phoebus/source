{ server_get_entry - look a requested name up in a directory.

  Image addresses:
    sau2  0x00E62D4A  server_get_entry (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).  The name is mapped back from the network's case for the
    lookup and to it for the reply.

  Status stored (in the reply):
    dir_$get_entryu's status: the lookup
    name_$leaf_truncated: the name was cut to 32 characters
}

  procedure server_get_entry(var request: rem_file_$server_req_t;
                             var response: rem_file_$server_resp_t);
  var
    entry: rem_file_$entry_view_t;
    truncated: boolean;
  begin
    server_unmap_name(request.req.ent_name, request.req.ent_name_len);

    dir_$get_entryu(request.req.uid, request.req.ent_name,
                    request.req.ent_name_len, entry.entry,
                    response.reply.hdr.status);
    if response.reply.hdr.status.code <> 0 then
      return;

    map_case(request.req.ent_name, request.req.ent_name_len,
             response.reply.ent_name, 16#20, response.reply.ent_name_len,
             truncated);
    if truncated then begin
      response.reply.ent_name_len := 32;
      response.reply.hdr.status.all := name_$leaf_truncated;
    end;

    response.reply.ent_type := entry.entry.entry_type;
    response.reply.ent_data := entry.data;
  end;
