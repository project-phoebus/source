{ dir_$old_unlink_entry - remove a named entry from an old-format
  directory.

  Image addresses:
    sau2  0x00E5569C  dir_$old_unlink_entry (module-local)

  - A hard link (type 1) hands back its UID, a plain entry or soft link
    UID_$NIL; the entry is deleted when the status's low word is clear.

  Status stored:
    status_$ok: the entry was removed
    name_$not_found: the name is not in the directory
    name_$not_link: a soft link's drop (operation 3) of a hard link
    name_$ill_link_op: a hard link's drop (operation 1) of a soft link
}

procedure dir_$old_unlink_entry(in dir_uid: uid_$t; dir: dir_$old_dir_ptr_t;
                                in name: univ name_$long_name_t;
                                name_len: pinteger; op_type: integer;
                                out uid_ret: uid_$t;
                                out status_ret: status_$t);
  internal;
var
  entry: dir_$old_slot_ptr_t;
  hash: pinteger;
  chain_level: integer;
  slot_idx: pinteger;
begin
  status_ret.all := status_$ok;

  if dir_$old_find_entry(dir, name, name_len, entry, slot_idx,
                         chain_level) then begin
    case entry^.slot_type of
      name_$entry_none: begin
        uid_ret := uid_$nil;
      end;
      name_$file: begin
        if op_type = 3 then
          status_ret.all := name_$not_link;
        uid_ret := entry^.uid;
      end;
      name_$link: begin
        if op_type = 1 then
          status_ret.all := name_$ill_link_op
        else
          uid_ret := uid_$nil;
      end;
    end;
  end
  else
    status_ret.all := name_$not_found;

  if status_ret.code = 0 then begin
    hash := dir_$old_hash_name(name, name_len, dir^.hdr.buckets);
    dir_$old_delete_entry(dir, slot_idx, chain_level, hash);
  end;
end;
