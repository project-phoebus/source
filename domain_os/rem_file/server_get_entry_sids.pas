{ server_get_entry_sids - serve a remote GET_ENTRY (opcode 16#1C).

  Image addresses:
    sau2  0x00E62F54  server_get_entry_sids (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - A 50-byte request (the old protocol) is looked up directly; a newer
    one under the requester's SIDs and project list, the server's own
    saved and put back whatever failed on the way.

  Status stored (in the reply):
    server_get_entry's status: the lookup was made
    the ACL routines' status: the requester's SIDs or projects could not
      be set up
}

  procedure server_get_entry_sids;
  label
    10;
  var
    sids_set: boolean;
    proj_set: boolean;
    saved_proj_list: acl_$proj_uids_t;
    saved_proj2: acl_prot_info_t;
    saved_proj1: acl_prot_info_t;
    saved_sids2: acl_sid_block_t;
    saved_sids1: acl_sid_block_t;
    temp_status: status_$t;
    proj_count: integer;
  begin
    if request_len = 50 then
      server_get_entry(request, response)
    else begin
      sids_set := false;
      proj_set := false;
      acl_$enter_super;
      audit_$suspend;

      acl_$get_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                           saved_proj2, response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;
      acl_$get_proj_list(saved_proj_list, 8, proj_count,
                         response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;

      acl_$set_re_all_sids(saved_sids1, request.req.ent_re_sids,
                           saved_proj1, saved_proj2,
                           response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;
      sids_set := true;
      acl_$set_proj_list(request.req.ent_proj, request.req.ent_proj_count,
                         response.reply.hdr.status);
      if response.reply.hdr.status.all <> status_$ok then
        goto 10;

      proj_set := true;
      audit_$resume;
      acl_$exit_super;
      server_get_entry(request, response);
      acl_$enter_super;
      audit_$suspend;

  10:
      if sids_set then
        acl_$set_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                             saved_proj2, temp_status);
      if proj_set then
        acl_$set_proj_list(saved_proj_list, proj_count, temp_status);
      audit_$resume;
      acl_$exit_super;
    end;

    reply_len := 56;
  end;
