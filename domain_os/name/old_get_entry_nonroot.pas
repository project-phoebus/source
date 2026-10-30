{ name_$old_get_entry_nonroot - look a name up in an old-format
  directory, wherever its hints say the directory lives.

  Image addresses:
    sau2  0x00E57CE0  name_$old_get_entry_nonroot

  - The hints are tried in order: this node, or a remote "directory
    locked", looks in the local copy (a read lock, dir_$old_find_entry);
    another node is asked (REM_FILE_$NAME_GET_ENTRYU).
  - A directory entry on another node gets a hint; not found, not a
    directory, or a rights refusal ends the lookup, other errors try the
    next hint.
  - Running out of hints crashes the system.

  Status stored:
    rem_file_$name_get_entryu's status: a remote answer ended it
    name_$unlock_dir's status: a local lookup found the entry
    name_$not_found: the local copy has no such entry
    name_$lock_dir's status: the local copy could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure name_$old_get_entry_nonroot(dir_uid: uid_$t;
                                      in name: univ name_$long_name_t;
                                      name_len: pinteger;
                                      out entry_ret: univ dir_$old_entry_t;
                                      out status_ret: status_$t);
  internal;
label
  10, 20;
var
  found: uid_$t;
  hints: hint_$addr_list_t;
  parsed: array[1..32] of char;
  unlock_status: status_$t;
  slot: dir_$old_slot_ptr_t;
  handle: dir_$old_dir_ptr_t;
  slot_idx: pinteger;
  chain_level: integer;
  parsed_len: pinteger;
  k: integer;
  found_it: boolean;
begin
  if not name_$validate_leaf(name, name_len, parsed, parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  for k := 1 to hint_$get_hints(dir_uid, hints) do begin
    if hints[k].node_id = node_$me then
      goto 10;

    rem_file_$name_get_entryu(hints[k].flags, dir_uid, parsed, parsed_len,
                              entry_ret, status_ret);
    if status_ret.all = status_$naming_directory_locked then
      goto 10;

    if status_ret.code = 0 then begin
      if k <> 1 then
        hint_$addi(dir_uid, hints[k]);

      found := entry_ret.uid;
      if ((dir_uid.low & 16#FFFFF) = (found.low & 16#FFFFF)) or else
         (entry_ret.entry_type <> 1) then
        return;

      if dir_uid <> name_$root_uid then
        hint_$addi(found, hints[k])
      else begin
        if entry_ret.extra = 0 then
          return;
        hints[1].flags := entry_ret.extra;
        hints[1].node_id := found.low & 16#FFFFF;
        hint_$addi(found, hints[1]);
      end;
      return;
    end;

    if (status_ret.all = name_$not_found) or else
       (status_ret.all = name_$file_not_directory) or else
       (status_ret.all = name_$no_rights) or else
       (status_ret.all = name_$insufficient_rights) then
      return;
    next;

10:
    name_$lock_dir(dir_uid, handle, 1, 1, status_ret);
    if status_ret.code <> 0 then
      goto 20;

    found_it := dir_$old_find_entry(handle, parsed, parsed_len, slot,
                                    slot_idx, chain_level);
    with slot^ do
      if found_it then begin
        entry_ret.entry_type := slot_type;
        entry_ret.uid := uid;
        found := uid;
        if dir_uid = name_$root_uid then
          entry_ret.extra := extra
        else
          entry_ret.extra := 0;

        if ((dir_uid.low & 16#FFFFF) <> (found.low & 16#FFFFF)) and then
           (slot_type = 1) then
          if dir_uid <> name_$root_uid then
            hint_$addu(found, dir_uid)
          else if entry_ret.extra <> 0 then begin
            hints[1].flags := entry_ret.extra;
            hints[1].node_id := found.low & 16#FFFFF;
            hint_$addi(found, hints[1]);
          end;
      end
      else
        status_ret.all := name_$not_found;

    name_$unlock_dir(unlock_status);
    if status_ret.all = status_$ok then
      status_ret := unlock_status;

20:
    acl_$exit_super;
    return;
  end;

  crash_system(name_$not_found);
end;
