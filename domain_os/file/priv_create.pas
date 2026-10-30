{ FILE_$PRIV_CREATE - create an object in a directory, locally or on the
  directory's node.

  Image addresses:
    sau2  0x00E5D382  FILE_$PRIV_CREATE

  - The directory is located and its attributes read.  The owner is the
    caller's (flags bit 1), nil, or the process's SIDs and projects.
  - On a remote parent the parent's node creates the object
    (REM_FILE_$CREATE_TYPE, or the pre-SR10 call); on a local one a new
    VTOCE is built and allocated (VTOC_$ALLOCATE).
  - A created object is loaded into the active object table; the result
    is true when the parent's attribute record's first byte is 0.

  Status stored:
    status_$ok: the object was created (also for a duplicate UID)
    ast_$get_attributes's status, with the fail bit but for "object not
      found": the directory's attributes could not be read
    file_$op_cannot_perform_here: a caller's UID for a remote parent
    file_$invalid_arg: type 4 or 5 to a pre-SR10 node
    status_$naming_vol_mounted_read_only or
      status_$file_volume_has_been_mounted_read_only: a read-only volume
    the callees' statuses: the remote create or the allocation failed
}

function file_$priv_create(file_type: integer; in type_uid: uid_$t;
                           in dir_uid: uid_$t; var file_uid_ret: uid_$t;
                           initial_size: integer32; flags: integer;
                           owner_info: univ_ptr;
                           out status_ret: status_$t): boolean;
label
  10;
var
  status: status_$t;
  owner_ptr: rem_file_$owner_info_ptr_t;
  clock: time_$clock_t;
  size: file_$create_size_t;
  owner_buf: rem_file_$owner_info_t;
  value: file_$attr_value_t;
  obj: file_$create_obj_t;
  lc: file_$create_loc_t;
  nl: file_$create_loc_t;
  acl_data: acl_sid_block_t;
  prot_info: acl_prot_info_t;
  is_file: boolean;
  is_dir: integer;
  i: integer;                             { the `for' (the count) }
begin
  { the size }
  if initial_size = 0 then
    size.all := file_$default_size
  else begin
    size.all := initial_size;
    size.explicit := true;
  end;

  { the directory's attributes }
  if dir_uid = uid_$nil then
    lc.loc.uid := name_$node_uid
  else
    lc.loc.uid := dir_uid;
  lc.loc.flags := lc.loc.flags - [6];
  ast_$get_attributes(lc.loc, 0, obj.attrs, status);
  if status.all <> status_$ok then begin
    if status.all <> file_$object_not_found then
      status.fail := true;
    status_ret := status;
    return;
  end;

  is_file := obj.v.flags1 <> 0;
  if (file_type = 1) or else
     (((not is_file) and ((flags & 1) <> 0)) and then (file_type <> 3)) then
    is_dir := 1
  else
    is_dir := 0;

  { the owner }
  owner_ptr := addr(owner_buf);
  if (flags & 2) <> 0 then begin
    if owner_info <> nil then
      owner_ptr := owner_info
    else begin
      owner_buf.sids.user_sid := ppo_$nil_user_uid;
      owner_buf.sids.group_sid := rgyc_$g_nil_uid;
      owner_buf.sids.org_sid := ppo_$nil_org_uid;
      owner_buf.projs.field_00 := 16#C;
      owner_buf.projs.field_04 := 16#C;
      owner_buf.projs.field_08 := 16#C;
    end;
  end
  else begin
    acl_$get_re_all_sids(acl_data, owner_buf.sids, prot_info,
                         owner_buf.projs, status);
    if owner_buf.projs.field_00 = 16#C then begin
      owner_buf.sids.user_sid := ppo_$nil_user_uid;
      owner_buf.sids.group_sid := rgyc_$g_nil_uid;
      owner_buf.sids.org_sid := ppo_$nil_org_uid;
    end;
  end;

  if 7 in lc.loc.flags then begin
    { a remote directory }
    if (flags & 2) <> 0 then begin
      status_ret.all := file_$op_cannot_perform_here;
      return;
    end;
    rem_file_$create_type(lc.loc, file_type, type_uid, size.all, flags,
                          owner_buf, obj.attrs, nl.loc, status);
    file_uid_ret := nl.loc.uid;
    if status.all <> status_$ok then begin
      if status.all = status_$vtoc_duplicate_uid then
        status.all := status_$ok
      else if status.all = file_$bad_reply_received_from_remote_node then
        if (file_type = 5) or else (file_type = 4) then
          status.all := file_$invalid_arg
        else begin
          rem_file_$create_type_presr10(lc.loc, file_type, is_dir,
                                        file_uid_ret, status);
          if (type_uid <> uid_$nil) and then (status.all = status_$ok)
          then begin
            value.uid := type_uid;
            ast_$set_attribute(file_uid_ret, 4, value, status);
          end;
          if (is_dir <> 0) and then (status.all = status_$ok) then begin
            value.flag := true;
            ast_$set_attribute(file_uid_ret, 0, value, status);
          end;
        end;
      goto 10;
    end;
  end
  else begin
    { a local directory }
    if obj.v.bits.read_only then begin
      if (file_type = 1) or else (file_type = 2) then
        status_ret.all := status_$naming_vol_mounted_read_only
      else
        status_ret.all := status_$file_volume_has_been_mounted_read_only;
      return;
    end;
    if (flags & 2) = 0 then
      uid_$gen(file_uid_ret);
    for i := 1 to 36 do
      obj.longs[i] := 0;
    obj.v.bits.dir := is_dir <> 0;
    clock.high := time_$current_clockh;
    clock.low := 0;
    obj.v.file_type := file_type;
    obj.v.file_uid := file_uid_ret;
    obj.v.type_uid := type_uid;
    obj.v.dtm := clock;
    obj.v.dtu := clock;
    obj.v.dta_high := time_$clockh;
    obj.v.dtb := clock;
    obj.v.parent_uid := lc.loc.uid;
    obj.v.refcount := 1;
    obj.v.acl_data := owner_ptr^.owner_bytes;
    obj.v.initial_size := size.all;
    obj.v.acl_ext := owner_ptr^.projs;
    obj.v.is_dir := is_dir;
    if is_file then
      obj.v.default_acl := uid_$nil
    else if (file_type = 1) or else (file_type = 2) then
      obj.v.default_acl := acl_$dndcal
    else if file_type = 3 then
      obj.v.default_acl := uid_$nil
    else
      obj.v.default_acl := acl_$fndwrx;
    nl.loc.uid := file_uid_ret;
    nl.byte_1c := lc.byte_1c;
    nl.loc.block_hint := lc.loc.block_hint;
    vtoc_$allocate(nl.req, obj.vtoce, status);
    if status.all <> status_$ok then
      goto 10;
  end;

  ast_$load_aote(obj.attrs, nl.loc);

10:
  status_ret := status;
  file_$priv_create := not is_file;
end;
