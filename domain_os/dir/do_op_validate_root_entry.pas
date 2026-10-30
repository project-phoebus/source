{ dir_$do_op_validate_root_entry - DIR_$DO_OP's 16#50: check a root
  entry against the replicated root, and refresh it if it is stale.

  Image addresses:
    sau2  0x00E501D2  dir_$do_op_validate_root_entry

  - As super-user, the root's entry is compared with REM_NAME_'s
    replicated one; the same, or a newer local version (the same node,
    the local high half greater, unsigned), is left.
  - Otherwise the old entry is replaced by the replicated one (type 3)
    and given to HINT_$ADDI.

  Status stored:
    rem_name_$get_entry's status: the entry is current, or the lookup
      failed
    status_$naming_cache_entry_stale_and_updated: the entry was replaced
    status_$naming_cache_entry_stale: the old entry could not be removed
    name_$not_found: the name is not in the root, or the add failed
    dir_$open_dir's status: the root could not be opened
}

procedure dir_$do_op_validate_root_entry(in name: univ name_$long_name_t;
                                         name_len: integer;
                                         out status_ret: status_$t);
label
  10;
var
  hint: hint_$addr_t;
  remove_uid: uid_$t;
  rep: rem_name_$dir_entry_t;
  uid: dir_$uid_view_t;
  entry: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  path: integer;
  depth: integer;
  extra: integer32;
begin
  acl_$enter_super;
  dir_$open_dir(name_$root_uid, 1, 0, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  if dir_$find_entry(handle^, name, name_len, 0, entry, path, depth) then
  begin
    if entry^.flags & 7 = 3 then begin
      uid.uid := entry^.uid;
      extra := entry^.extra;
    end
    else begin
      uid.uid := entry^.uid;
      extra := 0;
    end;

    dir_$release_handle(handle);
    rem_name_$get_entry(name_$canned_rep_root_uid, name, name_len, rep,
                        status_ret);
    if status_ret.all <> status_$ok then
      goto 10;

    { current, or a newer local version }
    if uid.uid = rep.uid then begin
      if extra = rep.extra then
        goto 10;
    end
    else if (uid.b0 <> 0) and then
            (dir_$uid_view_t(rep.uid).b0 <> 0) and then
            ((uid.low & 16#FFFFF) =
             (dir_$uid_view_t(rep.uid).low & 16#FFFFF)) and then
            (uid.high > dir_$uid_view_t(rep.uid).high) then
      goto 10;

    dir_$open_dir(name_$root_uid, 2, 0, handle, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;

    dir_$remove_entry(handle^, name, name_len, 0, remove_uid, status_ret);
    if status_ret.all <> status_$ok then begin
      status_ret.all := status_$naming_cache_entry_stale;
      goto 10;
    end;

    dir_$add_entry(handle^, name, name_len, 3, rep.extra, rep.uid, 0, '',
                   status_ret);
    if status_ret.all <> status_$ok then
      status_ret.all := name_$not_found
    else
      status_ret.all := status_$naming_cache_entry_stale_and_updated;
  end
  else
    status_ret.all := name_$not_found;

10:
  dir_$release_handle(handle);
  if status_ret.all = status_$naming_cache_entry_stale_and_updated then
  begin
    hint.flags := rep.extra;
    hint.node_id := rep.uid.low & 16#FFFFF;
    hint_$addi(rep.uid, hint);
  end;
  acl_$exit_super;
end;
