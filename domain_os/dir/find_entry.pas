{ dir_$find_entry - search a directory's pages for a name.

  Image addresses:
    sau2  0x00E4C9E4  dir_$find_entry (module-local)

  - From the root page down, each page's index table bisected, names
    compared byte by byte, unsigned; each level's page and index go into
    the path.  A path deeper than flags allows crashes the system.
  - The result is whether a leaf's entry matched (chr(0) never does);
    the last entry looked at is left in entry_ret.

  Status stored: none.
}

function dir_$find_entry(var handle: dir_$handle_t;
                         in name: univ name_$long_name_t;
                         name_len: integer; flags: integer;
                         out entry_ret: dir_$entry_ptr_t;
                         out extra: univ dir_$path_t;
                         out depth_ret: integer): boolean;
  internal;
label
  10;
var
  num_entries: integer;
  page_data: dir_$root_page_ptr_t;
  base_offset: integer;
  offset_array: dir_$index_ptr_t;
  lo: integer;
  mid: integer;
  cmp_result: integer;
  entry_name_len: integer;
  entry_name: dir_$name_ptr_t;
  i: integer;
begin
  depth_ret := 0;
  page_data := dir_$map_page(handle, 0);
  base_offset := 16#12 + page_data^.root_len;

  repeat
    { this page's index table }
    offset_array := dir_$index_ptr_t(base_offset + integer32(page_data));
    num_entries := (page_data^.hdr.index_end - base_offset) div 2;

    if page_data^.hdr.flags.kind = 1 then begin
      lo := 2;
      cmp_result := -1;
      mid := 2;
    end
    else
      lo := 1;

    while lo <= num_entries do begin
      { the middle entry }
      mid := (num_entries + lo) div 2;
      entry_ret := dir_$entry_ptr_t(offset_array^[mid] +
                                    integer32(page_data));
      entry_name := dir_$name_ptr_t(
                      dir_$name_offset_table[entry_ret^.flags & 7] +
                      integer32(entry_ret));
      entry_name_len := entry_ret^.name_len;

      { the names compared }
      i := 0;
      repeat
        i := i + 1;
        if i > name_len then begin
          if i > entry_name_len then begin
            cmp_result := 0;
            goto 10;
          end;
          cmp_result := -1;
          exit;
        end;
        if i > entry_name_len then begin
          cmp_result := 1;
          exit;
        end;
        if name[i] < entry_name^[i] then begin
          cmp_result := -1;
          exit;
        end;
        if name[i] > entry_name^[i] then begin
          cmp_result := 1;
          exit;
        end;
      until false;

      if cmp_result > 0 then
        lo := mid + 1
      else
        num_entries := mid - 1;
    end;

    if cmp_result < 0 then
      mid := mid - 1;

    { this level in the path }
10:
    depth_ret := depth_ret + 1;
    if depth_ret <= flags then begin
      extra[depth_ret].page_no := page_data^.hdr.page_no;
      extra[depth_ret].entry_idx := mid;
    end
    else if flags <> 0 then
      crash_system(status_$naming_internal_error);

    { an interior page: its child }
    if page_data^.hdr.flags.kind <> 1 then
      exit;
    entry_ret := dir_$entry_ptr_t(offset_array^[mid] +
                                  integer32(page_data));
    base_offset := 16#12;
    page_data := dir_$map_page(handle, entry_ret^.child);
  until false;

  { a leaf page }
  if (name_len = 1) and then (name[1] = chr(0)) then
    dir_$find_entry := false
  else
    dir_$find_entry := cmp_result = 0;
end;
