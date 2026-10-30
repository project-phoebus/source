{ NAME_CONVERT_ACL_STATUS - turn three ACL statuses into naming ones.

  Image addresses:
    sau2  0x00E5861C  NAME_CONVERT_ACL_STATUS

  - The status is rewritten in place; any other status is left.

  Status stored:
    name_$no_rights: it was "no right to perform operation"
    name_$insufficient_rights: it was "insufficient rights to perform
      operation"
    name_$file_not_directory: it was the ACL's "wrong type"
}

procedure name_convert_acl_status(in out status: status_$t);
begin
  if status.all = status_$no_right_to_perform_operation then
    status.all := name_$no_rights
  else if status.all = status_$insufficient_rights_to_perform_operation then
    status.all := name_$insufficient_rights
  else if status.all = status_$acl_wrong_type then
    status.all := name_$file_not_directory;
end;
