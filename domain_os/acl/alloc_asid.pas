{ ACL_$ALLOC_ASID - give a new address space the current process's SIDs.

  Image addresses:
    sau2  0x00E73BB8  ACL_$ALLOC_ASID
    sau9  0x3C47B580  ACL_$ALLOC_ASID

  - The current process's SIDs, projects and project lists are copied
    into asid's rows; with the free-ASID bit clear, the three copied
    login SIDs become UID_$NIL.
  - The free-ASID bit tested is the current process's.

  Status stored:
    status_$ok: always
}

[section(proc2_create_pro, proc2_create_dat)]
procedure acl_$alloc_asid(asid: integer; out status_ret: status_$t);
begin
  { the three SID blocks }
  acl_$original_sids[asid] := acl_$original_sids[proc1_$current];
  acl_$current_sids[asid] := acl_$current_sids[proc1_$current];
  acl_$saved_sids[asid] := acl_$saved_sids[proc1_$current];

  acl_$proj_uids[asid] := acl_$proj_uids[proc1_$current];

  acl_$saved_proj[asid] := acl_$saved_proj[proc1_$current];
  acl_$proj_lists[asid] := acl_$proj_lists[proc1_$current];

  if not acl_$asid_free_bitmap[proc1_$current] then begin
    acl_$original_sids[asid].login_sid := uid_$nil;
    acl_$current_sids[asid].login_sid := uid_$nil;
    acl_$saved_sids[asid].login_sid := uid_$nil;
  end;

  status_ret.all := status_$ok;
end;
