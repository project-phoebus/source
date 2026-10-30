{ ACL_$FREE_ASID - reset an address space's ACL state to the defaults.

  Image addresses:
    sau2  0x00E74C6A  ACL_$FREE_ASID
    sau9  0x3C47C7E6  ACL_$FREE_ASID

  - The current SIDs become the system user, project and organization
    and a nil login, copied to the original and saved SIDs; the project
    lists the default, the project UIDs nil, the subsystem level 0.
  - The address space is marked free and its super-user bit cleared.

  Status stored:
    status_$ok: always
}

{ TODO(pascal) ACL_$FREE_ASID's project list copied from a constant in the code

  acl_$proj_lists[asid] is filled by a block copy from the 12 bytes after
  the routine's code, three longwords 16#0D: a 12-byte constant of the
  record's type assigned to it.  As VTOCE_$OLD_TO_NEW's (see the
  TODO(pascal) in vtoc/old_to_new.pas) and FLP_$DINIT's, the reference
  has no structured constant for it, and a `static' variable would be in
  the data section; the Pascal assigns the three longwords (the same
  values; three stores, not a copy from the code). }

{ TODO(pascal) ACL_$FREE_ASID's 14 frame bytes

  The frame has 16 bytes for one word index whose value lives in a
  register: 14 bytes no object explains.  Three `with' statements'
  temporaries (4 bytes each, a lead) over the current SIDs, the project
  lists and the project row would explain 12; written as plain
  references here, which give the same instructions. }

[section(proc2_delete_pro, proc2_delete_dat)]
procedure acl_$free_asid(asid: integer; out status_ret: status_$t);
var
  i: integer;                             { held scaled }
begin
  { the system SIDs }
  acl_$current_sids[asid].user_sid := acl_$sys_user_uid;
  acl_$current_sids[asid].group_sid := acl_$sys_proj_uid;
  acl_$current_sids[asid].org_sid := acl_$sys_org_uid;
  acl_$current_sids[asid].login_sid := uid_$nil;

  { the default project list (the TODO above) }
  acl_$proj_lists[asid].field_00 := 16#0000000D;
  acl_$proj_lists[asid].field_04 := 16#0000000D;
  acl_$proj_lists[asid].field_08 := 16#0000000D;

  acl_$original_sids[asid] := acl_$current_sids[asid];
  acl_$saved_sids[asid] := acl_$current_sids[asid];
  acl_$saved_proj[asid] := acl_$proj_lists[asid];

  for i := 1 to 8 do
    acl_$proj_uids[asid][i] := uid_$nil;

  acl_$subsys_level[asid] := 0;
  acl_$asid_free_bitmap[asid] := true;
  acl_$asid_suser_bitmap[asid] := false;

  status_ret.all := status_$ok;
end;
