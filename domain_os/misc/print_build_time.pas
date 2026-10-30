{ PRINT_BUILD_TIME - write the kernel's banner on the console.

  Image addresses:
    sau2  0x00E38000  PRINT_BUILD_TIME

  - GET_BUILD_TIME's text on its own line (VFMT_$WRITE2).

  Status stored: none.
}

procedure print_build_time;
var
  buf: array[1..104] of char;
  len: integer;
begin
  get_build_time(buf, len);
  vfmt_$write2('%/%a%/%.', buf, len);
end;
