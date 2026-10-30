{ ACL_$SERVER - the ACL half of the remote-file server.

  Image addresses:
    sau2  0x00E49594  ACL_$SERVER

  - The opcodes: ACL_IMAGE (16#64, under ml_$acl_lock), ACL_CREATE
    (16#68), ACL_CHECK_RIGHTS (16#6C), ACL_SETIDS (16#6A), SET_ACL (16#66).
  - SET_ACL runs ACL_$SET_ACL_CHECK with the requester's SIDs and
    projects, then restores the server's.
  - ACL_IMAGE mode 4's rebuild runs whatever acl_$image_internal's
    status.
  - SET_ACL's restore reports into a local status.

  Status stored (in the reply):
    the operation's routine's status: a known opcode
    file_$bad_reply_received_from_remote_node: any other opcode (the
      reply opcode 3)
}

procedure acl_$server(var req: acl_$srv_req_t; out resp: acl_$srv_resp_t;
                      out reply_len: pinteger);
label
  10;
var
  subsys: uid_$t;
  cur_proj: acl_proj_list_t;
  saved_proj: acl_proj_list_t;
  proj_list: acl_$proj_uids_t;
  cur_sids: acl_sid_block_t;
  orig_sids: acl_sid_block_t;
  prot: acl_$prot_data_t;
  funky_prot: acl_$prot_data_t;
  acl_uid: uid_$t;
  buf: acl_$cache_slot_ptr_t;
  acl_data: acl_$cache_slot_ptr_t;
  restore_status: status_$t;
  status: status_$t;
  type_bits: integer;
  proj_count: integer;
  setid: boolean;
  create_flag: boolean;
  funky: boolean;
  image_flag_out: boolean;
  restore_sids: boolean;
  restore_proj: boolean;
begin
  { the reply's header }
  reply_len := 60;
  resp.flags := 16#80;
  resp.opcode := req.opcode + 1;
  resp.one := 1;

  case req.opcode of
    rem_file_op_acl_image: begin
      { ACL_IMAGE, the ACL's UID }
      funky := false;
      create_flag := false;
      type_bits := rshft(acl_$uid_view_t(req.uid).w2 & 16#FF0, 4);
      if (type_bits & 16#E0) <> 0 then begin
        funky := true;
        acl_$convert_funky_acl(req.uid, funky_prot, acl_uid, subsys,
                               status);
        if (type_bits & 16#60) <> 0 then
          create_flag := true;
      end
      else begin
        acl_uid := req.uid;
        status.all := status_$ok;
      end;

      { the image }
      if status.all = status_$ok then begin
        ml_$lock(ml_$acl_lock);
        if req.mode = 4 then begin
          buf := addr(acl_$image_buf);
          req.flag := true;
        end
        else
          buf := req.buf;
        acl_$image_internal(acl_uid, 1024, req.flag, buf^, resp.image_len,
                            prot, image_flag_out, status);
        resp.image_prot := prot;
        if req.mode = 4 then begin
          if funky then
            prot := funky_prot;
          if acl_uid = uid_$nil then begin
            acl_$image_buf.type_uid := subsys;
            acl_$image_buf.subsys_uid := subsys;
          end;
          acl_$prim_create_internal(prot, buf^, resp.image_len, subsys,
                                    create_flag, req.buf^, resp.image_len,
                                    status);
        end;
        ml_$unlock(ml_$acl_lock);
      end;

      resp.status := status;
      reply_len := 56;
    end;

    rem_file_op_acl_create: begin
      { ACL_CREATE }
      acl_data := req.acl_data;
      acl_uid := req.create_acl_uid;
      acl_$prim_create(acl_data^, acl_data^.entry_count * 32 + 52,
                       req.uid, req.create_prot, acl_uid, resp.status);
      resp.created_uid := acl_uid;
      reply_len := 20;
    end;

    rem_file_op_acl_check_rights: begin
      { ACL_CHECK_RIGHTS }
      resp.rights := acl_$eval_rights(req.rights_sids, req.rights_proj,
                                      req.uid, req.ignore_super,
                                      req.required_mask, req.option_flags,
                                      req.in_super, req.in_subsys,
                                      resp.status);
      reply_len := 16;
    end;

    rem_file_op_acl_setids: begin
      { ACL_SETIDS }
      acl_$setids(req.uid, true, req.setids_sids, req.owner_ext,
                  resp.changed, resp.status);
      resp.sids_bytes := req.sids_bytes;
      reply_len := 60;
    end;

    rem_file_op_set_acl: begin
      { SET_ACL, the requester's SIDs swapped in }
      restore_sids := false;
      restore_proj := false;
      acl_$enter_super;
      acl_$get_re_all_sids(orig_sids, cur_sids, saved_proj, cur_proj,
                           resp.status);
      if resp.status.all <> status_$ok then
        goto 10;
      acl_$get_proj_list(proj_list, 8, proj_count, resp.status);
      if resp.status.all <> status_$ok then
        goto 10;
      acl_$set_re_all_sids(orig_sids, req.new_sids, saved_proj, cur_proj,
                           resp.status);
      if resp.status.all <> status_$ok then
        goto 10;
      restore_sids := true;
      acl_$set_proj_list(req.new_proj, req.proj_count, resp.status);
      if resp.status.all <> status_$ok then
        goto 10;
      restore_proj := true;
      acl_$exit_super;
      discard(acl_$set_acl_check(req.uid, req.set_prot, req.set_acl_uid,
                                 req.op_type, setid, resp.status));
      acl_$enter_super;

      { what was swapped in, restored }
    10:
      if restore_sids then
        acl_$set_re_all_sids(orig_sids, cur_sids, saved_proj, cur_proj,
                             restore_status);
      if restore_proj then
        acl_$set_proj_list(proj_list, proj_count, restore_status);
      acl_$exit_super;
      reply_len := 8;
    end;

    otherwise begin
      resp.status.all := file_$bad_reply_received_from_remote_node;
      resp.opcode := 3;
    end;
  end;
end;
