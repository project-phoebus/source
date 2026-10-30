{ name_$split_path - split a pathname into its directory and its leaf.

  Image addresses:
    sau2  0x00E49E48  name_$split_path

  - The path is scanned back from its end to the last '/'; the
    directory's length is that '/''s position, less the '/' itself
    unless it is "/" or "//".

  Status stored: none.
}

procedure name_$split_path(in path: univ name_$long_pname_t;
                           path_len: pinteger;
                           out dirname_len: pinteger;
                           out filename_idx: pinteger;
                           out filename_len: integer);
  internal;
var
  i: pinteger;
begin
  { back over the leaf }
  i := path_len;
  filename_len := 0;
  while (i <= path_len) and then (path[i] <> '/') do begin
    filename_len := filename_len + 1;
    filename_idx := i;
    i := i - 1;
  end;

  { the directory without its last '/', but for "/" and "//" }
  dirname_len := i;
  if dirname_len > 1 then
    if (path[2] <> '/') or else (dirname_len <> 2) or else
       (path[1] <> '/') then
      dirname_len := dirname_len - 1;
end;
