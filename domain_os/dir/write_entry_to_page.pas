{ dir_$write_entry_to_page - build a new entry in a page at an index
  position (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4F100  dir_$write_entry_to_page (nested)

  - The entry's space comes from the bottom of the page's heap, its
    offset into index slot idx; a leaf entry gets add_entry's type and
    fields, an interior one type 1 and its child page.
  - The name comes from add_entry's, or page to page by the nested
    dir_$copy_name_cross_page.
  - Nested in dir_$insert_entry (itself nested in dir_$add_entry), whose
    frames it reaches.

  Status stored: none.
}

    procedure dir_$write_entry_to_page(flag: boolean;
                                       var page: dir_$root_page_ptr_t;
                                       idx: integer);
    var
      slot: dir_$word_ptr_t;
      entry: dir_$entry_ptr_t;
      text: dir_$name_ptr_t;
      i: integer;

%include 'dir/copy_name_cross_page.pas';

    begin
      page^.hdr.heap_base := page^.hdr.heap_base - entry_size;

      { the index slot }
      slot := dir_$word_ptr_t((idx - 1) * 2 + integer32(page) + 16#12);
      if page^.hdr.page_no = 0 then
        slot := dir_$word_ptr_t(integer32(slot) + page^.root_len);

      slot^ := page^.hdr.heap_base;
      page^.hdr.index_end := page^.hdr.index_end + 2;
      entry := dir_$entry_ptr_t(slot^ + integer32(page));
      entry^.flag_set := [];
      entry^.name_len := name_len;

      if page^.hdr.flags.kind = 0 then begin
        entry^.bits.kind := entry_type;
        case entry^.flags & 7 of
          dir_entry_interior: begin
            crash_system(status_$naming_internal_error);
          end;
          dir_entry_file: begin
               entry^.uid := uid;
               entry^.extra := 0;
               entry^.child := 0;
             end;
          dir_entry_hard_link: begin
               entry^.uid := uid;
               entry^.extra := extra;
               entry^.reserved_10 := 0;
               entry^.child := 0;
             end;
          dir_entry_soft_link: begin
               entry^.child := link_len;
               entry^.link_page := overflow_page;
               entry^.unused_06 := 0;
               entry^.unused_0a := 0;
             end;
        end;
      end
      else begin
        entry^.bits.kind := 1;
        if flag then
          entry^.child := split_pages[page_count + 2]
        else
          entry^.child := split_pages[page_count + 1];
      end;

      { the name }
      text := dir_$name_ptr_t(dir_$name_offset_table[entry^.flags & 7] +
                              integer32(entry));
      if src_name_loc = 0 then begin
        for i := 1 to name_len do
          text^[i] := name[i];
      end
      else
        dir_$copy_name_cross_page(src_name_loc div 16#400,
                                  src_name_loc mod 16#400,
                                  page^.hdr.page_no,
                                  integer32(text) - integer32(page),
                                  name_len);

      { a soft link's text kept in the entry }
      if (page^.hdr.flags.kind = 0) and then (entry_type = 4) and then
         (overflow_page = 16#FFFF) then begin
        text := dir_$name_ptr_t(
                  integer32(addr(dir_$entry_ptr_t(page^.hdr.heap_base +
                                   integer32(page))^.link_name)) +
                  name_len);
        for i := 1 to link_len do
          text^[i] := link_data[i];
      end;
    end;
