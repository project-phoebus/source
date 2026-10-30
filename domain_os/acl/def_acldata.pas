{ ACL_$DEF_ACLDATA - the default ACL data: a protection record and the
  nil ACL UID.

  Image addresses:
    sau2  0x00E478DC  ACL_$DEF_ACLDATA

  - Owner, group and organization nil, their rights 16#10 each, the
    world's 16#F; the last 16 bytes 0, 0, 0, 0 and 16#C three times.
  - The default ACL UID is UID_$NIL.

  Status stored: none.
}

{ TODO(pascal) ACL_$DEF_ACLDATA's last 16 bytes copied from a constant in the code

  The record's bytes +0x1C..+0x2B are one block copy from a constant
  cell after the routine's code: a 16-byte object of the record assigned
  a constant, though acl_$prot_data_t has no 16-byte field there (the
  subsystem rights, three bytes, the three extension longwords).  As in
  ACL_$FREE_ASID (see the TODO(pascal) in acl/free_asid.pas), the Pascal
  assigns the fields (the same values, but stores, not a copy from the
  code). }

procedure acl_$def_acldata(out prot: acl_$prot_data_t;
                           out def_acl_uid: uid_$t);
begin
  prot.owner := ppo_$nil_user_uid;
  prot.group := rgyc_$g_nil_uid;
  prot.org := ppo_$nil_org_uid;

  prot.owner_rights := [4];
  prot.group_rights := [4];
  prot.org_rights := [4];
  prot.world_rights := [0..3];
  prot.subsys_rights := [];
  prot.reserved_1d := chr(0);
  prot.reserved_1e := chr(0);
  prot.reserved_1f := chr(0);
  prot.owner_ext[1] := 16#C;
  prot.owner_ext[2] := 16#C;
  prot.owner_ext[3] := 16#C;

  def_acl_uid := uid_$nil;
end;
