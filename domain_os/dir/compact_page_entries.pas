{ dir_$compact_page_entries - squeeze the dead entries out of the
  current page's heap (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4F2DA  dir_$compact_page_entries (nested)

  - For a page marked as holding dead entries: the live words below each
    dead entry move up over it, the index slots that pointed below it
    with them.
  - Nested in dir_$insert_entry (itself nested in dir_$add_entry), whose
    frames it reaches.

  Status stored: none.
}

    procedure dir_$compact_page_entries;
    var
      scan: dir_$entry_ptr_t;
      size: integer;
      start: dir_$words_ptr_t;
      k: integer;
      offset: integer;
      j: integer;
    begin
      if 13 in page_data^.flag_set then begin
        page_data^.flag_set := page_data^.flag_set - [13];

        scan := dir_$entry_ptr_t(page_data^.hdr.heap_base +
                                 integer32(page_data));
        while linteger(page_data) + 16#400 > linteger(scan) do begin
          size := dir_$calc_entry_size(scan^);

          { a dead entry }
          if 15 in scan^.flag_set then begin
            start := dir_$words_ptr_t(page_data^.hdr.heap_base +
                                      integer32(page_data));
            for k := (integer32(scan) - integer32(start)) div 2 downto 1 do
              start^[k + size div 2] := start^[k];

            offset := integer32(scan) - integer32(page_data);
            for j := 1 to num_entries do
              if idx_base^[j] < offset then
                idx_base^[j] := size + idx_base^[j];

            page_data^.hdr.heap_base := page_data^.hdr.heap_base + size;
          end;

          scan := dir_$entry_ptr_t(integer32(scan) + size);
        end;
      end;
    end;
