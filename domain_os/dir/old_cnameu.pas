{ DIR_$OLD_CNAMEU - rename an entry of an old-format directory.

  Image addresses:
    sau2  0x00E57562  DIR_$OLD_CNAMEU

  - Under the directory's add lock (mode 4, rights 2) the entry goes in
    again under the new name, in the root with its extra word as a
    replacement; on success the old slot is freed.
  - Super-user mode, which name_$lock_dir entered, is left (not after
    the bad-leaf refusal).

  Status stored:
    name_$unlock_dir's status: the add worked (its code word 0)
    the add's status: it failed (dir_$old_add_entry_ext's in the root,
      else dir_$old_add_entry's)
    name_$not_found: the old name is not in the directory
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: either name is not a valid leaf
}

procedure dir_$old_cnameu(in dir_uid: uid_$t;
                          in old_name: univ name_$long_name_t;
                          in old_name_len: pinteger;
                          in new_name: univ name_$long_name_t;
                          in new_name_len: pinteger;
                          out status_ret: status_$t);
var
  old_parsed: array[1..32] of char;
  new_parsed: array[1..32] of char;
  local_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  add_result: dir_$old_slot_ptr_t;
  entry: dir_$old_slot_ptr_t;
  old_parsed_len: pinteger;
  hash: pinteger;
  new_parsed_len: pinteger;
  chain_level: integer;
  slot_idx: pinteger;
  dir: dir_$old_dir_ptr_t;
  found: boolean;
begin
  if not name_$validate_leaf(new_name, new_name_len, new_parsed,
                             new_parsed_len)
     or else not name_$validate_leaf(old_name, old_name_len, old_parsed,
                                     old_parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 4, 2, status_ret);
  dir := handle;
  if status_ret.code = 0 then begin
    found := dir_$old_find_entry(dir, old_parsed, old_parsed_len, entry,
                                 slot_idx, chain_level);
    with entry^ do
      if not found then
        status_ret.all := name_$not_found
      else begin
        { the entry under the new name }
        if dir_uid <> name_$root_uid then
          dir_$old_add_entry(dir_uid, dir, new_parsed, new_parsed_len,
                             ord(slot_type), uid, false, add_result,
                             status_ret)
        else begin
          flags := flags + [15];
          dir_$old_add_entry_ext(dir_uid, dir, new_parsed, new_parsed_len,
                                 ord(slot_type), uid, extra, true,
                                 add_result, status_ret);
          flags := flags - [15];
        end;

        { the old slot freed }
        if status_ret.code = 0 then begin
          slot_type := 1;
          hash := dir_$old_hash_name(old_parsed, old_parsed_len,
                                     dir^.hdr.buckets);
          dir_$old_delete_entry(dir, slot_idx, chain_level, hash);
        end;
      end;

    name_$unlock_dir(local_status);
    if status_ret.code = 0 then
      status_ret := local_status;
  end;

  acl_$exit_super;
end;
