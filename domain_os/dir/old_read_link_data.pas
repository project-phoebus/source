{ dir_$old_read_link_data - read a soft link's text out of its blocks.

  Image addresses:
    sau2  0x00E55764  dir_$old_read_link_data (module-local)

  - The link's reference (its slot's UID field) gives the length and the
    blocks, copied 144 bytes each.

  Status stored: none.
}

procedure dir_$old_read_link_data(dir: dir_$old_dir_ptr_t;
                                  in refs: univ dir_$old_link_refs_t;
                                  out buf: univ name_$long_pname_t;
                                  out buf_len: pinteger);
  internal;
var
  n: pinteger;
  j: pinteger;
  i: pinteger;
begin
  n := 0;
  buf_len := refs.text_len;

  for j := 1 to 3 do
    with dir^.blocks[refs.blocks[j]] do
      for i := 1 to 144 do begin
        buf[(j - 1) * 16#90 + i] := text[i];
        n := n + 1;
        if n = refs.text_len then
          return;
      end;
end;
