{ server_truncate_delete - serve a remote TRUNCATE (opcode 16#08).

  Image addresses:
    sau2  0x00E631C2  server_truncate_delete (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - The request's flag selects a delete; a current client's delete of an
    object of type 0 sets its attribute 7 first.
  - A truncate hands back the object's DTA in a 16-byte reply.

  Status stored (in the reply):
    status_$ok: the object was deleted or truncated
    the callees' status: a step failed (status_$ast_refcount_says_unused
      from the attribute read does not stop it)
}

  procedure server_truncate_delete;
  var
    value: file_$attr_value_t;
  begin
    response.reply.hdr.status.all := status_$ok;
    response.reply.reply_loc.uid := request.req.uid;
    response.reply.reply_loc.flags := response.reply.reply_loc.flags - [6];

    if request.req.trunc_flags and then (request.req.hdr.magic = 0) then
    begin
      ast_$get_attributes(response.reply.reply_loc, 16#81,
                          response.reply.reply_attrs,
                          response.reply.hdr.status);
      if (response.reply.hdr.status.all = status_$ok) and then
         (response.reply.reply_attrs.byte_00 = 0) then begin
        value.word_val := 1;
        ast_$set_attribute(request.req.uid, 7, value,
                           response.reply.hdr.status);
      end;
    end;

    reply_len := 8;

    if (response.reply.hdr.status.all = status_$ok) or else
       (response.reply.hdr.status.all = status_$ast_refcount_says_unused)
    then
      if request.req.trunc_flags then
        discard(file_$delete(request.req.uid, response.reply.hdr.status))
      else begin
        ast_$truncate(request.req.uid, request.req.trunc_size, 0,
                      trunc_result, response.reply.hdr.status);
        ast_$get_attributes(response.reply.reply_loc, 16#80,
                            response.reply.reply_attrs,
                            response.reply.hdr.status);
        response.reply.reply_clock := response.reply.reply_attrs.dta;
        reply_len := 16;
      end;
  end;
