{ dir_$do_op_dir_readu - DIR_$DO_OP's operation 16#42: read a
  directory's entries into a reply buffer.

  Image addresses:
    sau2  0x00E4D954  dir_$do_op_dir_readu
    sau2  0x00E4D8AA  dir_$refind_entry (nested)

  - As super-user, the directory opened for reading; "." and ".." are
    written first when the read starts there.
  - The start is the entry after the name, or the continuation's page
    and entry; a full buffer or count leaves the continuation naming the
    entry that did not fit, 0 at the directory's end.
  - A mount point's UID is the mounted root's in the current format.

  Status stored:
    status_$ok: the entries were read, or there was nothing to do
    dir_$open_dir's status: the directory could not be opened
    file_$get_attributes' status: the parent for ".." could not be read
}

{ TODO(pascal) dir_$do_op_dir_readu's open frame bytes

  The SAU2 frame leaves 38 bytes unaddressed: the slots of six
  register-held locals and the 8-byte alignment explain some; 16 bytes
  just before path are not explained. }

procedure dir_$do_op_dir_readu(in uid: uid_$t; version: integer;
                               in name: univ name_$long_name_t;
                               name_flags: integer;
                               in out cont: univ dir_$readu_cont_t;
                               max_entries: integer32; max_size: linteger;
                               buf_ptr: dir_$readu_buf_ptr_t;
                               out size_ret: integer32;
                               out offset_ret: integer32;
                               out count_ret: integer32;
                               out status_ret: status_$t);
label
  10, 20;
var
  dir_$readu_cookie_first: static integer32 := 16#00020001;
                                          { A5+0x2114 }
  dir_$readu_cookie_dotdot: static integer32 := 16#00010001;
                                          { A5+0x2118 }
  dir_$readu_cookie_dot: static integer32 := 16#00000001;
                                          { A5+0x211C }
  attrs: file_$attributes_t;
  loc: file_$obj_loc_t;
  path: dir_$path_t;
  entry_name: dir_$name_ptr_t;
  entry_ptr: dir_$entry_ptr_t;
  base_ptr: dir_$index_ptr_t;
  page_data: dir_$root_page_ptr_t;
  handle: dir_$handle_ptr_t;
  local_name_len: integer;
  virt_len: integer;
  entry_idx: integer;
  page_idx: pinteger;
  depth: integer;
  num_entries: integer;
  is_old_version: boolean;
  overflow: boolean;
  at_eof: boolean;
  word_idx: linteger;
  last_entry: integer32;
  entry_size: pinteger;
  base: integer;
  k: integer;
  j: integer;
  n: integer;

%include 'dir/refind_entry.pas';             { dir_$refind_entry, nested }

