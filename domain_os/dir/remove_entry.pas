{ dir_$remove_entry - remove an entry from a directory by its name.

  Image addresses:
    sau2  0x00E50FC8  dir_$remove_entry
    sau2  0x00E50D5E  dir_$remove_entry_from_page (nested)

  - A file's or hard link's entry hands its UID back; a soft link's own
    text page is invalidated after the removal.
  - The nested dir_$remove_entry_from_page takes the entry out of its
    leaf page; a page left empty is removed from its parent in turn.
  - An emptied leaf lets the directory's tail of empty pages be cut
    (AST_$TRUNCATE) when that saves 4096 bytes or more.

  Status stored:
    status_$ok: the entry was removed
    ast_$purify's status: a page was purified after the removal
    name_$not_found: the name is not in the directory
    name_$not_link: operation type 4 on an entry that is not a soft link
    name_$ill_link_op: another non-zero operation type on a soft link
}

{ TODO(pascal) the open bytes of dir_$remove_entry's and its nested
  routine's frames

  In the SAU2 image dir_$remove_entry's frame leaves 18 bytes no object
  explains, beside the reserved slot, and the nested routine's 16
  bytes; the register-held locals account for some only if each keeps a
  slot.  dpc packs the declarations below without these holes, so in
  its build the nested routine reaches the parent's objects at dpc's
  offsets (the same open point as dir/add_entry.pas's TODO). }

procedure dir_$remove_entry(var handle: dir_$handle_t;
                            in name: univ name_$long_name_t;
                            name_len: integer; op_type: integer;
                            out uid_ret: uid_$t;
                            out status_ret: status_$t);
  internal;
var
  dir_uid: uid_$t;
  path: dir_$path_t;
  purify_seg: integer32;
  page0: dir_$root_page_ptr_t;
  sub_status: status_$t;
  tab: dir_$index_ptr_t;
  entry: dir_$entry_ptr_t;
  entry_ret: dir_$entry_ptr_t;
  hdr_size: integer;
  n_entries: integer;
  entry_idx: integer;
  depth: integer;
  trunc_result: boolean;
  did_truncate: boolean;
  is_leaf: boolean;
  level: integer;
  link_page: pinteger;
  last_page: pinteger;
  new_size: integer32;
  tail_page: dir_$root_page_ptr_t;

  procedure dir_$remove_entry_from_page(page_idx: integer;
                                        out status_ret: status_$t);
  var
    page: dir_$root_page_ptr_t;
    i: integer;
  begin
    status_ret.all := status_$ok;

    page := dir_$map_page(handle, path[page_idx].page_no);

    { the header's size }
    if page^.hdr.page_no = 0 then begin
      page0 := page;
      hdr_size := 16#12 + page0^.root_len;
    end
    else
      hdr_size := 16#12;

    n_entries := (page^.hdr.index_end - hdr_size) div 2;

    { a page other than the root loses its last entry: the page goes }
    if (page^.hdr.page_no <> 0) and then (n_entries = 1) then begin
      dir_$remove_entry_from_page(page_idx - 1, status_ret);
      if status_ret.all <> status_$ok then
        return;
      dir_uid := handle.uid;
      ast_$invalidate(dir_uid, path[page_idx].page_no, 1, true, sub_status);
      return;
    end;

    entry_idx := path[page_idx].entry_idx;
    tab := dir_$index_ptr_t(hdr_size + integer32(page));
    if entry_idx > n_entries then
      crash_system(status_$naming_internal_error);
    entry := dir_$entry_ptr_t(tab^[entry_idx] + integer32(page));
    is_leaf := page^.hdr.flags.kind = 1;

    dir_$wire_page(handle, page);

    { the root's last entry: an empty leaf root }
    if (page^.hdr.page_no = 0) and then (n_entries = 1) then begin
      if not is_leaf then
        crash_system(status_$naming_internal_error);
      page^.word_00 := 0;
      page^.hdr.flags.format := 5;
      page^.hdr.flags.kind := 0;
      page^.hdr.index_end := hdr_size;
      page^.hdr.heap_base := 16#400;
      page^.hdr.heap_base := (page^.hdr.heap_base - 16#0E) & (-4);
      tab^[1] := page^.hdr.heap_base;
      page^.hdr.index_end := page^.hdr.index_end + 2;
      entry := dir_$entry_ptr_t(tab^[1] + integer32(page));
      entry^.flag_set := [];
      entry^.bits.kind := 4;
      entry^.name_len := 1;
      entry^.child := 0;
      entry^.link_page := -1;
      entry^.link_name[1] := chr(0);
    end

    { any other entry }
    else begin
      if is_leaf and then (entry_idx = 1) then begin
        entry_ret := entry;
        entry := dir_$entry_ptr_t(tab^[2] + integer32(page));
        entry_ret^.child := entry^.child;
        entry_idx := 2;
      end;
      entry^.flag_set := entry^.flag_set + [15];
      for i := entry_idx to n_entries - 1 do
        tab^[i] := tab^[i + 1];
      page^.hdr.index_end := page^.hdr.index_end - 2;
      page^.flag_set := page^.flag_set + [13];
    end;

    dir_$release_wire(handle);

    { a leaf page: purified now }
    if is_leaf then begin
      did_truncate := true;
      purify_seg := page^.hdr.page_no;
      ast_$purify(handle.uid, 16#12, 0, purify_seg, 1, status_ret);
    end;
  end;

begin
  if not dir_$find_entry(handle, name, name_len, 8, entry_ret, path,
                         depth) then begin
    status_ret.all := name_$not_found;
    return;
  end;
  level := depth;

  if (entry_ret^.flags & 7 = 2) or else (entry_ret^.flags & 7 = 3) then
    uid_ret := entry_ret^.uid;

  { the operation against the entry's type }
  status_ret.all := status_$ok;
  if op_type <> 0 then
    if op_type = 4 then begin
      if entry_ret^.flags & 7 <> 4 then
        status_ret.all := name_$not_link;
    end
    else if entry_ret^.flags & 7 = 4 then
      status_ret.all := name_$ill_link_op;
  if status_ret.all <> status_$ok then
    return;

  if entry_ret^.flags & 7 = 4 then
    link_page := entry_ret^.link_page
  else
    link_page := 16#FFFF;

  did_truncate := false;
  dir_$remove_entry_from_page(level, status_ret);

  { a soft link's text page }
  if (link_page <> 16#FFFF) and then (status_ret.all = status_$ok) then
  begin
    if not did_truncate then begin
      purify_seg := path[level].page_no;
      ast_$purify(handle.uid, 16#12, 0, purify_seg, 1, status_ret);
    end;
    if status_ret.all = status_$ok then begin
      dir_uid := handle.uid;
      ast_$invalidate(dir_uid, link_page, 1, true, sub_status);
    end;
  end;

  if (not did_truncate) or else (status_ret.all <> status_$ok) then
    return;

  { the last page in use }
  last_page := handle.length div 1024 - 1;
  repeat
    tail_page := dir_$map_page(handle, last_page);
    if tail_page^.word_00 <> 0 then
      exit;
    if last_page = 0 then
      crash_system(status_$naming_internal_error);
    last_page := last_page - 1;
  until false;

  { the directory cut to it and a spare page }
  new_size := (last_page + 1) * 1024;
  if new_size <> 1024 then
    new_size := new_size + 16#400;
  if (new_size = 1024) or else (handle.length - new_size >= 4096) then
  begin
    ast_$truncate(handle.uid, new_size, 0, trunc_result, sub_status);
    if sub_status.all = status_$ok then
      handle.length := new_size;
  end;

  page0 := dir_$map_page(handle, 0);
  page0^.hdr.flags.seg_map_valid := handle.length <> 1024;
end;
