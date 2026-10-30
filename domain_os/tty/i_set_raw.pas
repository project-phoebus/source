{ TTY_$I_SET_RAW - switch a line into or out of raw mode, by line
  number.

  Image addresses:
    sau2  0x00E673AA  TTY_$I_SET_RAW

  - tty_$i_set_raw_mode on the line's descriptor.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$i_set_raw(line: integer; raw: boolean; out status: status_$t);
  options(val_param);
var
  tty: tty_$desc_ptr_t;
begin
  tty := tty_$desc_ptr_t(tty_$i_get_desc(line, status));
  if status.all <> status_$ok then
    return;
  tty_$i_set_raw_mode(tty^, raw);
end;
