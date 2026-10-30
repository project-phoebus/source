{ DIR_$SET_PROTECTION - set an object's protection through its
  directory's server.

  Image addresses:
    sau2  0x00E52228  DIR_$SET_PROTECTION

  - An operation-16#52 request through DIR_$DO_OP.  For an old-format
    server an ACL not in the old form is converted (ACL_$CONVERT_TO_9ACL,
    against ACL_$DIR_ACL), and the object locked (FILE_$PRIV_LOCK, mode
    4), its protection set as type 6 and the lock released.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    file_$set_prot's status: an old-format server
    file_$incompatible_request: a protection type other than 4, 5 or 6
    acl_$convert_to_9acl's or file_$priv_lock's status: a step failed
}

procedure dir_$set_protection(in uid: uid_$t; in prot: acl_$prot_data_t;
                              in def_acl: uid_$t; in prot_type: integer;
                              out status_ret: status_$t);
var
  old_acl: uid_$t;
  response: dir_$reply_hdr_t;
  request: dir_$set_prot_req_t;
  lock_slot: linteger;
  dtv: time_$clock_t;
  local_status: status_$t;
  lock_rights: integer;
  received_len: integer;
begin
  request.hdr.op := dir_op_set_protection;
  request.hdr.uid := uid;
  request.hdr.version := dir_$op_tab[41].version;
  request.prot := prot;
  request.acl_uid := def_acl;
  request.prot_type := prot_type;

  dir_$do_op(request, dir_$op_tab[41].base_size, 20, response,
             received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
  begin
    if (prot_type <> file_$prot_acl_image) and then
       (prot_type <> file_$prot_merge_acl) and then
       (prot_type <> file_$prot_acl) then begin
      status_ret.all := file_$incompatible_request;
      return;
    end;

    if (rshft(dir_$uid_view_t(def_acl).w2 & 16#FF0, 4) & 16#10) = 0 then
    begin
      acl_$convert_to_9acl(prot, def_acl, uid, acl_$dir_acl, old_acl,
                           status_ret);
      if status_ret.all <> status_$ok then
        return;
    end
    else
      old_acl := def_acl;

    file_$priv_lock(uid, proc1_$as_id, 0, 4, false, 8, 0, 0, 0, 0, 0, 1,
                    lock_slot, lock_rights, status_ret);
    if status_ret.all <> status_$ok then
      return;

    file_$set_prot(uid, file_$prot_acl, prot, old_acl, status_ret);
    discard(file_$priv_unlock(uid, lock_slot, 4, proc1_$as_id, false, 0, 0,
                              0, dtv, local_status));
  end
  else
    status_ret := response.status;
end;
