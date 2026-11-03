{ LPR_$INIT - probe the line printer port and set it up.

  Image addresses:
    sau3  0x00E32F34  LPR_$INIT

  - When the port answers, the circular buffer is set up, LPR_$INT
    becomes the level 5 autovector's handler and the current mode (0) is
    programmed.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure lpr_$init;
var
  data: integer;
begin
  lpr_$present := testpage(0, addr(lpr), data);
  if lpr_$present then begin
    cbuf_$init_cb(lpr_$bcb, lpr_$buffer, 512);
    lpr_vec := addr(lpr_$int);
    lpr_set_mode;
  end;
end;
