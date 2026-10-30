{ server_set_prot_attrib - serve a remote FILE_SET_PROT (opcode 16#80) or
  FILE_SET_ATTRIB (16#82).

  Image addresses:
    sau2  0x00E63344  server_set_prot_attrib (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - The change is made under the requester's SIDs and project list (from
    the request's extended SID), the server's own saved and put back.
  - On success the object's attributes are read into the reply.
  - prot_type is set only in the case arms.

  Status stored (in the reply):
    file_$set_prot_int's or file_$set_attribute's status: the change
    the ACL routines' status: the requester's SIDs could not be set up
}

  procedure server_set_prot_attrib;
  label
    10;
  type
    exsid_ptr_t = ^acl_$exsid_t;
    proj_ptr_t = ^acl_$proj_uids_t;
  var
    sids_set: boolean;
    proj_set: boolean;
    exsid_p: exsid_ptr_t;
    proj_p: proj_ptr_t;
    saved_proj_list: acl_$proj_uids_t;
    saved_proj2: acl_prot_info_t;
    saved_proj1: acl_prot_info_t;
    saved_sids2: acl_sid_block_t;
    saved_sids1: acl_sid_block_t;
    temp_status: status_$t;
    saved_proj_count: integer;
    prot_type: integer;
  begin
    reply_len := 190;

    if request.req.hdr.opcode = rem_file_op_file_set_prot then
      case request.req.fsp_type of
        rem_file_prot_attr_type0: prot_type := file_$prot_owner1;
        rem_file_prot_attr_type1: prot_type := file_$prot_owner2;
        rem_file_prot_attr_type2: prot_type := file_$prot_owner3;
        rem_file_prot_attr_type3: prot_type := file_$prot_rights;
        rem_file_prot_attr_type4: prot_type := file_$prot_acl_image;
        rem_file_prot_attr_type5: prot_type := file_$prot_merge_acl;
        rem_file_prot_attr_acl: prot_type := file_$prot_acl;
      end;

    sids_set := false;
    proj_set := false;
    acl_$enter_super;
    audit_$suspend;
    acl_$get_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                         saved_proj2, response.reply.hdr.status);
    if response.reply.hdr.status.all <> status_$ok then
      goto 10;
    acl_$get_proj_list(saved_proj_list, 8, saved_proj_count,
                       response.reply.hdr.status);
    if response.reply.hdr.status.all <> status_$ok then
      goto 10;

    if request.req.hdr.opcode = rem_file_op_file_set_prot then
      exsid_p := addr(request.req.fsp_exsid)
    else
      exsid_p := addr(request.req.fsa_exsid);
    acl_$set_re_all_sids(saved_sids1, exsid_p^.sids, saved_proj1,
                         saved_proj2, response.reply.hdr.status);
    if response.reply.hdr.status.all <> status_$ok then
      goto 10;

    sids_set := true;
    if request.req.hdr.opcode = rem_file_op_file_set_prot then
      proj_p := addr(request.req.fsp_exsid.proj_uids)
    else
      proj_p := addr(request.req.fsa_exsid.proj_uids);
    acl_$set_proj_list(proj_p^, 8, response.reply.hdr.status);
    if response.reply.hdr.status.all <> status_$ok then
      goto 10;

    proj_set := true;
    audit_$resume;
    acl_$exit_super;

    if request.req.hdr.opcode = rem_file_op_file_set_prot then
      file_$set_prot_int(request.req.uid, request.req.fsp_value,
                         request.req.fsp_type, prot_type,
                         request.req.fsp_subsys, response.reply.hdr.status)
    else
      file_$set_attribute(request.req.uid, request.req.fsa_attr_id,
                          request.req.fsa_value, request.req.fsa_rights,
                          request.req.fsa_options,
                          response.reply.hdr.status);

    if response.reply.hdr.status.all = status_$ok then begin
      response.reply.reply_loc.uid := request.req.uid;
      ast_$get_attributes(response.reply.reply_loc, 16#81,
                          response.reply.reply_attrs,
                          response.reply.hdr.status);
    end;

    acl_$enter_super;
    audit_$suspend;

  10:
    if sids_set then
      acl_$set_re_all_sids(saved_sids1, saved_sids2, saved_proj1,
                           saved_proj2, temp_status);
    if proj_set then
      acl_$set_proj_list(saved_proj_list, saved_proj_count, temp_status);
    audit_$resume;
    acl_$exit_super;
  end;
