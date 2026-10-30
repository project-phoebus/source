{ dir_$refind_entry - find a page's last entry again, so as to record the
  path to it (nested in dir_$do_op_dir_readu).

  Image addresses:
    sau2  0x00E4D8AA  dir_$refind_entry (nested)

  - A page with no entries sets the parent's end flag; otherwise up to 32
    levels of the path to its last entry go into the parent's path.
  - The entry not found again crashes the system
    (status_$naming_internal_error).
  - Nested in dir_$do_op_dir_readu, whose locals it reaches.

  Status stored: none.
}

  procedure dir_$refind_entry;
  var
    name_len: integer;
    i: integer;
    name_buf: name_$long_name_t;
  begin
    if num_entries = 0 then begin
      at_eof := true;
      return;
    end;

    entry_ptr := dir_$entry_ptr_t(base_ptr^[num_entries] +
                                  integer32(page_data));
    entry_name := dir_$name_ptr_t(
                    dir_$name_offset_table[entry_ptr^.flags & 7] +
                    integer32(entry_ptr));
    name_len := entry_ptr^.name_len;

    for i := 1 to name_len do
      name_buf[i] := entry_name^[i];

    if not dir_$find_entry(handle^, name_buf, name_len, 16#20, entry_ptr,
                           path, depth) then
      crash_system(status_$naming_internal_error);
  end;
