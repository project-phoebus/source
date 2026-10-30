{ dir_$move_entries_to_page - copy a run of entries to the new page of
  a split (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4EF7C  dir_$move_entries_to_page (nested)

  - Each entry of from_idx..to_idx is copied to the new page's heap with
    an index slot, its old copy marked dead.
  - Nested in dir_$insert_entry (itself nested in dir_$add_entry), whose
    frames it reaches.

  Status stored: none.
}

    procedure dir_$move_entries_to_page(from_idx: integer; to_idx: integer);
    var
      i: integer;
      entry: dir_$entry_ptr_t;
      size: integer;
      slot: dir_$word_ptr_t;
      dst: dir_$words_ptr_t;
      j: integer;
    begin
      if from_idx <= to_idx then begin
        page_data^.flag_set := page_data^.flag_set + [13];

        for i := from_idx to to_idx do begin
          entry := dir_$entry_ptr_t(idx_base^[i] + integer32(page_data));
          size := dir_$calc_entry_size(entry^);

          { a slot and space on the new page }
          slot := dir_$word_ptr_t(new_page^.hdr.index_end +
                                  integer32(new_page));
          new_page^.hdr.index_end := new_page^.hdr.index_end + 2;
          new_page^.hdr.heap_base := new_page^.hdr.heap_base - size;
          slot^ := new_page^.hdr.heap_base;
          dst := dir_$words_ptr_t(slot^ + integer32(new_page));

          for j := 1 to size div 2 do
            dst^[j] := dir_$words_ptr_t(entry)^[j];

          entry^.flag_set := entry^.flag_set + [15];
        end;
      end;
    end;
