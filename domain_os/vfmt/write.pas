{ VFMT_$WRITE - format a control string and write it to the console.

  Image addresses:
    sau2  0x00E6AFE2  VFMT_$WRITE

  - VFMT_$MAIN into a 200-byte buffer, then TERM_$WRITE to terminal
    line 1, at most 100 characters a call, its status not looked at.
  - Reached through the hand-written VFMT_$WRITEN thunk.

  Status stored: none.
}

procedure vfmt_$write(in control_string: univ vfmt_$string_t;
                      in args: vfmt_$arg_ptr_t);
var
  buf: vfmt_$string_t;
  status: status_$t;                      { written, never read }
  pos: integer;
  len: integer;
begin
  vfmt_$main(control_string, buf, 200, len, args);

  pos := 1;
  while len > 0 do
    if len <= 100 then begin
      term_$write(1, buf[pos], len, status);
      len := 0;
    end
    else begin
      term_$write(1, buf[pos], 100, status);
      pos := pos + 100;
      len := len - 100;
    end;
end;
