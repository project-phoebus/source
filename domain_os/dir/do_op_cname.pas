{ dir_$do_op_cname - DIR_$DO_OP's handler for operation 16#32, renaming a
  directory entry.

  Image addresses:
    sau2  0x00E518BC  dir_$do_op_cname

  - As super-user, the directory opened for writing (mode 2, rights 2).
  - A soft link's text is copied under DIR_$LINK_BUF_MUTEX into the
    module's link buffer, the mutex released after the add.
  - An entry of another kind crashes the system.

  Status stored:
    dir_$remove_entry's status: the new name was added
    dir_$add_entry's status: it could not be
    status_$ok: a server process (type 9) found only the new name (a
      retried rename)
    dir_$open_dir's status: the directory could not be opened
    name_$not_found: the old name is missing
    status_$ast_only_local_access_allowed: a server process renaming an
      object that forbids remote access
    status_$naming_directory_locked: the object is a mount's source
    name_$insufficient_rights: ACL_$RIGHTS granted right 16#40
    name_convert_acl_status' status: another ACL_$RIGHTS failure
}

{ TODO(pascal) dir_$do_op_cname's open frame bytes

  The SAU2 frame leaves 22 bytes to no declared object.  The same open
  point as the other DIR handlers' frames (dir/README.md). }

procedure dir_$do_op_cname(in uid: uid_$t; req_version: integer;
                           in old_name: univ name_$long_name_t;
                           old_name_len: integer;
                           in new_name: univ name_$long_name_t;
                           new_name_len: integer;
                           out status_ret: status_$t);
label
  10;
var
  attrs: dir_$acl_attr_view_t;
  loc: file_$obj_loc_t;
  path: dir_$path_t;
  entry: dir_$entry_ptr_t;
  extra: integer32;
  handle: dir_$handle_ptr_t;
  page: pinteger;
  depth: integer;
  entry_type: integer;
  link_len: integer;
  rights: integer32;
  src: dir_$text_ptr_t;
  n: integer;
  i: integer;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 2, 2, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the old name }
  if not dir_$find_entry(handle^, old_name, old_name_len, 8, entry, path,
                         depth) then begin
    if (proc1_$type[proc1_$current] = 9) and then
       dir_$find_entry(handle^, new_name, new_name_len, 8, entry, path,
                       depth) then
      goto 10;
    status_ret.all := name_$not_found;
    goto 10;
  end;

  entry_type := entry^.bits.kind;
  case entry_type of
    dir_entry_file: begin
      { an object }
      loc.uid := entry^.uid;
      if proc1_$type[proc1_$current] = 9 then begin
        loc.flags := loc.flags - [6];
        ast_$get_acl_attributes(loc, 16#80, attrs.attr, status_ret);
        if (status_ret.all = status_$ok) and then attrs.local_only then
        begin
          status_ret.all := status_$ast_only_local_access_allowed;
          goto 10;
        end;
      end;

      { not a mount's source }
      for n := 1 to dir_$mttab.count do
        if loc.uid = dir_$mttab.mount_uid[n] then begin
          status_ret.all := status_$naming_directory_locked;
          goto 10;
        end;

      { the rights }
      rights := acl_$rights(loc.uid, true, 16#40, -1, status_ret);
      if (status_ret.all = status_$no_right_to_perform_operation)
         or else (status_ret.all =
                  status_$insufficient_rights_to_perform_operation)
         or else (status_ret.all = status_$ok) then begin
        if (rights & 16#40) <> 0 then begin
          status_ret.all := name_$insufficient_rights;
          goto 10;
        end;
      end
      else begin
        status_ret.fail := false;
        if status_ret.all <> file_$object_not_found then begin
          name_convert_acl_status(status_ret);
          goto 10;
        end;
      end;
    end;
    dir_entry_hard_link: begin
      { a hard link }
      extra := entry^.extra;
      loc.uid := entry^.uid;
    end;
    dir_entry_soft_link: begin
      { a soft link, its text to the buffer }
      link_len := entry^.child;
      ml_$exclusion_start(dir_$link_buf_mutex);
      dir_$link_buf_owner := proc1_$current;

      if entry^.link_page = -1 then
        src := dir_$text_ptr_t(entry^.name_len + integer32(entry) + 12)
      else begin
        page := entry^.link_page;
        src := dir_$text_ptr_t(integer32(dir_$map_page(handle^, page)) + 1);
      end;

      for i := 1 to link_len do
        dir_$link_buf[i] := src^[i];
    end;
    otherwise begin
      crash_system(status_$naming_internal_error);
    end;
  end;

  { the new name }
  dir_$add_entry(handle^, new_name, new_name_len, entry_type, extra,
                 loc.uid, link_len, dir_$link_buf, status_ret);

  if proc1_$current = dir_$link_buf_owner then begin
    dir_$link_buf_owner := 0;
    ml_$exclusion_stop(dir_$link_buf_mutex);
  end;

  { the old name goes }
  if status_ret.all = status_$ok then
    dir_$remove_entry(handle^, old_name, old_name_len, entry_type, loc.uid,
                      status_ret);

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
