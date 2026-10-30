{ acl_$image_internal - render an ACL object as a version-5 ACL image.

  Image addresses:
    sau2  0x00E47B78  acl_$image_internal (module-local)

  Assume we're called with ml_$acl_lock held.

  - An ACL object's attributes are read first; a remote one's image is
    fetched (REM_FILE_$ACL_IMAGE, the flag set below version 5).
  - Otherwise the cache slot is copied when it fits, the subsystem
    rights (member 6) taken out unless asked for; with no slot, the
    52-byte default image.
  - The rights walk reads the entry count whether or not the slot was
    copied, and only st's low word is tested.

  Status stored:
    status_$ok: the image was rendered
    ast_$get_acl_attributes' status: the attributes could not be read
    status_$acl_wrong_type: the object is not an ACL
    rem_file_$acl_image's status: a remote object
    status_$image_buffer_too_small: the image does not fit the buffer
    acl_$find_acl_slot's status: the slot could not be found
}

procedure acl_$image_internal(uid: uid_$t; buffer_len: integer;
                              flag: boolean;
                              var image: univ acl_$cache_slot_t;
                              out len_out: integer;
                              var data_out: acl_$prot_data_t;
                              var flag_out: boolean;
                              out status: status_$t); internal;
var
  def_uid: uid_$t;
  loc: file_$obj_loc_t;
  attr: ast_$acl_attr_t;
  uid3: uid_$t;
  uid2: uid_$t;
  st: status_$t;
  slot: integer;
  len: integer;
  i: integer;                             { the counts only }
begin
  { the UID's normal form }
  acl_$uid_view_ptr_t(addr(uid))^.low_set :=
    acl_$uid_view_ptr_t(addr(uid))^.low_set - [24];
  uid2 := uid;

  { an ACL object's attributes; a remote one }
  if (uid <> acl_$nil) and then
     (acl_$uid_view_ptr_t(addr(uid))^.b0 <> 0) then begin
    loc.uid := uid;
    loc.flags := loc.flags - [6];
    ast_$get_acl_attributes(loc, 1, attr, st);
    if st.all <> status_$ok then begin
      status := st;
      return;
    end;
    if attr.sub_type <> 3 then begin
      status.all := status_$acl_wrong_type;
      return;
    end;
    if not (0 in attr.obj_flags) and then (7 in loc.flags) then begin
      rem_file_$acl_image(loc.loc_info, uid, flag, image, len_out, data_out,
                          status);
      if image.version < 5 then
        flag_out := true
      else
        flag_out := false;
      return;
    end;
  end;

  { the cache slot, or the default protection }
  if uid <> uid_$nil then
    slot := acl_$find_acl_slot(uid, flag_out, data_out, st)
  else begin
    acl_$def_acldata(data_out, def_uid);
    st.all := status_$ok;
    slot := acl_cache_no_slot;
    flag_out := false;
  end;

  if st.code = 0 then begin
    if slot <> acl_cache_no_slot then begin
      { the slot's image }
      len := acl_$acl_cache[slot].entry_count * 32 + 52;
      len_out := len;
      if len <= buffer_len then
        for i := 1 to len div 4 do
          acl_$image_longs_ptr_t(addr(image))^[i] :=
            acl_$image_longs_ptr_t(addr(acl_$acl_cache[slot]))^[i]
      else
        st.all := status_$image_buffer_too_small;

      { the subsystem rights taken out }
      if (not flag) and flag_out then begin
        with image do
          for i := 1 to entry_count do
            entries[i].rights := entries[i].rights - [6];
        data_out.owner_rights := data_out.owner_rights - [6];
        data_out.group_rights := data_out.group_rights - [6];
        data_out.org_rights := data_out.org_rights - [6];
        data_out.world_rights := data_out.world_rights - [6];
        data_out.subsys_rights := data_out.subsys_rights - [6];
      end;
    end
    else begin
      { the default image }
      len_out := 52;
      uid3 := uid2;
      if acl_$uid_view_ptr_t(addr(uid3))^.w0 = 2 then
        image.type_uid := acl_$dir_acl
      else
        image.type_uid := acl_$file_acl;
      image.entry_count := 0;
      image.required_uid := uid_$nil;
      image.subsys_uid := image.type_uid;
      image.version := 5;
      for i := 1 to 12 do
        image.words_2a[i] := 0;
      image.reserved_0a := 0;
      image.reserved_10 := 0;
      image.reserved_22 := 0;
      image.reserved_26 := 0;
      image.world_entry_present := false;
      image.unused_29 := chr(0);
    end;
  end
  else
    len_out := 0;

  status := st;
end;
