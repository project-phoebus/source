{ DTTY_$WRITE_STRING - write characters to the display through the PROM.

  Image addresses:
    sau2  0x00E1D690  DTTY_$WRITE_STRING
    sau4  0x0F81E9AE  DTTY_$WRITE_STRING
    sau6  0x7801F8FE  DTTY_$WRITE_STRING
    sau7  0x3C421944  DTTY_$WRITE_STRING
    sau9  0x3C42005C  DTTY_$WRITE_STRING

  - The display type is asked for and ignored; each character goes to
    DTTY_$PUTC.

  Status stored: none.
}

procedure dtty_$write_string(in str: univ dtty_$chars_t; in len: integer);
var
  i: integer;
begin
%if smd_display_memory or dtty_color_board or dtty_gpu %then
  dtty_$get_disp_type;
%else
  discard(dtty_$get_disp_type);
%endif
  for i := 1 to len do
    dtty_$putc(str[i]);
end;
