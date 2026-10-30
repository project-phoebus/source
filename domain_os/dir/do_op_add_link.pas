{ dir_$do_op_add_link - add a name for an existing object to a directory
  (DIR_$DO_OP's 16#2A and 16#2C: a plain add and a hard link).

  Image addresses:
    sau2  0x00E5044A  dir_$do_op_add_link

  - The entry is added first; a local object on the directory's volume
    then gets its link count raised, and a failure from there on drops
    the entry again.
  - A plain add of an object not found is accepted, marked remote.

  Status stored:
    status_$ok: the object is remote or on another volume
    ast_$set_attribute's status: the link count was raised
    dir_$do_op_add_entry's status: the entry could not be added
    ast_$get_common_attributes' status: the object could not be read
    name_$insufficient_rights: only right 16#40 of mask 16#48 is held
    name_convert_acl_status' status: another ACL_$RIGHTS failure
    status_$naming_too_many_hard_links: 65525 links or more
}

procedure dir_$do_op_add_link(in uid: uid_$t;
                              in name: univ name_$long_name_t;
                              name_len: integer; in file_uid: uid_$t;
                              is_hard_link: boolean;
                              out status_ret: status_$t);
label
  10, 20;
var
  value: file_$attr_value_t;
  drop_uid: uid_$t;
  loc: file_$obj_loc_t;
  attr: ast_$common_attr_t;
  status: status_$t;
  volume: integer;
  rights: integer;
begin
  dir_$do_op_add_entry(uid, 2, name, name_len, 2, 0, file_uid, 0, '',
                       volume, status);
  if status.all <> status_$ok then
    goto 20;

  loc.uid := file_uid;
  loc.flags := loc.flags - [6];
  ast_$get_common_attributes(loc, 16#90, attr, status);
  if status.all <> status_$ok then begin
    if is_hard_link or else
       (status.all <> file_$object_not_found) then
      goto 10;
    loc.flags := loc.flags + [7];
    status.all := status_$ok;
  end;

  if (7 in loc.flags) or else (status.all <> status_$ok) or else
     (volume <> loc.volume) then
    goto 10;

  { more links: the rights, the count }
  if attr.refcount <> 0 then begin
    rights := acl_$rights(file_uid, false, 16#48, -1, status);
    if (status.all = status_$insufficient_rights_to_perform_operation)
       or else (status.all = status_$ok)
       or else (status.all = status_$no_right_to_perform_operation) then
    begin
      if rights & 16#48 = 16#40 then begin
        status.all := name_$insufficient_rights;
        goto 10;
      end;
    end
    else begin
      name_convert_acl_status(status);
      goto 10;
    end;
    if attr.refcount >= 65525 then begin
      status.all := status_$naming_too_many_hard_links;
      goto 10;
    end;
  end;

  { one more link }
  value.word_val := 1;
  ast_$set_attribute(file_uid, 6, value, status);

  { undo the add }
10:
  if status.all <> status_$ok then begin
    status_ret := status;
    dir_$do_op_drop_entry(uid, 0, name, name_len, 2, drop_uid, status);
    return;
  end;

20:
  status_ret := status;
end;
