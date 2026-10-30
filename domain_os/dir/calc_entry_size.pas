{ dir_$calc_entry_size - the size of a directory entry, rounded to 4
  (nested in dir_$insert_entry).

  Image addresses:
    sau2  0x00E4EF42  dir_$calc_entry_size (nested)

  - A soft link's (type 4) text, kept in the entry, counts too.
  - Nested though it reaches no enclosing frame: it lies inside
    dir_$insert_entry's family, and its callers are that family's.

  Status stored: none.
}

    function dir_$calc_entry_size(var entry: dir_$entry_t): integer;
    var
      kind: integer;
      size: integer;
    begin
      kind := entry.flags & 7;
      size := dir_$name_offset_table[kind] + entry.name_len;

      if (kind = 4) and then (entry.link_page = -1) then
        size := size + entry.child;

      dir_$calc_entry_size := (size + 3) & (-4);
    end;
