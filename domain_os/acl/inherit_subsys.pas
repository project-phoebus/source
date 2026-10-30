{ ACL_$INHERIT_SUBSYS - set the current process's subsystem bit.

  Image addresses:
    sau2  0x00E49138  ACL_$INHERIT_SUBSYS

  - The boolean goes into the process's element of the packed bitmap
    acl_$asid_free_bitmap.

  Status stored:
    status_$ok: always
}

procedure acl_$inherit_subsys(in flag: boolean; out status: status_$t);
begin
  acl_$asid_free_bitmap[proc1_$current] := flag;
  status.all := status_$ok;
end;
