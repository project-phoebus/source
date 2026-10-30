{ DIR_$SET_ACL - set an object's ACL through its directory's server.

  Image addresses:
    sau2  0x00E52C86  DIR_$SET_ACL

  - An operation-16#4A request through DIR_$DO_OP; for an old-format
    server the object is locked locally (FILE_$PRIV_LOCK, mode 4), its
    ACL set, and the lock released, its status dropped.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    file_$set_acl's status: an old-format server
    file_$priv_lock's status: the object could not be locked
}

procedure dir_$set_acl(in uid: uid_$t; in acl: uid_$t;
                       out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$uid_req_t;
  lock_slot: linteger;
  local_status: status_$t;
  dtv: time_$clock_t;
  lock_rights: integer;
  received_len: integer;
begin
  request.hdr.op := dir_op_set_acl;
  request.hdr.uid := uid;
  request.hdr.version := dir_$op_tab[37].version;
  request.acl_type := acl;

  dir_$do_op(request, dir_$op_tab[37].base_size, 20, response,
             received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
  begin
    file_$priv_lock(uid, proc1_$as_id, 0, 4, false, 8, 0, 0, 0, 0, 0, 1,
                    lock_slot, lock_rights, status_ret);
    if status_ret.all = status_$ok then begin
      file_$set_acl(uid, acl, status_ret);
      discard(file_$priv_unlock(uid, lock_slot, 4, proc1_$as_id, false, 0,
                                0, 0, dtv, local_status));
    end;
  end
  else
    status_ret := response.status;
end;
