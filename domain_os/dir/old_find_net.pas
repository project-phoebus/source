{ DIR_$OLD_FIND_NET - the extra longword of the old-format directory
  entry for a node.

  Image addresses:
    sau2  0x00E55AFE  DIR_$OLD_FIND_NET

  - Under a read lock (mode 1) the slots are searched; not found in the
    root, the replicated root is asked (REM_NAME_$FIND_NETWORK) and its
    entry added to the local root.
  - The result is the entry's extra longword, 0 on any failure.
  - Super-user mode, which name_$lock_dir enters, is left on every path.

  Status stored: none.
}

function dir_$old_find_net(in dir_uid: uid_$t; in node: linteger):
  integer32;
var
  name_out: rem_name_$name_t;
  entry: rem_name_$dir_entry_t;
  unlock_status: status_$t;
  status: status_$t;
  handle: dir_$old_dir_ptr_t;
  name_len: integer;
  truncated: boolean;
begin
  dir_$old_find_net := 0;
  name_$lock_dir(dir_uid, handle, 1, 0, status);
  if status.all = status_$ok then begin
    dir_$old_find_node_slot(handle, node, entry, status);
    name_$unlock_dir(unlock_status);

    if status.all = status_$ok then begin
      dir_$old_find_net := entry.extra;
      status := unlock_status;
    end
    else if (status.all = name_$not_found) and then
            (dir_uid = name_$root_uid) then begin
      rem_name_$find_network(dir_uid, node, entry, status);
      if status.all = status_$ok then begin
        unmap_case(entry.name, entry.name_len, name_out, 16#20, name_len,
                   truncated);
        name_$old_add_entry(dir_uid, 0, name_out, name_len, entry.uid,
                            entry.extra, unlock_status);
        dir_$old_find_net := entry.extra;
      end;
    end;
  end;

  acl_$exit_super;
end;
