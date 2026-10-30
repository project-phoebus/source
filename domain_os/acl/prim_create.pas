{ ACL_$PRIM_CREATE - create an ACL object from a version-5 ACL image.

  Image addresses:
    sau2  0x00E47968  ACL_$PRIM_CREATE

  - A remote directory's ACL is made by REM_FILE_$ACL_CREATE.
  - Otherwise, as super-user, the file is created, mapped and filled
    (acl_$prim_create_internal for type 0, else a copy and the magic
    16#FEDCA983), unmapped, made immutable and purified.  A required
    subsystem clears every entry's rights member 1.

  Status stored:
    ast_$purify's status: the object was made
    ast_$get_acl_attributes' status: the directory could not be read
    rem_file_$acl_create's status: a remote directory
    status_$image_buffer_too_small: the length does not fit the count
    file_$priv_create's status: the create failed
    mst_$maps', mst_$unmap_privi's, file_$mk_immutable's or ast_$purify's
      status, fail bit set: that step failed
}

{ TODO(pascal) the address of ACL_$PRIM_CREATE's magic longword formed in one register and copied to another

  The store of the magic longword at +0x3F8 of the mapped image copies
  the pointer, forms the element's address in one address register and
  copies it into another before the store.  A plain element store, as
  written here, would address it once off the pointer.  The copy has the
  shape of a `with' temporary; a `with' over a record at +0x3F8 (the
  image's last but one longword, which no type here gives a record of
  its own) would fit.  The original construct is not identified. }

procedure acl_$prim_create(var acl_data: univ acl_$cache_slot_t;
                           in data_len: integer; in dir_uid: uid_$t;
                           in prot: acl_$prot_data_t;
                           var file_uid_ret: uid_$t;
                           out status_ret: status_$t);
label
  10, 20;
var
  loc: file_$obj_loc_t;
  attrs: ast_$acl_attr_t;
  local_status: status_$t;
  map_info: integer32;
  image_len: integer;
  mapped: acl_$image_longs_ptr_t;
  i: integer;                             { the count only }
begin
  { the directory's attributes }
  loc.uid := dir_uid;
  loc.flags := loc.flags - [6];
  ast_$get_acl_attributes(loc, 1, attrs, local_status);
  if local_status.all <> status_$ok then begin
    status_ret := local_status;
    return;
  end;

  { a remote directory }
  if not (0 in attrs.obj_flags) and then (7 in loc.flags) then begin
    rem_file_$acl_create(loc.loc_info, acl_data, prot, dir_uid,
                         file_uid_ret, status_ret);
    return;
  end;

  { as the super user; the image's length }
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  if data_len <> acl_data.entry_count * sizeof(acl_$cache_entry_t) + 52
  then begin
    status_ret.all := status_$image_buffer_too_small;
    goto 10;
  end;

  { a required subsystem }
  if acl_data.required_uid <> uid_$nil then
    for i := 1 to acl_data.entry_count do
      acl_data.entries[i].rights := acl_data.entries[i].rights - [1];

  { the file, mapped }
  discard(file_$priv_create(3, uid_$nil, dir_uid, file_uid_ret, 0, 0, nil,
                            status_ret));
  if status_ret.code <> 0 then
    goto 10;
  mapped := mst_$maps(proc1_$as_id, true, file_uid_ret, 0, 1024, 16#16, 0,
                      true, map_info, status_ret);
  if status_ret.code <> 0 then
    goto 20;

  { its contents }
  if attrs.obj_type = 0 then
    acl_$prim_create_internal(prot, acl_data, data_len, acl_data.type_uid,
                              false, mapped^, image_len, status_ret)
  else begin
    for i := 1 to data_len div 4 do
      mapped^[i] := acl_$image_longs_ptr_t(addr(acl_data))^[i];
    mapped^[255] := -16#0123567D;                       { 16#FEDCA983 }
  end;

  { unmapped, immutable, purified }
  mst_$unmap_privi(1, file_uid_ret, integer32(mapped), 1024, proc1_$as_id,
                   status_ret);
  if status_ret.code <> 0 then
    goto 20;
  file_$mk_immutable(file_uid_ret, status_ret);
  if status_ret.code <> 0 then
    goto 20;
  ast_$purify(file_uid_ret, 2, 0, 0, 0, status_ret);
  if status_ret.code = 0 then
    goto 10;

20:
  status_ret.fail := true;
10:
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;
end;
