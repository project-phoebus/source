{ FILE_$GET_SEG_MAP - which of an object's segments are mapped.

  Image addresses:
    sau2  0x00E74044  FILE_$GET_SEG_MAP

  - AST_$GET_SEG_MAP's map of one segment's worth (32 entries) from the
    start offset: its first longword's members become the caller's 32-bit
    bitmap, member k at bit k.

  Status stored:
    ast_$get_seg_map's status: in either case
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$get_seg_map(file_uid: uid_$t; in start_off: integer32;
                            in flags_in: boolean;
                            out bitmap_out: file_$seg_bits_t;
                            out status_ret: status_$t);
var
  segs: ast_$seg_map_t;
  location: integer32;
  local_status: status_$t;
  flags: ast_$seg_map_flags_t;
  i: integer;                             { the outer count }
  j: integer;
  bit_offset: integer;
begin
  bitmap_out := [];
  location := 0;
  if flags_in then
    flags := [ast_$seg_map_all_pages]
  else
    flags := [];

  ast_$get_seg_map(file_uid, start_off, location, 1, 16#20, flags, segs,
                   local_status);

  bit_offset := 0;
  for i := 0 to 0 do begin
    if segs[i] <> [] then
      for j := 0 to 31 do
        if j in segs[i] then
          bitmap_out := bitmap_out + [j + bit_offset];
    bit_offset := bit_offset + 32;
  end;

  status_ret := local_status;
end;
