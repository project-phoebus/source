{ server_drop_link - serve a remote DROP_HARD_LINKU (opcode 16#28).

  Image addresses:
    sau2  0x00E63096  server_drop_link (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - A locksmith request is served super-user with auditing suspended,
    under the locksmith's login SID; the server's SIDs and mode are put
    back whatever failed on the way.
  - A "directory locked" reply is marked for the client and counted.

  Status stored (in the reply):
    dir_$old_drop_hard_linku's status: the link was dropped, or not
    the ACL routines' status: the locksmith's SIDs could not be set up
}

  procedure server_drop_link;
  label
    10;
  var
    saved_sids2: acl_sid_block_t;
    saved_sids1: acl_sid_block_t;
    saved_proj2: acl_prot_info_t;
    saved_proj1: acl_prot_info_t;
    temp_status: status_$t;
  begin
    server_unmap_name(request.dl_name, request.dl_name_len);

    if request.dl_as_locksmith then begin
      acl_$enter_super;
      audit_$suspend;
      acl_$override_local_locksmith(true, response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;
      acl_$get_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                           saved_proj2, response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;
      saved_sids2.login_sid := acl_$locksmith_uid;
      acl_$set_re_all_sids(saved_sids2, saved_sids2, saved_proj1,
                           saved_proj2, response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;
    end;

    dir_$old_drop_hard_linku(request.dl_uid, request.dl_name,
                             request.dl_name_len, request.dl_flags,
                             response.reply.hdr.status);

    if request.dl_as_locksmith then begin
      saved_sids2.login_sid := uid_$nil;
      acl_$set_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                           saved_proj2, temp_status);
      acl_$override_local_locksmith(false, temp_status);
  10:
      audit_$resume;
      acl_$exit_super;
    end;

    if response.reply.hdr.status.all = status_$naming_directory_locked then
    begin
      response.reply.hdr.pkt_flag := -1;
      rem_file_$stale_link_count := rem_file_$stale_link_count + 1;
    end;

    reply_len := 8;
  end;
