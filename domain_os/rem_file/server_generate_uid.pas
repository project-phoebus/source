{ server_generate_uid - serve a remote GENERATE_UID (opcode 16#24).

  Image addresses:
    sau2  0x00E632C2  server_generate_uid (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - A UID that names an existing object is generated again, up to
    eleven tries.

  Status stored (in the reply):
    status_$ok: the UID names no object
    ast_$get_location's status: eleven UIDs named objects, or the lookup
      failed
}

  procedure server_generate_uid;
  var
    probe: file_$obj_loc_t;
    vol_uid: ast_$location_t;
  begin
    uid_retry := 0;

    repeat
      uid_retry := uid_retry + 1;
      uid_$gen(response.reply.reply_uid);
      probe.flags := probe.flags - [6];
      probe.uid := response.reply.reply_uid;
      ast_$get_location(probe, 1, location_unused, vol_uid,
                        response.reply.hdr.status);
    until (response.reply.hdr.status.all = file_$object_not_found) or else
          (uid_retry > 10);

    if response.reply.hdr.status.all = file_$object_not_found then
      response.reply.hdr.status.all := status_$ok;

    reply_len := 18;
  end;
