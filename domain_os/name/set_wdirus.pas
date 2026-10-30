{ NAME_$SET_WDIRUS - make a directory the working directory.

  Image addresses:
    sau2  0x00E58670  NAME_$SET_WDIRUS

  - As super-user, with the right to use it (ACL_$RIGHTS), the old
    mapping is undone and the directory mapped and recorded.  With
    auditing on the change is logged (event 16#00040027).

  Status stored:
    status_$ok: the directory is the working one already, or now
    name_convert_acl_status' status: no right to use it
    name_$map_dir's status, fail bit set: the mapping failed
}

procedure name_$set_wdirus(in uid: uid_$t; out status: status_$t);
var
  ev: name_$event_uid_t;
  flags: pinteger;
begin
  if uid = name_$wdir_uid[proc1_$as_id] then
    status.all := status_$ok
  else begin
    acl_$enter_super;
    if acl_$rights(uid, true, 1, 1, status) = 0 then
      name_convert_acl_status(status)
    else begin
      name_$unmap_dir_buffers(proc1_$as_id,
                              name_$wdir_mapped_info[proc1_$as_id]);
      discard(name_$map_dir(uid, proc1_$as_id,
                            name_$wdir_mapped_info[proc1_$as_id], status));
      if status.all <> status_$ok then
        status.fail := true
      else begin
        name_$wdir_uid[proc1_$as_id] := uid;
        status.all := status_$ok;
      end;
    end;
    acl_$exit_super;

    if audit_$enabled then begin
      ev.uid := uid_$nil;
      ev.event_class := 4;
      ev.audit_subtype := 16#27;
      if status.all <> status_$ok then
        flags := 1
      else
        flags := 0;
      audit_$log_event(ev.uid, flags, status, uid, 8);
    end;
  end;
end;
