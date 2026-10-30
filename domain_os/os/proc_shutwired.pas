{ OS_PROC_SHUTWIRED - translate an ACL status into the file manager's.

  Image addresses:
    sau2  0x00E5D050  OS_PROC_SHUTWIRED

  - A fragment of the FILE_ module (file/file.pas includes it); its map
    symbol also starts the run OS_$SHUTDOWN wires.

  Status stored:
    status_$no_rights: status was "no right to perform operation"
    status_$insufficient_rights: status was "insufficient rights to
      perform operation"
    file_$wrong_type: status was the ACL's "wrong type"
    file_$objects_on_different_volumes: status was "ACL on another
      volume"
    status, its fail bit set: any other status but
      file_$object_not_found (status_$ok too)
}

{ TODO(pascal) OS_PROC_SHUTWIRED's 4 frame bytes

  The frame has 4 bytes and no object in it: the routine is map-named
  (global, no reserved slot) and declares nothing the image addresses.
  The same unexplained 4 bytes as other small map-named procedures. }

procedure os_proc_shutwired(in out status: status_$t);
begin
  if status.all = status_$no_right_to_perform_operation then
    status.all := status_$no_rights
  else if status.all = status_$insufficient_rights_to_perform_operation then
    status.all := status_$insufficient_rights
  else if status.all = status_$acl_wrong_type then
    status.all := file_$wrong_type
  else if status.all = status_$acl_on_different_volume then
    status.all := file_$objects_on_different_volumes
  else if status.all <> file_$object_not_found then
    status.fail := true;
end;
