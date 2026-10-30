{ DIR_$OLD_ADD_BAKU - keep an old-format directory's entry as `.bak' and
  enter a new object under its name.

  Image addresses:
    sau2  0x00E56E3E  DIR_$OLD_ADD_BAKU

  - A name not in the directory: the new object gets the directory's
    default file ACL and is entered under it.
  - A name present: the new object gets the old one's protection, an
    existing backup is deleted, the old entry renamed to the backup name
    (at most 32 characters) and the new object entered.
  - Every path from the lock on ends with ACL_$EXIT_SUPER.

  Status stored:
    file_$fw_file's status: the new object was entered
    name_$bad_leaf: not a valid leaf, or folded past 28 characters
    name_$ill_link_op: the name or its `.BAK' entry is not an object
    name_$not_file: ACL_$RIGHTS said "wrong type"
    name_convert_acl_status' status: another ACL_$RIGHTS failure
    name_$lock_dir's or name_$unlock_dir's status: the lock failed
    the failed step's status: dir_$old_get_default_acl,
      file_$get_attributes, file_$set_prot, name_$old_delete_entryu,
      dir_$old_cnameu or dir_$old_add_hard_linku
}

procedure dir_$old_add_baku(in dir_uid: uid_$t;
                            in leaf: univ name_$name_t;
                            in leaf_len: integer;
                            in backup_uid: uid_$t;
                            out status_ret: status_$t);
label
  80, 90;
type
  { The attribute record as this routine reads it: the object's
    protection at +0x48 and its default ACL at +0x88 (FILE_$SET_PROT's
    two data arguments are those two offsets into the record). }
  attr_view_t = record
    case integer of
      1: (attrs: file_$attributes_t);              { 0x00 }
      2: (unused_00: array[16#00..16#47] of char;  { 0x00 }
          prot: acl_$prot_data_t;                  { 0x48 }
          unused_74: array[16#74..16#87] of char;  { 0x74 }
          def_acl: uid_$t);                        { 0x88 }
  end;
var
  delete_uid: uid_$t;
  acl_data: acl_$prot_data_t;
  loc_rec: file_$obj_loc_t;
  attr_rec: attr_view_t;
  bak_name: name_$name_t;
  parsed: name_$name_t;
  default_acl: uid_$t;
  old_file_uid: uid_$t;
  unlock_status: status_$t;
  bak_entry: dir_$old_slot_ptr_t;
  entry: dir_$old_slot_ptr_t;
  handle: dir_$old_dir_ptr_t;
  chain_level: integer;
  slot_idx: pinteger;
  cname_len: pinteger;
  parsed_len: pinteger;
  bak_len: integer;
  fold_len: integer;
  bak_found: boolean;
  found: boolean;
begin
  { the name }
  if not name_$validate_leaf(leaf, leaf_len, parsed, parsed_len)
     or else ((parsed_len > 28) and then (parsed_len <> leaf_len)) then
  begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  { the backup name }
  if leaf_len > 28 then
    bak_len := 32
  else
    bak_len := leaf_len + 4;
  bak_name := leaf;
  bak_name[bak_len - 3] := '.';
  bak_name[bak_len - 2] := 'b';
  bak_name[bak_len - 1] := 'a';
  bak_name[bak_len] := 'k';

  name_$lock_dir(dir_uid, handle, 4, 0, status_ret);
  if status_ret.code <> 0 then
    goto 90;

  { the entry }
  found := dir_$old_find_entry(handle, parsed, parsed_len, entry, slot_idx,
                               chain_level);
  with entry^ do
    if not found then begin
      { a new entry }
      name_$unlock_dir(status_ret);
      acl_$exit_super;
      if status_ret.code <> 0 then
        return;
      acl_$def_acldata(acl_data, default_acl);
      dir_$old_get_default_acl(dir_uid, acl_$file_acl, default_acl,
                               status_ret);
      if status_ret.code <> 0 then
        return;
      file_$set_prot(backup_uid, file_$prot_acl, acl_data, default_acl,
                     status_ret);
      if status_ret.code <> 0 then
        return;
      dir_$old_add_hard_linku(dir_uid, leaf, leaf_len, backup_uid,
                              status_ret);
      if status_ret.code <> 0 then
        return;
      file_$fw_file(dir_uid, status_ret);
      return;
    end
    else begin
      { the existing entry, an object }
      if slot_type <> 1 then begin
        status_ret.all := name_$ill_link_op;
        goto 80;
      end;
      old_file_uid := uid;
    end;

  discard(acl_$rights(old_file_uid, true, 2, 0, status_ret));
  if status_ret.all <> status_$ok then begin
    if status_ret.all = status_$acl_wrong_type then
      status_ret.all := name_$not_file
    else
      name_convert_acl_status(status_ret);
    goto 80;
  end;

  { an existing `.BAK' of the folded name }
  if parsed_len > 28 then
    fold_len := 32
  else
    fold_len := parsed_len + 4;
  parsed[fold_len - 3] := '.';
  parsed[fold_len - 2] := 'B';
  parsed[fold_len - 1] := 'A';
  parsed[fold_len] := 'K';
  bak_found := dir_$old_find_entry(handle, parsed, fold_len, bak_entry,
                                   slot_idx, chain_level);
  with bak_entry^ do
    if bak_found then begin
      if slot_type <> 1 then begin
        status_ret.all := name_$ill_link_op;
        goto 80;
      end;
      discard(acl_$rights(uid, true, 2, 0, status_ret));
      if status_ret.all <> status_$ok then begin
        if status_ret.all = status_$acl_wrong_type then
          status_ret.all := name_$not_file
        else
          name_convert_acl_status(status_ret);
        goto 80;
      end;
    end;

  name_$unlock_dir(status_ret);
  if status_ret.all <> status_$ok then
    goto 90;

  { the old object's protection for the new }
  file_$get_attributes(old_file_uid, 1, 16#90, loc_rec, attr_rec.attrs,
                       status_ret);
  if status_ret.code <> 0 then
    goto 90;
  file_$set_prot(backup_uid, file_$prot_acl, attr_rec.prot, attr_rec.def_acl,
                 status_ret);
  if status_ret.code <> 0 then
    goto 90;

  { an existing backup deleted }
  if bak_found then begin
    name_$old_delete_entryu(dir_uid, bak_name, bak_len, true, true, false,
                            delete_uid, status_ret);
    if status_ret.all <> status_$ok then
      goto 90;
  end;

  { the old entry renamed }
  cname_len := bak_len;
  dir_$old_cnameu(dir_uid, leaf, leaf_len, bak_name, cname_len, status_ret);
  if status_ret.all <> status_$ok then
    goto 90;

  { the new object entered }
  dir_$old_add_hard_linku(dir_uid, leaf, leaf_len, backup_uid, status_ret);
  if status_ret.all <> status_$ok then
    goto 90;
  file_$fw_file(dir_uid, status_ret);
  goto 90;

  { the unlock tail }
80:
  name_$unlock_dir(unlock_status);
  if status_ret.code = 0 then
    status_ret := unlock_status;

90:
  acl_$exit_super;
end;
