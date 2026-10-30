{ dir_$copy_name_cross_page - copy bytes from one directory page to
  another through a 32-byte buffer (nested in dir_$write_entry_to_page).

  Image addresses:
    sau2  0x00E4F034  dir_$copy_name_cross_page (nested)

  - In chunks of at most 32 bytes, each read with the source page mapped
    and written with the destination mapped: the two may not be mapped
    at once.
  - Nested in dir_$write_entry_to_page, three levels inside
    dir_$add_entry, whose handle it reaches.

  Status stored: none.
}

      procedure dir_$copy_name_cross_page(src_page: integer;
                                          src_off: integer;
                                          dst_page: integer;
                                          dst_off: integer;
                                          len: integer);
      var
        buf: array[1..32] of char;
        chunk: integer;
        done: integer;
        i: integer;
        p: dir_$name_ptr_t;
      begin
        done := 0;

        repeat
          p := dir_$map_page(handle, src_page);
          p := dir_$name_ptr_t(integer32(p) + done + src_off);

          if len - done > 32 then
            chunk := 32
          else
            chunk := len - done;

          for i := 1 to chunk do
            buf[i] := p^[i];

          p := dir_$map_page(handle, dst_page);
          p := dir_$name_ptr_t(integer32(p) + done + dst_off);

          for i := 1 to chunk do
            p^[i] := buf[i];

          done := done + chunk;
        until done >= len;
      end;
