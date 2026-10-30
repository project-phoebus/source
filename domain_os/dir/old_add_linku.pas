{ DIR_$OLD_ADD_LINKU - add a soft link to an old-format directory.

  Image addresses:
    sau2  0x00E576EA  DIR_$OLD_ADD_LINKU

  - The text is case-mapped (MAP_CASE); the directory is locked for
    adding (mode 4, rights 2), the root's add made in the replace mode.
  - Super-user mode, which name_$lock_dir entered, is left (not after
    the two refusals).

  Status stored:
    dir_$old_add_link_entry's status: the directory was locked
    name_$unlock_dir's status: the unlock failed
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
    name_$bad_link: the mapping was truncated
}

procedure dir_$old_add_linku(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: pinteger;
                             in target: univ name_$long_pname_t;
                             in target_len: pinteger;
                             out status_ret: status_$t);
var
  parsed: array[1..32] of char;
  mapped: array[1..256] of char;
  entry: dir_$old_slot_ptr_t;
  local_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  parsed_len: pinteger;
  consumed: integer;
  path_type: integer;
  mapped_len: integer;
  is_root: boolean;
  truncated: boolean;
begin
  if not name_$validate_leaf(name, name_len, parsed, parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  map_case(target, target_len, mapped, 16#100, mapped_len, truncated);
  if truncated
     or else not name_$validate(mapped, mapped_len, consumed, path_type)
  then begin
    status_ret.all := name_$bad_link;
    return;
  end;

  is_root := dir_uid = name_$root_uid;

  name_$lock_dir(dir_uid, handle, 4, 2, status_ret);
  if status_ret.all = status_$ok then begin
    dir_$old_add_link_entry(dir_uid, handle, parsed, parsed_len, mapped,
                            mapped_len, is_root, entry, status_ret);

    name_$unlock_dir(local_status);
    if local_status.all <> status_$ok then
      status_ret := local_status;
  end;

  acl_$exit_super;
end;
