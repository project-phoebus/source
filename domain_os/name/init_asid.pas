{ NAME_$INIT_ASID - give a new address space its directories.

  Image addresses:
    sau2  0x00E73CFC  NAME_$INIT_ASID

  - As super-user, the new address space gets the current one's working
    and naming directories: each is mapped and its UID recorded when
    ACL_$RIGHTS grants any right; no right leaves it as it was.

  Status stored:
    status_$ok: no right to a directory (that one left)
    name_$map_dir's status: the directories were mapped
    the failed map's status, fail bit set: the rest is skipped
}

[section(proc2_create_pro, proc2_create_dat)]
procedure name_$init_asid(in new_asid: integer; out status: status_$t);
label
  99;
var
  current_uid: uid_$t;
begin
  acl_$enter_super;

  { the working directory }
  current_uid := name_$wdir_uid[proc1_$as_id];
  if acl_$rights(current_uid, true, -1, 1, status) <> 0 then begin
    discard(name_$map_dir(current_uid, new_asid,
                          name_$wdir_mapped_info[new_asid], status));
    if status.all <> status_$ok then begin
      status.fail := true;
      goto 99;
    end;
    name_$wdir_uid[new_asid] := current_uid;
  end
  else
    status.all := status_$ok;

  { the naming directory }
  current_uid := name_$ndir_uid[proc1_$as_id];
  if acl_$rights(current_uid, true, -1, 1, status) <> 0 then begin
    discard(name_$map_dir(current_uid, new_asid,
                          name_$ndir_mapped_info[new_asid], status));
    if status.all <> status_$ok then
      status.fail := true
    else
      name_$ndir_uid[new_asid] := current_uid;
  end
  else
    status.all := status_$ok;

99:
  acl_$exit_super;
end;
