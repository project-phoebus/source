{ DIR_$OLD_READ_LINKU - read a soft link of an old-format directory.

  Image addresses:
    sau2  0x00E577F4  DIR_$OLD_READ_LINKU

  - Under a read lock (mode 1, rights 4); a soft link's text is gathered
    from its overflow blocks and un-mapped into the caller's buffer
    (UNMAP_CASE, at most 256 characters).  The UID starts as UID_$NIL.
  - Super-user mode is left (not after the bad-leaf refusal).

  Status stored:
    name_$unlock_dir's status: the status's code word was still 0
    name_$not_link: a hard entry (its UID handed back)
    name_$bad_link: the text was truncated
    name_$not_found: the name is not in the directory
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure dir_$old_read_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              out target: univ name_$long_pname_t;
                              out target_len: integer;
                              out target_uid: uid_$t;
                              out status_ret: status_$t);
var
  link_buf: array[1..256] of char;
  parsed: array[1..32] of char;
  unlock_status: status_$t;
  entry: dir_$old_slot_ptr_t;
  handle: dir_$old_dir_ptr_t;
  chain_level: integer;
  slot_idx: pinteger;
  link_len: pinteger;
  parsed_len: pinteger;
  truncated: boolean;
  found: boolean;
begin
  target_uid := uid_$nil;

  if not name_$validate_leaf(name, name_len, parsed, parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 1, 4, status_ret);
  if status_ret.code = 0 then begin
    found := dir_$old_find_entry(handle, parsed, parsed_len, entry, slot_idx,
                                 chain_level);

    with entry^ do
      if found then begin
        case slot_type of
          name_$entry_none: { empty };
          name_$file: begin
            target_uid := uid;
            status_ret.all := name_$not_link;
          end;
          name_$link: begin
            dir_$old_read_link_data(handle, uid, link_buf, link_len);

            unmap_case(link_buf, link_len, target, 16#100, target_len,
                       truncated);
            if truncated then
              status_ret.all := name_$bad_link;
          end;
        end;
      end
      else
        status_ret.all := name_$not_found;

    name_$unlock_dir(unlock_status);
    if status_ret.code = 0 then
      status_ret := unlock_status;
  end;

  acl_$exit_super;
end;
