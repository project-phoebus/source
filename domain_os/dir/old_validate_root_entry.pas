{ DIR_$OLD_VALIDATE_ROOT_ENTRY - check an old-format root entry against
  the replicated root's.

  Image addresses:
    sau2  0x00E580C4  DIR_$OLD_VALIDATE_ROOT_ENTRY

  - The local entry stands when it names the same object and extra
    longword, or a newer generation of it (the same node, the local high
    half above, unsigned); otherwise it is replaced by the replicated
    one under its unmapped name.

  Status stored:
    status_$ok: the local entry stands
    status_$naming_cache_entry_stale_and_updated: it was replaced
    status_$naming_cache_entry_stale: the old entry could not be dropped
    name_$not_found: the new entry could not be added
    name_$old_get_entry_nonroot's or rem_name_$get_entry's status: a
      lookup failed
}

procedure dir_$old_validate_root_entry(in name: univ name_$long_name_t;
                                       in name_len: pinteger;
                                       out status_ret: status_$t);
var
  unmapped: array[1..32] of char;
  drop_uid: uid_$t;
  rep_entry: rem_name_$dir_entry_t;
  local_entry: dir_$old_entry_t;
  unmapped_len: integer;
  truncated: boolean;
begin
  name_$old_get_entry_nonroot(name_$root_uid, name, name_len, local_entry,
                              status_ret);
  if status_ret.code <> 0 then
    return;

  rem_name_$get_entry(name_$canned_rep_root_uid, name, name_len, rep_entry,
                      status_ret);
  if status_ret.code <> 0 then
    return;

  if local_entry.uid = rep_entry.uid then begin
    if local_entry.extra = rep_entry.extra then begin
      status_ret.all := status_$ok;
      return;
    end;
  end
  else if (dir_$uid_view_t(local_entry.uid).b0 <> 0) and then
          (dir_$uid_view_t(rep_entry.uid).b0 <> 0) and then
          ((dir_$uid_view_t(local_entry.uid).low & 16#FFFFF) =
           (dir_$uid_view_t(rep_entry.uid).low & 16#FFFFF)) and then
          (dir_$uid_view_t(local_entry.uid).high >
           dir_$uid_view_t(rep_entry.uid).high) then begin
    status_ret.all := status_$ok;
    return;
  end;

  name_$old_drop_entry(name_$root_uid, name, name_len, 0, drop_uid,
                       status_ret);
  if status_ret.code <> 0 then begin
    status_ret.all := status_$naming_cache_entry_stale;
    return;
  end;

  unmap_case(rep_entry.name, rep_entry.name_len, unmapped, 16#20,
             unmapped_len, truncated);

  name_$old_add_entry(name_$root_uid, 0, unmapped, unmapped_len,
                      rep_entry.uid, rep_entry.extra, status_ret);
  if status_ret.code <> 0 then
    status_ret.all := name_$not_found
  else
    status_ret.all := status_$naming_cache_entry_stale_and_updated;
end;
