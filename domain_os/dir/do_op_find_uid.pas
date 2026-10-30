{ dir_$do_op_find_uid - DIR_$DO_OP's 16#46 operation: an entry by its
  UID (or by its node).

  Image addresses:
    sau2  0x00E4E41A  dir_$do_op_find_uid

  - As super-user, the directory opened for reading; a mount point's
    target is searched for as the mount point.
  - With flag true the node (the UIDs' low 20 bits) is compared and a
    hard link's extra longword handed back; with flag false the whole
    UID, the entry's name handed back.
  - Not found in the network root, the network is asked and its answer
    added to the local root as a hard link.

  Status stored:
    status_$ok: the entry was found, here (dir_$open_dir's) or by the
      network (REM_NAME_$FIND_NETWORK's or REM_NAME_$FIND_UID's)
    dir_$open_dir's status: the directory could not be opened
    name_$not_found: no match, or the network failed
}

{ TODO(pascal) open bytes in dir_$do_op_find_uid's frame

  The SAU2 frame has 30 bytes that no object explains.  Stand-ins are
  not declared: dpc's own frame differs anyway, and no instruction
  addresses the bytes. }

procedure dir_$do_op_find_uid(in uid: uid_$t; in target_uid: uid_$t;
                              flag: boolean;
                              out name_ret: univ name_$long_name_t;
                              out len_ret: integer;
                              out extra_ret: integer32;
                              out status_ret: status_$t);
  internal;
label
  10;
var
  drop_uid: uid_$t;
  search_uid: uid_$t;
  result: rem_name_$dir_entry_t;
  path: dir_$path_t;
  add_status: status_$t;
  find_ret: dir_$entry_ptr_t;
  handle: dir_$handle_ptr_t;
  volume: integer;
  page_idx: pinteger;
  depth: integer;
  found: boolean;
  entry: dir_$entry_ptr_t;
  page_data: dir_$root_page_ptr_t;
  base: integer;
  base_ptr: dir_$index_ptr_t;
  ename: dir_$name_ptr_t;
  n: integer;
  i: integer;
  j: integer;
begin
  acl_$enter_super;
  len_ret := 0;
  extra_ret := 0;

  dir_$open_dir(uid, 1, 0, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { a mount point's target searched as the mount point }
  search_uid := target_uid;
  for n := 1 to dir_$mttab.count do
    if target_uid = dir_$mttab.mount_tgt[n] then begin
      search_uid := dir_$mttab.mount_uid[n];
      exit;
    end;

  { the first entry }
  discard(dir_$find_entry(handle^, chr(0), 1, 16#20, find_ret, path,
                          depth));
  entry := find_ret;
  page_data := dir_$map_page(handle^, path[depth].page_no);
  found := false;

  repeat
    if page_data^.hdr.page_no = 0 then
      base := 16#12 + page_data^.root_len
    else
      base := 16#12;
    base_ptr := dir_$index_ptr_t(base + integer32(page_data));

    { its entries }
    for i := 1 to (page_data^.hdr.index_end - base) div 2 do begin
      entry := dir_$entry_ptr_t(base_ptr^[i] + integer32(page_data));
      case entry^.flags & 7 of
        dir_entry_file, dir_entry_hard_link: begin
          if flag then
            found := (search_uid.low & 16#FFFFF) =
                     (entry^.uid.low & 16#FFFFF)
          else
            found := search_uid = entry^.uid;
          if found then
            exit;
        end;
      end;
    end;

    { the next page }
    if found then
      exit;
    dir_$next_page(handle^, depth, path, page_idx);
    if page_idx = 16#FFFF then
      exit;
    page_data := dir_$map_page(handle^, page_idx);
  until false;

  if found then begin
    { found here }
    if flag then begin
      if entry^.flags & 7 = 3 then
        extra_ret := entry^.extra;
    end
    else begin
      ename := dir_$name_ptr_t(dir_$name_offset_table[entry^.flags & 7] +
                               integer32(entry));
      len_ret := entry^.name_len;
      for i := 1 to len_ret do
        name_ret[i] := ename^[i];
    end;
  end
  else begin
    if uid = name_$root_uid then begin
      { ask the network }
      dir_$release_handle(handle);
      if flag then
        rem_name_$find_network(uid, target_uid.low & 16#FFFFF, result,
                               status_ret)
      else
        rem_name_$find_uid(uid, target_uid, result, status_ret);
      if status_ret.all = status_$ok then begin
        { the name's capitals folded }
        for j := 1 to result.name_len do
          if result.name[j] in ['A'..'Z'] then
            result.name[j] := chr(ord(result.name[j]) + 16#20);

        { added to the local root }
        dir_$do_op_add_entry(uid, 0, result.name, result.name_len, 3,
                             result.extra, result.uid, 0, '', volume,
                             add_status);
        if add_status.all = name_$already_exists then begin
          dir_$do_op_drop_entry(uid, 0, result.name, result.name_len, 3,
                                drop_uid, add_status);
          dir_$do_op_add_entry(uid, 0, result.name, result.name_len, 3,
                               result.extra, result.uid, 0, '', volume,
                               add_status);
        end;

        if flag then
          extra_ret := result.extra
        else begin
          len_ret := result.name_len;
          for i := 1 to len_ret do
            name_ret[i] := result.name[i];
        end;
        goto 10;
      end;
    end;

    status_ret.all := name_$not_found;
  end;

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
