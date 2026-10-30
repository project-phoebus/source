{ dir_$do_op_fix_dir - DIR_$DO_OP's 16#48: rebuild a damaged directory.

  Image addresses:
    sau2  0x00E53A18  dir_$do_op_fix_dir

  - As super-user, the directory opened for repair (mode 0, rights 2);
    the sane entries of its format-5 leaf pages go into a new directory,
    whose pages are copied back over the old object.
  - The new object, if one was made, gets a reference count of 0.

  Status stored:
    file_$fw_file's status: the directory was rebuilt
    dir_$open_dir's or dir_$create_dir_obj's status: that step failed
    dir_$add_entry's status: an add failed other than "already exists"
    file_$truncate's status: a truncation failed
}

{ TODO(pascal) dir_$do_op_fix_dir's open frame bytes

  The SAU2 frame has 82 bytes that no object explains, about one slot
  per register-held local if each keeps one: the same open point as the
  other DIR frames' TODOs (dir/README.md's list). }

procedure dir_$do_op_fix_dir(in uid: uid_$t; out status_ret: status_$t);
label
  10;
var
  name_buf: name_$long_name_t;
  entry_uid: uid_$t;
  new_dir_uid: uid_$t;
  saved_file_acl: uid_$t;
  saved_dir_acl: uid_$t;
  temp_status: status_$t;
  link_data: dir_$text_ptr_t;
  extra: integer32;
  page: dir_$root_page_ptr_t;
  page0: dir_$root_page_ptr_t;
  new_handle: dir_$handle_ptr_t;
  orig_handle: dir_$handle_ptr_t;
  ovf_page: pinteger;
  link_len: integer;
  entry_type: pinteger;
  total: pinteger;
  page_idx: integer;
  name_len: integer;
  page_end: linteger;
  table_off: integer;
  num: integer;
  table: dir_$index_ptr_t;
  entry_idx: integer;
  entry: dir_$entry_ptr_t;
  etype: integer;
  size: integer;
  name_p: dir_$name_ptr_t;
  k: integer;
  ovf: dir_$root_page_ptr_t;
  copy_page: integer;
  orig_page: dir_$root_page_ptr_t;
begin
  new_handle := nil;
  new_dir_uid := uid_$nil;
  acl_$enter_super;
  dir_$open_dir(uid, 0, 2, orig_handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { a new directory from the old root page }
  page := dir_$map_page(orig_handle^, 0);
  saved_dir_acl := page^.dir_def_prot.acl_uid;
  saved_file_acl := page^.file_def_prot.acl_uid;
  dir_$create_dir_obj(uid_$nil, page^, uid_$nil, uid_$nil, new_dir_uid,
                      status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  dir_$open_dir(new_dir_uid, 2, 0, new_handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { every old page's entries into the new one }
  total := orig_handle^.length div 1024 - 1;
  for page_idx := 0 to total do begin
    page := dir_$map_page(orig_handle^, page_idx);
    if (page^.hdr.flags.kind <> 0) or else
       (page_idx <> page^.hdr.page_no) or else
       (page^.hdr.flags.format <> 5) then
      next;
    page_end := linteger(page) + 16#400;
    if page_idx = 0 then
      table_off := 16#12 + page^.root_len
    else
      table_off := 16#12;
    if table_off >= 16#400 then
      next;
    num := (page^.hdr.index_end - table_off) div 2;
    if num >= 1024 then
      next;
    table := dir_$index_ptr_t(table_off + integer32(page));
    if linteger(table) >= page_end then
      next;

    for entry_idx := 1 to num do begin
      if (page_idx = 0) and then (entry_idx = 1) then
        next;
      entry := dir_$entry_ptr_t(table^[entry_idx] + integer32(page));
      if linteger(entry) + 2 >= page_end then
        next;
      etype := entry^.bits.kind;
      if etype > 7 then
        next;
      size := dir_$name_offset_table[etype] + entry^.name_len;
      if integer32(entry) + size > page_end then
        next;
      if (etype = 4) and then (entry^.link_page = -1) then
        size := size + entry^.child;
      if integer32(entry) + size > page_end then
        next;
      if entry^.name_len > 255 then
        next;
      name_p := dir_$name_ptr_t(dir_$name_offset_table[etype] +
                                integer32(entry));
      name_len := entry^.name_len;
      for k := 1 to name_len do
        name_buf[k] := name_p^[k];

      entry_type := etype;
      extra := 0;
      link_len := 0;
      case etype of
        dir_entry_file: begin
          entry_uid := entry^.uid;
        end;
        dir_entry_hard_link: begin
          entry_uid := entry^.uid;
          extra := entry^.extra;
        end;
        dir_entry_soft_link: begin
          if entry^.child > 16#3FF then
            next;
          entry_uid := uid_$nil;
          link_len := entry^.child;
          if entry^.link_page = -1 then
            link_data := dir_$text_ptr_t(entry^.name_len +
                                         integer32(addr(entry^.link_name)))
          else begin
            if pinteger(entry^.link_page) > total then
              next;
            ovf_page := entry^.link_page;
            ovf := dir_$map_page(orig_handle^, ovf_page);
            if ovf^.hdr.flags.kind <> 2 then
              next;
            link_data := dir_$text_ptr_t(integer32(ovf) + 1);
          end;
        end;
        otherwise begin
          next;
        end;
      end;

      dir_$add_entry(new_handle^, name_buf, name_len, entry_type, extra,
                     entry_uid, link_len, link_data^, status_ret);
      if (status_ret.all <> status_$ok) and then
         (status_ret.all <> name_$already_exists) then
        goto 10;
    end;
  end;

  file_$truncate(orig_handle^.uid, 16#400, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the new pages over the old }
  for copy_page := 0 to new_handle^.length div 1024 - 1 do begin
    orig_page := dir_$map_page(orig_handle^, copy_page);
    orig_page^ := dir_$root_page_ptr_t(dir_$map_page(new_handle^,
                                                     copy_page))^;
    if copy_page = 0 then begin
      orig_page^.dir_def_prot.acl_uid := saved_dir_acl;
      orig_page^.file_def_prot.acl_uid := saved_file_acl;
      orig_page^.flag_set := orig_page^.flag_set - [0..5];
      file_$fw_file(orig_handle^.uid, status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
    end;
  end;

  file_$truncate(orig_handle^.uid, new_handle^.length, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;
  file_$fw_file(orig_handle^.uid, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  page0 := dir_$map_page(orig_handle^, 0);
  page0^.hdr.flags.format := 5;
  file_$fw_file(orig_handle^.uid, status_ret);

10:
  dir_$release_handle(orig_handle);
  dir_$release_handle(new_handle);
  if new_dir_uid <> uid_$nil then
    file_$set_refcnt(new_dir_uid, 0, temp_status);
  acl_$exit_super;
end;
