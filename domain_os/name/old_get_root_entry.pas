{ name_$old_get_root_entry - look a name up in the old-format root
  directory, falling back on the replicated root.

  Image addresses:
    sau2  0x00E57F74  name_$old_get_root_entry

  - name_$old_get_entry_nonroot first; a name not in the root is asked
    of the naming server (REM_NAME_$GET_ENTRY), and a directory entry it
    gives is cached in the local root under its unmapped name.
  - The cache add's status is discarded.

  Status stored:
    name_$old_get_entry_nonroot's status: the root had it, or another
      directory
    rem_name_$get_entry's status: the server gave a directory entry
    name_$not_found: any other answer
}

procedure name_$old_get_root_entry(in dir_uid: uid_$t;
                                   in name: univ name_$long_name_t;
                                   name_len: pinteger;
                                   out entry_ret: univ dir_$old_entry_view_t;
                                   out status_ret: status_$t);
  internal;
var
  found: uid_$t;
  rem_entry: rem_name_$dir_entry_t;
  unmapped: array[1..32] of char;
  add_status: status_$t;
  unmapped_len: integer;
  truncated: boolean;
begin
  name_$old_get_entry_nonroot(dir_uid, name, name_len, entry_ret,
                              status_ret);

  if (dir_uid = name_$root_uid) and then
     (status_ret.all = name_$not_found) then begin
    rem_name_$get_entry(dir_uid, name, name_len, rem_entry, status_ret);

    if (status_ret.all = status_$ok) and then
       (rem_entry.entry_type = 1) then begin
      entry_ret.entry_type := rem_entry.entry_type;
      entry_ret.data := rem_entry.data;

      unmap_case(rem_entry.name, rem_entry.name_len, unmapped, 16#20,
                 unmapped_len, truncated);

      found := entry_ret.uid;
      name_$old_add_entry(dir_uid, 0, unmapped, unmapped_len, found,
                          entry_ret.extra, add_status);
    end
    else
      status_ret.all := name_$not_found;
  end;
end;
