{ DIR_$DO_OP - carry out a directory operation, here or on the node that
  holds the directory.

  Image addresses:
    sau2  0x00E4C02C  DIR_$DO_OP

  - A server process (type 9) asks only this node; other callers try
    the nodes HINT_$GET_HINTS gives.
  - A locked remote directory is retried at the same hint up to 20
    times; a retryable failure, or a local "object not found", moves on.
  - A success at a hint other than the first enters it (HINT_$ADDI); a
    remote reply naming an object on another node updates the hint file.
  - An operation code outside dir_$op_tab crashes the system.

  Status stored (in the reply):
    rem_file_$rn_do_op's status: a remote node answered
    the handler's status: the local node answered
    file_$bad_reply_received_from_remote_node: a remote reply of the
      wrong version, or the hints ran out after a bad reply
    file_$object_not_found: the hints ran out
}

procedure dir_$do_op(var request: univ dir_$request_t; req_size: integer;
                     resp_size: integer; var response: univ dir_$reply_t;
                     var received_len: integer);
var
  entry_uid: uid_$t;
  local_uid: dir_$uid_view_t;
  hints: hint_$addr_list_t;
  status: status_$t;
  retries: integer;
  volume: integer;
  hint_count: integer;
  i: integer;
  is_server: boolean;
  op_code: pinteger;
  op_half: pinteger;
  size: linteger;