begin
  depth := 0;
  count_ret := 0;
  word_idx := 0;
  status_ret.all := status_$ok;
  last_entry := 0;
  size_ret := 0;
  offset_ret := 0;
  local_name_len := name_flags;
  is_old_version := version = 0;

  if max_entries = 0 then
    return;
  if max_size = 0 then
    return;
  if (cont.all = 0) and then (local_name_len = 0) then
    return;

  at_eof := false;
  overflow := false;
  acl_$enter_super;
  dir_$open_dir(uid, 1, 4, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 20;

  { the starting name }
  if is_old_version then begin
    if local_name_len = 32 then
      local_name_len := 0;
    if local_name_len = 0 then
      if cont.all = dir_$readu_cookie_dot then
        cont.all := dir_$readu_cookie_first;
  end
  else if local_name_len <> 0 then begin
    if (local_name_len = 1) and then (name[1] = '.') then begin
      cont.all := dir_$readu_cookie_dotdot;
      local_name_len := 0;
    end
    else if (local_name_len = 2) and then (name[1] = '.') and then
            (name[2] = '.') then begin
      cont.all := dir_$readu_cookie_first;
      local_name_len := 0;
    end;
  end;

  { "." and ".." }
  if local_name_len = 0 then
    if (cont.all = dir_$readu_cookie_dot) or else
       (cont.all = dir_$readu_cookie_dotdot) then
      repeat
        if cont.all = dir_$readu_cookie_dot then
          virt_len := 1
        else
          virt_len := 2;

        entry_size := (virt_len + 16#1A) & (-4);
        if (word_idx * 2 + entry_size > max_size) or else
           (max_entries = count_ret) then begin
          overflow := true;
          exit;
        end;

        last_entry := integer32(addr(buf_ptr^[word_idx]));
        word_idx := word_idx + entry_size div 2;
        count_ret := count_ret + 1;

        with dir_$readu_entry_ptr_t(last_entry)^ do begin
          entnxt := entry_size;
          enthandle := cont.all;
          entlen := virt_len;
          for k := 1 to virt_len do
            entname[k] := '.';
          entname[virt_len + 1] := chr(0);
          enttype := 1;

          if cont.all = dir_$readu_cookie_dotdot then begin
            if uid = name_$node_uid then
              entuid := name_$root_uid
            else begin
              file_$get_attributes(uid, 1, 16#90, loc, attrs, status_ret);
              if status_ret.all <> status_$ok then
                goto 20;
              entuid := attrs.dirptr;
            end;
          end
          else
            entuid := uid;

          entextra := 0;
        end;

        cont.entry_idx := cont.entry_idx + 1;
      until cont.all = dir_$readu_cookie_first;

  if overflow then
    goto 20;

  { the first page and entry }
  if local_name_len <> 0 then begin
    discard(dir_$find_entry(handle^, name, local_name_len, 16#20,
                            entry_ptr, path, depth));
    page_idx := path[depth].page_no;
    entry_idx := path[depth].entry_idx + 1;
  end
  else begin
    if cont.page <> 0 then
      page_idx := cont.page - 1
    else
      page_idx := 0;
    entry_idx := cont.entry_idx;
    if page_idx > (handle^.length - 1) div 1024 then
      goto 20;
    if (page_idx = 0) and then (entry_idx <= 2) then begin
      discard(dir_$find_entry(handle^, chr(0), 1, 16#20, entry_ptr, path,
                              depth));
      page_idx := path[depth].page_no;
      entry_idx := path[depth].entry_idx;
    end;
    if entry_idx = 0 then
      entry_idx := 1;
  end;
  if (page_idx = 0) and then (entry_idx = 1) then
    entry_idx := 2;

  repeat
    { the page }
    page_data := dir_$map_page(handle^, page_idx);
    if page_data^.word_00 = 0 then
      exit;
    if page_data^.hdr.flags.kind <> 0 then
      exit;

    if page_data^.hdr.page_no = 0 then
      base := 16#12 + page_data^.root_len
    else
      base := 16#12;
    num_entries := (page_data^.hdr.index_end - base) div 2;
    base_ptr := dir_$index_ptr_t(base + integer32(page_data));

    { its entries }
    while entry_idx <= num_entries do begin
      entry_ptr := dir_$entry_ptr_t(base_ptr^[entry_idx] +
                                    integer32(page_data));
      if is_old_version then begin
        entry_size := entry_ptr^.name_len + 16#10;
        if odd(entry_size) then
          entry_size := entry_size + 1;
      end
      else
        entry_size := (entry_ptr^.name_len + 16#1A) & (-4);

      if (word_idx * 2 + entry_size > max_size) or else
         (max_entries = count_ret) then begin
        overflow := true;
        exit;
      end;

      entry_name := dir_$name_ptr_t(
                      dir_$name_offset_table[entry_ptr^.flags & 7] +
                      integer32(entry_ptr));
      last_entry := integer32(addr(buf_ptr^[word_idx]));
      word_idx := word_idx + entry_size div 2;
      count_ret := count_ret + 1;

      if is_old_version then
        with dir_$readu_old_entry_ptr_t(last_entry)^ do begin
          entlen := entry_ptr^.name_len;
          for j := 1 to entry_ptr^.name_len do
            entname[j] := entry_name^[j];

          case entry_ptr^.flags & 7 of
            dir_entry_file: begin
              enttype := 1;
              entuid := entry_ptr^.uid;
              entextra := 0;
            end;
            dir_entry_hard_link: begin
              enttype := 1;
              entuid := entry_ptr^.uid;
              entextra := entry_ptr^.extra;
            end;
            dir_entry_soft_link: begin
              enttype := 3;
              entuid := uid_$nil;
              entextra := 0;
            end;
            otherwise begin
              crash_system(status_$naming_internal_error);
            end;
          end;
        end
      else
        with dir_$readu_entry_ptr_t(last_entry)^ do begin
          entnxt := entry_size;
          cont.page := page_idx + 1;
          cont.entry_idx := entry_idx;
          enthandle := cont.all;
          entlen := entry_ptr^.name_len;
          for j := 1 to entry_ptr^.name_len do
            entname[j] := entry_name^[j];
          entname[entlen + 1] := chr(0);

          case entry_ptr^.flags & 7 of
            dir_entry_file: begin
              enttype := 1;
              entuid := entry_ptr^.uid;
              entextra := 0;
              for n := 1 to dir_$mttab.count do
                if entuid = dir_$mttab.mount_uid[n] then begin
                  entuid := dir_$mttab.mount_tgt[n];
                  exit;
                end;
            end;
            dir_entry_hard_link: begin
              enttype := 1;
              entuid := entry_ptr^.uid;
              entextra := entry_ptr^.extra;
            end;
            dir_entry_soft_link: begin
              enttype := 3;
              entuid := uid_$nil;
              entextra := 0;
            end;
            otherwise begin
              crash_system(status_$naming_internal_error);
            end;
          end;
        end;

      entry_idx := entry_idx + 1;
    end;

    if overflow then
      goto 10;

    { the next page }
    if depth = 0 then begin
      dir_$refind_entry;
      if at_eof then
        goto 10;
    end;
    dir_$next_page(handle^, depth, path, page_idx);
    if page_idx = 16#FFFF then
      exit;
    entry_idx := 1;
  until false;

  at_eof := true;

10:
  if at_eof then
    cont.all := 0
  else begin
    cont.page := page_idx + 1;
    cont.entry_idx := entry_idx;
  end;

20:
  size_ret := word_idx * 2;
  if last_entry = 0 then
    offset_ret := 0
  else
    offset_ret := last_entry - integer32(buf_ptr);
  dir_$release_handle(handle);
  acl_$exit_super;
end;
