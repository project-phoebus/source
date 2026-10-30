{ FILE_$SET_PROT_INT - set an object's protection, locally or on its node.

  Image addresses:
    sau2  0x00E5DD08  FILE_$SET_PROT_INT

  - A new protection naming an ACL object must be on the object's volume
    (file_$check_same_volume).
  - A remote object's change goes to its node (REM_FILE_$FILE_SET_PROT)
    and into the local AST copy; a bad reply falls back to the local
    path, where ACL_$SET_ACL_CHECK decides before AST_$SET_ATTRIBUTE.
  - Every path ends in the audit log entry when auditing is on.

  Status stored:
    ast_$set_attribute's status: the protection was set locally
    rem_file_$file_set_prot's or ast_$set_attr's status: a remote change
    file_$objects_on_different_volumes: the ACL is on another volume
    file_$incompatible_request: AST_'s "incompatible request"
    status_$no_right_to_perform_operation: set-id rights refused in a
      server process (but for the locksmith)
    the callees' statuses, ACL_'s made FILE_ statuses: those failed
}

procedure file_$set_prot_int(in file_uid: uid_$t;
                             in acl_data: file_$set_prot_rec_t;
                             attr_type: integer; prot_type: integer;
                             subsys_flag: boolean;
                             out status_ret: status_$t);
  options(val_param);
label
  10;
var
  loc: file_$obj_loc_t;
  exsid: acl_$exsid_t;
  mtime: time_$clock_t;
  local_status: status_$t;
  unused: integer32;
  location: ast_$location_t;
  setid: boolean;
  acl_check_result: boolean;
  same_volume_result: boolean;
begin
  { an ACL object must be on the same volume }
  same_volume_result := false;
  if acl_data.acl_uid.b0 <> 0 then
    if not file_$check_same_volume(file_uid, acl_data.acl_uid.uid, true,
                                   loc, status_ret) then begin
      if status_ret.all = status_$ok then begin
        status_ret.all := file_$objects_on_different_volumes;
        goto 10;
      end;
      if status_ret.all <> file_$object_is_remote then
        goto 10;
      same_volume_result := true;
    end;

  { the object's location }
  if not same_volume_result then begin
    loc.uid := file_uid;
    loc.flags := loc.flags - [6];
    ast_$get_location(loc, 0, unused, location, local_status);
    if local_status.all <> status_$ok then begin
      status_ret := local_status;
      goto 10;
    end;
  end;

  { a remote object }
  if 7 in loc.flags then begin
    acl_$get_exsid(exsid, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
    rem_file_$file_set_prot(loc.loc_info, file_uid, acl_data.value,
                            attr_type, exsid, subsys_flag, mtime,
                            status_ret);
    if status_ret.all <> file_$bad_reply_received_from_remote_node then
      begin
      if status_ret.all = status_$ok then
        ast_$set_attr(file_uid, attr_type, acl_data.value, false, mtime,
                      status_ret);
      goto 10;
    end;
  end;

  { the local check }
  acl_check_result := acl_$set_acl_check(file_uid, acl_data.prot,
                                         acl_data.acl_uid.uid, prot_type,
                                         setid, status_ret);
  if not acl_check_result then begin
    if setid and (proc1_$type[proc1_$current] = 9) and
       (acl_$get_local_locksmith <> 0) then begin
      status_ret.all := status_$no_right_to_perform_operation;
      goto 10;
    end;
    if subsys_flag and then
       (status_ret.all = status_$acl_no_right_to_set_subsystem_data) then
      if (acl_$get_local_locksmith = 0) or
         (proc1_$type[proc1_$current] <> 9) then
        status_ret.all := status_$ok;
    if status_ret.all <> status_$ok then begin
      os_proc_shutwired(status_ret);
      goto 10;
    end;
  end;

  ast_$set_attribute(file_uid, attr_type, acl_data.value, status_ret);
  if status_ret.all = status_$ast_incompatible_request then
    status_ret.all := file_$incompatible_request;

10:
  if audit_$enabled then
    file_$audit_set_prot(file_uid, acl_data.prot, acl_data.acl_uid.uid,
                         prot_type, status_ret);
end;
