{ dir_$do_op_add_entry - add an entry, accepting a repeat of the same add.

  Image addresses:
    sau2  0x00E4FEF2  dir_$do_op_add_entry

  - As super-user, the directory opened for writing with the caller's
    rights.  An entry of an unknown type, met in the repeat check,
    crashes the system.
  - A hard link (type 3) added to the root records the object's hint
    (HINT_$ADDI); the directory's volume is handed back.

  Status stored:
    dir_$add_entry's status: the add was made, or failed
    status_$ok: a server process (type 9) repeated an add already made
    dir_$open_dir's status: the directory could not be opened
}

procedure dir_$do_op_add_entry(in uid: uid_$t; rights: integer;
                               in name: univ name_$long_name_t;
                               name_len: integer; entry_type: integer;
                               extra: integer32;
                               in target_uid: univ uid_$t;
                               link_len: integer;
                               in link_data: univ name_$long_pname_t;
                               out volume_ret: integer;
                               out status_ret: status_$t);
label
  10;
var
  hint: hint_$addr_t;
  entry: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  path: dir_$page_path_t;
  depth: integer;
  text: dir_$text_ptr_t;
  i: integer;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 2, rights, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  dir_$add_entry(handle^, name, name_len, entry_type, extra, target_uid,
                 link_len, link_data, status_ret);

  if (status_ret.all = name_$already_exists) and then
     (proc1_$type[proc1_$current] = 9) then begin
    if not dir_$find_entry(handle^, name, name_len, 0, entry, path,
                           depth) then
      goto 10;

    if entry^.flags & 7 <> entry_type then
      goto 10;

    case entry_type of
      dir_entry_file: begin
        if entry^.uid <> target_uid then
          goto 10;
      end;
      dir_entry_hard_link: begin
        if (entry^.uid <> target_uid) or else (entry^.extra <> extra) then
          goto 10;
      end;
      dir_entry_soft_link: begin
        if entry^.child <> link_len then
          goto 10;
        if entry^.link_page = -1 then
          text := dir_$text_ptr_t(entry^.name_len +
                                  integer32(addr(entry^.link_name)))
        else
          text := dir_$map_link_page(handle^, entry^.link_page);
        for i := 1 to link_len do
          if link_data[i] <> text^[i] then
            goto 10;
      end;
      otherwise begin
        crash_system(status_$naming_internal_error);
      end;
    end;

    status_ret.all := status_$ok;
  end
  else if status_ret.all <> status_$ok then
    goto 10;

  if (entry_type = 3) and then (uid = name_$root_uid) then begin
    hint.flags := extra;
    hint.node_id := target_uid.low & 16#FFFFF;
    hint_$addi(target_uid, hint);
  end;

  volume_ret := handle^.volume;

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
