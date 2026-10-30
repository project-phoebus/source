{ ACL_$OVERRIDE_LOCAL_LOCKSMITH - set or clear the caller's locksmith
  override bit.

  Image addresses:
    sau2  0x00E49254  ACL_$OVERRIDE_LOCAL_LOCKSMITH
    sau9  0x3C450910  ACL_$OVERRIDE_LOCAL_LOCKSMITH

  - The boolean goes into the process's element of
    acl_$locksmith_override_bitmap.

  Status stored:
    status_$ok: the process is of type 9
    status_$no_right_to_perform_operation: any other type
}

procedure acl_$override_local_locksmith(enable: boolean;
                                        out status: status_$t);
  options(val_param);
begin
  status.all := status_$no_right_to_perform_operation;

  if proc1_$type[proc1_$current] = 9 then begin
    acl_$locksmith_override_bitmap[proc1_$current] := enable;
    status.all := status_$ok;
  end;
end;
