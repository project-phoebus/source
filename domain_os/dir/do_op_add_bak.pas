{ dir_$do_op_add_bak - DIR_$DO_OP's 16#34: enter an object as the backup
  of a name, the name's old object becoming "<name>.bak".

  Image addresses:
    sau2  0x00E50832  dir_$do_op_add_bak
    sau2  0x00E50790  dir_$add_bak_default_prot (nested)

  - The backup name is the name with '.bak' appended, cut to 32
    characters for a request of version 0, else to 255.
  - The new object's link count is raised (attribute 6) and lowered
    again (attribute 7) if the routine fails after that.
  - An old backup object that is local and on the volume is deleted
    first; the backup entry then names the old object, the name the new.

  Status stored:
    file_$fw_file's status: the backup was made
    status_$ok: the name names the new object already
    dir_$open_dir's status: the directory could not be opened
    ast_$get_location's or ast_$set_attribute's status: the new object
      could not be located or counted
    file_$objects_on_different_volumes: the new object is remote or on
      another volume
    name_$ill_link_op: the name or the backup name is a soft link
    name_$not_file: ACL_$RIGHTS said "wrong type", or the old backup
      object is not a file
    name_convert_acl_status' status: another ACL_$RIGHTS failure
    acl_$copy's, file_$delete_obj's or dir_$add_entry's status: that
      step failed
    the nested routine's callees' statuses: the name was not in the
      directory
}

{ TODO(pascal) open bytes in dir_$do_op_add_bak's frame

  The SAU2 frame has 14 bytes that the locals do not explain.  Not
  settled; no stand-in is declared. }

procedure dir_$do_op_add_bak(in uid: uid_$t; req_version: integer;
                             in name: univ name_$long_name_t;
                             name_len: integer; in uid_data: uid_$t;
                             out result_uid: uid_$t;
                             out status_ret: status_$t);
label
  10;
var
  bak: static array[1..4] of char := '.bak';
                                          { A5+0x2120 }
  value: file_$attr_value_t;
  old_bak_uid: uid_$t;
  orig_uid: uid_$t;
  loc: file_$obj_loc_t;
  attr: ast_$common_attr_t;
  bak_name: name_$long_name_t;
  get_loc_unused: integer32;
  local_status: status_$t;
  location: ast_$location_t;
  entry: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  path: integer;
  depth: integer;
  rollback: boolean;
  deleted: boolean;
  bak_name_len: integer32;
  orig_extra: integer32;
  i: integer;
  j: integer;
  type_byte: integer;

%include 'dir/add_bak_default_prot.pas';   { nested }

begin
  result_uid := uid_$nil;
  rollback := false;

  if req_version = 0 then begin
    bak_name_len := name_len + 4;
    if bak_name_len > 32 then
      bak_name_len := 32;
  end
  else begin
    bak_name_len := name_len + 4;
    if bak_name_len > 255 then
      bak_name_len := 255;
  end;

  for i := 1 to name_len do
    bak_name[i] := name[i];
  for j := 1 to 4 do
    bak_name[j + (bak_name_len - 4)] := bak[j];

  acl_$enter_super;
  dir_$open_dir(uid, 2, 0, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the new object, local and on the volume }
  loc.uid := uid_data;
  loc.flags := loc.flags - [6];
  ast_$get_location(loc, 1, get_loc_unused, location, local_status);
  if (local_status.all <> status_$ok) or else
     (handle^.volume <> loc.volume) or else (7 in loc.flags) then begin
    status_ret := local_status;
    if status_ret.all = status_$ok then
      status_ret.all := file_$objects_on_different_volumes;
    goto 10;
  end;

  { one more link, undone on failure }
  value.word_val := 1;
  ast_$set_attribute(uid_data, 6, value, local_status);
  if local_status.all <> status_$ok then begin
    status_ret := local_status;
    goto 10;
  end;
  rollback := true;

  { no such name }
  if not dir_$find_entry(handle^, name, name_len, 0, entry, path,
                         depth) then begin
    dir_$add_bak_default_prot;
    goto 10;
  end;

  if entry^.bits.kind = 4 then begin
    status_ret.all := name_$ill_link_op;
    goto 10;
  end;
  orig_uid := entry^.uid;
  orig_extra := entry^.extra;

  { the old object's rights }
  discard(acl_$rights(orig_uid, true, 2, 0, status_ret));
  if status_ret.all <> status_$ok then begin
    if status_ret.all = status_$acl_wrong_type then begin
      status_ret.all := name_$not_file;
      goto 10;
    end;
    name_convert_acl_status(status_ret);
    goto 10;
  end;

  { its ACL to the new object }
  if orig_uid = uid_data then
    goto 10;
  acl_$copy(orig_uid, uid_data, acl_$filein_acl, acl_$filein_acl,
            status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the backup name }
  if dir_$find_entry(handle^, bak_name, bak_name_len, 0, entry, path,
                     depth) then begin
    if entry^.bits.kind = 4 then begin
      status_ret.all := name_$ill_link_op;
      goto 10;
    end;

    { the old backup's rights }
    old_bak_uid := entry^.uid;
    discard(acl_$rights(old_bak_uid, true, 2, 0, status_ret));
    if status_ret.all <> status_$ok then begin
      status_ret.fail := false;
      if status_ret.all <> file_$object_not_found then begin
        if status_ret.all = status_$acl_wrong_type then begin
          status_ret.all := name_$not_file;
          goto 10;
        end;
        name_convert_acl_status(status_ret);
        goto 10;
      end;
    end;

    { a local file on the volume is deleted }
    loc.uid := old_bak_uid;
    loc.flags := loc.flags - [6];
    ast_$get_common_attributes(loc, 16#81, attr, local_status);
    if not (7 in loc.flags) and then (local_status.all = status_$ok) and
       then (handle^.volume = loc.volume) then begin
      type_byte := ord(attr.sub_type);
      if not ((type_byte = 5) or (type_byte = 4) or (type_byte = 0)) then
      begin
        status_ret.all := name_$not_file;
        goto 10;
      end;
      file_$delete_obj(old_bak_uid, true, deleted, status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
      if deleted then
        result_uid := old_bak_uid;
    end;

    { the backup entry names the old object }
    entry^.uid := orig_uid;
    entry^.extra := orig_extra;
  end
  else begin
    dir_$add_entry(handle^, bak_name, bak_name_len, 2, 0, orig_uid, 0, '',
                   status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  { the name names the new object }
  if not dir_$find_entry(handle^, name, name_len, 0, entry, path,
                         depth) then
    crash_system(status_$naming_internal_error);
  entry^.uid := uid_data;
  rollback := false;
  file_$fw_file(uid, status_ret);

10:
  dir_$release_handle(handle);
  acl_$exit_super;
  if (status_ret.all <> status_$ok) and then rollback then
    ast_$set_attribute(uid_data, 7, value, local_status);
end;