begin
  local_uid.uid := request.uid;
  op_code := request.op;
  op_half := op_code div 2;

  status.all := file_$object_not_found;
  is_server := proc1_$type[proc1_$current] = 9;
  response.flags := [];

  { where to look }
  if is_server then begin
    hint_count := 1;
    hints[1].node_id := node_$me;
    hints[1].flags := 0;
  end
  else begin
    request.proc_flags := [1];
    hint_count := hint_$get_hints(local_uid.uid, hints);
    request.reply_version := dir_$op_tab[op_half].reply_version;
  end;

  dir_$proc_flags[proc1_$current] := request.proc_flags;

  i := 0;
  retries := 0;
  while i < hint_count do begin
    i := i + 1;
    if hints[i].node_id <> node_$me then begin
      { a remote node }
      request.remote := 1;
      request.unused_10 := 0;
      rem_file_$rn_do_op(hints[i].flags, request, req_size + 16#8E,
                         resp_size, response, received_len);

      if response.status.all <> status_$ok then begin
        if response.status.all = status_$naming_directory_locked then begin
          hint_count := i;
          retries := retries + 1;
          if retries >= 20 then
            return;
          i := i - 1;
        end
        else begin
          if not dir_$is_retryable_status(response.status) then
            return;
          if response.status.all = file_$bad_reply_received_from_remote_node
          then
            status.all := file_$bad_reply_received_from_remote_node;
        end;
      end
      else begin
        { the reply's versions }
        if (response.version > 0) or else
           (response.reply_version > dir_$op_tab[op_half].reply_version)
        then begin
          response.status.all := file_$bad_reply_received_from_remote_node;
          return;
        end;

        if i <> 1 then
          hint_$addi(local_uid.uid, hints[i]);
        response.flags := response.flags + [0];

        { an object on another node }
        if response.entry.b0 <> 0 then
          if ((local_uid.uid.low & 16#FFFFF) <>
              (response.entry.uid.low & 16#FFFFF)) and then
             (op_code = dir_op_resolve) then
            dir_$update_hint(local_uid.uid, hints[i].flags,
                             hints[i].node_id, response.entry.uid,
                             response.redirect)
          else if (response.entry.b0 <> 0) and then
                  (local_uid.b0 <> 0) and then
                  ((local_uid.uid.low & 16#FFFFF) <>
                   (response.entry.uid.low & 16#FFFFF)) and then
                  (op_code = dir_op_get_entryu_op) and then
                  (response.len = 1) then
            dir_$update_hint(local_uid.uid, hints[i].flags,
                             hints[i].node_id, response.entry.uid,
                             response.extra);
        return;
      end;
    end
    else begin
      { the local node }
      with dir_$op_tab[op_half] do begin
        received_len := 20 + reply_size;
        response.reply_version := reply_version;
      end;
      response.version := 0;

      case op_code of
        dir_op_addu: begin
          if request.add_entry.flags = 0 then
            dir_$do_op_add_link(local_uid.uid, request.add_entry.name,
                                request.add_entry.path_len,
                                request.add_entry.file_uid, false,
                                response.status)
          else
            dir_$do_op_add_entry(local_uid.uid, 2, request.add_entry.name,
                                 request.add_entry.path_len, 3,
                                 request.add_entry.flags,
                                 request.add_entry.file_uid, 0, '',
                                 volume, response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#12, response.status, local_uid.uid,
                              request.add_entry.file_uid,
                              request.add_entry.path_len,
                              request.add_entry.name);
        end;
        dir_op_add_hard_linku: begin
          dir_$do_op_add_link(local_uid.uid, request.uid_name.name,
                              request.uid_name.path_len,
                              request.uid_name.target_uid, true,
                              response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#1F, response.status, local_uid.uid,
                              request.uid_name.target_uid,
                              request.uid_name.path_len,
                              request.uid_name.name);
        end;
        dir_op_drop_hard_linku: begin
          dir_$do_op_delete(local_uid.uid, request.word_name.name,
                            request.word_name.path_len,
                            0 in request.word_name.flags, true, true,
                            entry_uid, response.uid, response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#20, response.status, local_uid.uid,
                              response.uid, request.word_name.path_len,
                              request.word_name.name);
        end;
        dir_op_code_30: begin
          dir_$do_op_delete(local_uid.uid, request.name_body.name,
                            request.name_body.path_len, true, true, true,
                            entry_uid, response.uid, response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#13, response.status, local_uid.uid,
                              response.uid, request.name_body.path_len,
                              request.name_body.name);
        end;
        dir_op_cnameu: begin
          dir_$do_op_cname(local_uid.uid, request.version,
                           request.cname.name, request.cname.old_len,
                           request.raw[dir_$op_tab[25].base_size +
                                       request.cname.old_len],
                           request.cname.new_len, response.status);
          if audit_$enabled then
            audit_$log_cname_op(16#18, response.status, local_uid.uid,
                                request.cname.old_len,
                                request.cname.new_len, request.cname.name,
                                request.raw[dir_$op_tab[25].base_size +
                                            request.cname.old_len]);
        end;
        dir_op_add_baku: begin
          dir_$do_op_add_bak(local_uid.uid, request.version,
                             request.uid_name.name,
                             request.uid_name.path_len,
                             request.uid_name.target_uid, response.uid,
                             response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#19, response.status, local_uid.uid,
                              request.uid_name.target_uid,
                              request.uid_name.path_len,
                              request.uid_name.name);
        end;
        dir_op_delete_fileu: begin
          dir_$do_op_delete(local_uid.uid, request.delete_file.name,
                            request.delete_file.path_len,
                            request.delete_file.flag0,
                            request.delete_file.flag1, false, entry_uid,
                            response.uid, response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#13, response.status, local_uid.uid,
                              response.uid, request.delete_file.path_len,
                              request.delete_file.name);
        end;
        dir_op_create_diru: begin
          dir_$do_op_create_dir(local_uid.uid, request.name_body.name,
                                request.name_body.path_len, response.uid,
                                response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#16, response.status, local_uid.uid,
                              response.uid, request.name_body.path_len,
                              request.name_body.name);
        end;
        dir_op_drop_diru: begin
          dir_$do_op_drop_dir(local_uid.uid, request.name_body.name,
                              request.name_body.path_len,
                              response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#17, response.status, local_uid.uid,
                              local_uid.uid, request.name_body.path_len,
                              request.name_body.name);
        end;
        dir_op_add_linku: begin
          dir_$do_op_add_entry(local_uid.uid, 2, request.add_link.name,
                               request.add_link.path_len, 4, 0, 0,
                               request.add_link.target_len,
                               request.add_link.target_ptr^, volume,
                               response.status);
          if audit_$enabled then
            audit_$log_link_op(16#1A, response.status, local_uid.uid,
                               request.add_link.path_len,
                               request.add_link.name,
                               request.add_link.target_len,
                               request.add_link.target_ptr^);
        end;
        dir_op_read_linku: begin
          dir_$do_op_read_linku(local_uid.uid, request.add_link.name,
                                request.add_link.path_len,
                                request.add_link.target_len,
                                request.add_link.target_ptr, response.len,
                                response.entry, response.status);
        end;
        dir_op_drop_linku: begin
          dir_$do_op_drop_entry(local_uid.uid, 2, request.name_body.name,
                                request.name_body.path_len, 4,
                                response.uid, response.status);
          if audit_$enabled then
            audit_$log_dir_op(16#1B, response.status, local_uid.uid,
                              response.uid, request.name_body.path_len,
                              request.name_body.name);
        end;
        dir_op_dir_readu: begin
          { the read's size }
          if is_server then begin
            size := 1024;
            if request.readu.max_size < size then
              size := request.readu.max_size;
            if size > 1024 then
              size := 1024;
          end
          else
            size := request.readu.max_size;

          if request.reply_version < response.reply_version then
            response.reply_version := request.reply_version;
          response.continuation := request.readu.continuation;

          dir_$do_op_dir_readu(local_uid.uid, response.reply_version,
                               request.readu.name, request.readu.name_len,
                               response.continuation,
                               request.readu.max_entries, size,
                               request.readu.buf_va, response.size,
                               response.last_offset, response.count,
                               response.status);
        end;
        dir_op_get_entryu_op: begin
          dir_$do_op_get_entryu(local_uid, request.name_body.name,
                                request.name_body.path_len, response.len,
                                response.entry, response.extra,
                                response.status);
        end;
        dir_op_find_uid: begin
          dir_$do_op_find_uid(local_uid.uid, request.find_uid.target_uid,
                              request.find_uid.flag, response.name,
                              response.name_len, response.find_extra,
                              response.status);
          if response.status.all = status_$ok then
            received_len := received_len + response.name_len;
        end;
        dir_op_fix_dir: begin
          dir_$do_op_fix_dir(local_uid.uid, response.status);
        end;
        dir_op_set_acl: begin
          dir_$do_op_set_acl(local_uid.uid, request.uid_body,
                             response.status);
        end;
        dir_op_set_default_acl: begin
          dir_$do_op_set_default_acl(local_uid.uid,
                                     request.uid_pair.acl_type_uid,
                                     request.uid_pair.acl_uid,
                                     response.status);
        end;
        dir_op_get_default_acl: begin
          dir_$do_op_get_default_acl(local_uid.uid, request.uid_body,
                                     response.uid_view, response.status);
        end;
        dir_op_validate_root_entry: begin
          dir_$do_op_validate_root_entry(request.name_body.name,
                                         request.name_body.path_len,
                                         response.status);
        end;
        dir_op_set_protection: begin
          dir_$do_op_set_prot(local_uid.uid, request.set_prot.prot,
                              request.set_prot.acl_uid,
                              request.set_prot.prot_type,
                              response.status);
          if audit_$enabled then
            audit_$log_prot_op(response.status, local_uid.uid,
                               request.set_prot.prot, acl_$dirin_acl,
                               request.set_prot.acl_uid,
                               request.set_prot.prot_type);
        end;
        dir_op_set_def_protection: begin
          dir_$do_op_set_def_prot(local_uid.uid,
                                  request.set_def_prot.acl_type_uid,
                                  request.set_def_prot.prot,
                                  request.set_def_prot.acl_uid,
                                  response.status);
          if audit_$enabled then
            audit_$log_prot_op(response.status, local_uid.uid,
                               request.set_def_prot.prot,
                               request.set_def_prot.acl_type_uid,
                               request.set_def_prot.acl_uid, 4);
        end;
        dir_op_get_def_protection: begin
          dir_$do_op_get_def_prot(local_uid.uid, request.uid_body,
                                  response.prot, response.def_acl,
                                  response.status);
        end;
        dir_op_resolve: begin
          response.state.bytes := request.resolve.state.bytes;

          dir_$do_op_resolve(request.resolve.path_ptr^,
                             request.resolve.path_len,
                             response.state.start_view, response.redirect,
                             response.state.resolved_uid, response.more,
                             response.loop, response.state.param5,
                             response.state.param6, response.state.param7,
                             response.state.param8, request.resolve.link_buf,
                             response.link_count, response.status);

          if audit_$enabled then
            if response.more and not response.loop and
               (response.status.all = status_$ok) then
              if response.link_count = 0 then
                audit_$log_resolve_op(request.resolve.path_ptr^,
                                      request.resolve.path_len,
                                      response.state.start_uid,
                                      response.status);
        end;
        dir_op_add_mount: begin
          dir_$do_op_add_mount(local_uid.uid, request.mount.mount_uid,
                               request.mount.node_id, response.status);
          if audit_$enabled then
            audit_$log_mount_op(16#1C, response.status, local_uid.uid,
                                request.mount.mount_uid,
                                request.mount.node_id);
        end;
        dir_op_drop_mount: begin
          dir_$do_op_drop_mount(request.mount.mount_uid,
                                request.mount.node_id, response.status);
          if audit_$enabled then
            audit_$log_mount_op(16#1D, response.status, local_uid.uid,
                                request.mount.mount_uid,
                                request.mount.node_id);
        end;
        otherwise begin
          crash_system(status_$naming_internal_error);
        end;
      end;

      { a local success }
      if response.status.all = status_$ok then begin
        if i <> 1 then
          hint_$addi(local_uid.uid, hints[i]);
        return;
      end;

      { another node may have it }
      if is_server or else
         (response.status.all <> status_$naming_directory_object_not_found)
      then
        return;
    end;
  end;

  response.status := status;
end;
