{ dir_$insert_entry - insert an entry into a directory page of the B-tree,
  splitting pages as needed (nested in dir_$add_entry).

  Image addresses:
    sau2  0x00E4F3BA  dir_$insert_entry (nested)

  - A page with room takes the entry in place; a soft link's write runs
    under a cleanup handler, a fault removing the half-added entry and
    being signaled again.
  - A full page is split where the sizes reach 503 bytes (less half the
    root area on the root page); a non-root page inserts its split
    point's name in its parent first, recursively.
  - Nested in dir_$add_entry, whose frame it reaches.

  Status stored:
    status_$ok: the entry was inserted
    dir_$finalize_split's status: a split ended at the leaf level
    name_$directory_full: a root split past eight levels
    dir_$alloc_split_page's or the recursive insert's status: that step
      failed
    dir_$remove_entry's status: a fault while writing a soft link
}

{ TODO(pascal) dir_$insert_entry's 14 open frame bytes and its stored limit

  Of the SAU2 frame's 0x1C bytes, -0x4 is the static link and
  -0x14..-0xE four words the nested routines read; 14 bytes no
  instruction addresses, and -0x1A holds the first shift loop's limit
  where the second keeps its limit in a register.  Five register-held
  locals (split_entry, found, move_from, k, j) would need 10 bytes at a
  slot each; which byte is whose, and why one `for' limit goes to the
  frame, is not settled.  The declarations below keep an earlier
  order. }

procedure dir_$insert_entry(slot_idx: integer; src_name_loc: linteger;
                            name_len: integer; out status_ret: status_$t);
var
  num_entries: integer;
  target_entry_idx: integer;
  entry_size: integer;
  base_offset: integer;
  split_entry: integer;
  found: boolean;
  move_from: integer;
  k: integer;                             { the shift loops' index }
  j: integer;

%include 'dir/purify_split_pages.pas';
%include 'dir/alloc_split_page.pas';
%include 'dir/finalize_split.pas';
%include 'dir/calc_entry_size.pas';
%include 'dir/move_entries_to_page.pas';
%include 'dir/write_entry_to_page.pas';
%include 'dir/compact_page_entries.pas';

begin
  status_ret.all := status_$ok;

  { the page at this level }
  page_data := dir_$map_page(handle, path[slot_idx].page_no);
  target_entry_idx := path[slot_idx].entry_idx;

  if page_data^.hdr.page_no = 0 then begin
    inter_page := page_data;
    base_offset := 16#12 + inter_page^.root_len;
  end
  else
    base_offset := 16#12;

  num_entries := (page_data^.hdr.index_end - base_offset) div 2;
  idx_base := dir_$index_ptr_t(base_offset + integer32(page_data));

  { the entry's size, rounded to 4 }
  if page_data^.hdr.flags.kind = 0 then begin
    entry_size := name_len + dir_$name_offset_table[entry_type];
    if (entry_type = 4) and then (overflow_page = 16#FFFF) then
      entry_size := entry_size + link_len;
  end
  else
    entry_size := name_len + 4;
  entry_size := (entry_size + 3) & (-4);

  free_space := page_data^.hdr.heap_base - page_data^.hdr.index_end;

  { reclaim the dead entries' space }
  if (entry_size + 2 > free_space) and then
     (13 in page_data^.flag_set) then begin
    dir_$wire_page(handle, page_data);
    dir_$compact_page_entries;
    dir_$release_wire(handle);
    free_space := page_data^.hdr.heap_base - page_data^.hdr.index_end;
  end;

  if entry_size + 2 > free_space then begin
    { the split's threshold }
    split_threshold := 16#1F7;
    if page_data^.hdr.page_no = 0 then begin
      if max_depth = 8 then begin
        status_ret.all := name_$directory_full;
        return;
      end;
      inter_page := page_data;
      split_threshold := split_threshold - inter_page^.root_len div 2;
    end;

    { the split point }
    accum_size := 0;
    split_entry := 0;
    found := false;
    repeat
      if split_entry = target_entry_idx then begin
        found := true;
        accum_size := accum_size + entry_size;
        if accum_size >= split_threshold then
          exit;
      end;
      split_entry := split_entry + 1;
      if split_entry > num_entries then
        crash_system(status_$naming_internal_error);
      temp_entry := dir_$entry_ptr_t(idx_base^[split_entry] +
                                     integer32(page_data));
      accum_size := accum_size + dir_$calc_entry_size(temp_entry^);
    until accum_size >= split_threshold;

    if page_data^.hdr.page_no = 0 then begin
      { the root's split pages }
      dir_$alloc_split_page(true, status_ret);
      if status_ret.all <> status_$ok then
        return;

      { the first new page }
      page_count := page_count + 1;
      new_page := dir_$map_page(handle, split_pages[page_count]);
      new_page^.word_00 := 0;
      new_page^.hdr.flags.kind := page_data^.hdr.flags.kind;
      new_page^.hdr.flags.format := page_data^.hdr.flags.format;
      new_page^.hdr.dir_uid := dir_uid;
      new_page^.hdr.page_no := split_pages[page_count];
      new_page^.hdr.next_page := new_page^.hdr.page_no + 1;
      new_page^.hdr.index_end := 16#12;
      new_page^.hdr.heap_base := 16#400;

      dir_$wire_page(handle, page_data);
      if page_data^.hdr.flags.kind = 0 then
        copy_start := 2
      else
        copy_start := 1;

      { the lower half, with the entry if it belongs there }
      if found then begin
        dir_$move_entries_to_page(copy_start, target_entry_idx);
        if page_data^.hdr.flags.kind = 0 then
          copy_start := target_entry_idx
        else
          copy_start := target_entry_idx + 1;
        dir_$write_entry_to_page(true, new_page, copy_start);
        dir_$move_entries_to_page(target_entry_idx + 1, split_entry);
      end
      else
        dir_$move_entries_to_page(copy_start, split_entry);

      { the second new page }
      page_count := page_count + 1;
      new_page := dir_$map_page(handle, split_pages[page_count]);
      new_page^.word_00 := 0;
      new_page^.hdr.flags.kind := page_data^.hdr.flags.kind;
      new_page^.hdr.flags.format := page_data^.hdr.flags.format;
      new_page^.hdr.dir_uid := dir_uid;
      new_page^.hdr.page_no := split_pages[page_count];
      new_page^.hdr.next_page := -1;
      new_page^.hdr.index_end := 16#12;
      new_page^.hdr.heap_base := 16#400;

      { the upper half }
      if not found then begin
        dir_$move_entries_to_page(split_entry + 1, target_entry_idx);
        move_from := target_entry_idx + 1;
        dir_$write_entry_to_page(false, new_page, move_from - split_entry);
        dir_$move_entries_to_page(move_from, num_entries);
      end
      else
        dir_$move_entries_to_page(split_entry + 1, num_entries);

      { the root becomes an interior page }
      page_data^.word_00 := 0;
      page_data^.hdr.flags.format := 5;
      page_data^.hdr.flags.kind := 1;
      page_data^.hdr.index_end := base_offset + 4;
      page_data^.hdr.heap_base := 16#400;
      page_data^.hdr.heap_base := (page_data^.hdr.heap_base - 6) & (-4);

      { its entry for the first new page }
      idx_base^[1] := page_data^.hdr.heap_base;
      temp_entry := dir_$entry_ptr_t(page_data^.hdr.heap_base +
                                     integer32(page_data));
      temp_entry^.flag_set := [];
      temp_entry^.bits.kind := 1;
      temp_entry^.name_len := 1;
      temp_entry^.child := split_pages[page_count - 1];
      temp_entry^.child_name[1] := chr(0);

      { the second new page's first entry }
      first_child_idx := dir_$word_ptr_t(16#12 + integer32(new_page));
      first_child_entry := dir_$entry_ptr_t(first_child_idx^ +
                                            integer32(new_page));
      first_child_name := dir_$name_ptr_t(
        dir_$name_offset_table[first_child_entry^.flags & 7] +
        integer32(first_child_entry));

      { the root's entry for it, named by it }
      page_data^.hdr.heap_base := page_data^.hdr.heap_base - 4 -
                                  first_child_entry^.name_len;
      page_data^.hdr.heap_base := page_data^.hdr.heap_base & (-4);
      idx_base^[2] := page_data^.hdr.heap_base;
      temp_entry := dir_$entry_ptr_t(page_data^.hdr.heap_base +
                                     integer32(page_data));
      temp_entry^.flag_set := [];
      temp_entry^.bits.kind := 1;
      temp_entry^.name_len := first_child_entry^.name_len;
      temp_entry^.child := split_pages[page_count];
      for j := 1 to temp_entry^.name_len do
        temp_entry^.child_name[j] := first_child_name^[j];
    end
    else begin
      { the name the parent level gets }
      if (split_entry = target_entry_idx) and then not found then begin
        recursive_param := src_name_loc;
        recursive_name_len := name_len;
      end
      else begin
        if split_entry + 1 > num_entries then
          crash_system(status_$naming_internal_error);
        temp_entry := dir_$entry_ptr_t(idx_base^[split_entry + 1] +
                                       integer32(page_data));
        recursive_param := idx_base^[split_entry + 1] +
                           page_data^.hdr.page_no * 16#400 +
                           dir_$name_offset_table[temp_entry^.flags & 7];
        recursive_name_len := temp_entry^.name_len;
      end;

      dir_$insert_entry(slot_idx - 1, recursive_param, recursive_name_len,
                        status_ret);
      if status_ret.all <> status_$ok then
        return;

      { the page again }
      page_data := dir_$map_page(handle, path[slot_idx].page_no);
      idx_base := dir_$index_ptr_t(base_offset + integer32(page_data));

      { the new page after it }
      page_count := page_count + 1;
      new_page := dir_$map_page(handle, split_pages[page_count]);
      new_page^.hdr.flags := page_data^.hdr.flags;
      new_page^.hdr.dir_uid := dir_uid;
      new_page^.hdr.page_no := split_pages[page_count];
      new_page^.hdr.next_page := page_data^.hdr.next_page;
      new_page^.hdr.index_end := 16#12;
      new_page^.hdr.heap_base := 16#400;
      dir_$wire_page(handle, page_data);

      { the upper half }
      if not found then begin
        dir_$move_entries_to_page(split_entry + 1, target_entry_idx);
        move_from := target_entry_idx + 1;
        dir_$write_entry_to_page(false, new_page, move_from - split_entry);
        dir_$move_entries_to_page(move_from, num_entries);
      end
      else
        dir_$move_entries_to_page(split_entry + 1, num_entries);

      { the lower half stays }
      page_data^.hdr.index_end := split_entry * 2 + base_offset;
      num_entries := split_entry;
      dir_$compact_page_entries;

      { the entry on the lower half }
      if found then begin
        for k := split_entry + 1 downto target_entry_idx + 2 do
          idx_base^[k] := idx_base^[k - 1];
        dir_$write_entry_to_page(false, page_data, target_entry_idx + 1);
      end;

      page_data^.hdr.next_page := split_pages[page_count];
    end;

    page_data^.hdr.dir_uid := dir_uid;
    dir_$release_wire(handle);
    if max_depth = slot_idx then
      dir_$finalize_split(status_ret);
  end
  else begin
    { an interior page's split page }
    if page_data^.hdr.flags.kind = 1 then begin
      dir_$alloc_split_page(false, status_ret);
      if status_ret.all <> status_$ok then
        return;
    end;

    { open the index at the entry }
    dir_$wire_page(handle, page_data);
    for k := num_entries + 1 downto target_entry_idx + 2 do
      idx_base^[k] := idx_base^[k - 1];

    if (not handle.split_busy) and then (entry_type = 4) then
      fim_status := fim_$cleanup(fim_data)
    else
      fim_status.all := status_$ok;

    if (fim_status.all = status_$ok) or else
       (fim_status.all = fault_$cleanup_set) then begin
      dir_$write_entry_to_page(false, page_data, target_entry_idx + 1);
      if fim_status.all = fault_$cleanup_set then
        fim_$rls_cleanup(fim_data);
    end
    else begin
      dir_$release_wire(handle);
      dir_$remove_entry(handle, name, name_len, 4, remove_uid, status_ret);
      fim_$signal(fim_status);
    end;

    if handle.split_busy then
      page_data^.hdr.dir_uid := dir_uid;
    dir_$release_wire(handle);
  end;
end;
