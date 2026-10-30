{ AUDIT_$ADMINISTRATOR - whether the caller is an audit administrator.

  Image addresses:
    sau2  0x00E714B6  AUDIT_$ADMINISTRATOR

  - True when ACL_$RIGHTS gives exactly right 2 on the audit directory,
    `node_data/audit.

  Status stored:
    acl_$rights's status: the directory was found
    status_$audit_could_not_find_audit_event_list: it was not
}

function audit_$administrator(out status: status_$t): boolean;
var
  dir_uid: uid_$t;
begin
  audit_$administrator := false;
  name_$resolve('`node_data/audit', 16, dir_uid, status);

  if status.all <> status_$ok then
    status.all := status_$audit_could_not_find_audit_event_list
  else if acl_$rights(dir_uid, false, 2, 1, status) = 2 then
    audit_$administrator := true;
end;
