{ TTY_$I_INQ_RAW - whether a line is in raw mode, by line number.

  Image addresses:
    sau2  0x00E673EA  TTY_$I_INQ_RAW

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$i_inq_raw(line: integer; out raw: boolean;
                         out status: status_$t);
  options(val_param);
var
  tty: tty_$desc_ptr_t;
begin
  tty := tty_$desc_ptr_t(tty_$i_get_desc(line, status));
  if status.all <> status_$ok then
    return;
  raw := tty^.raw_mode;
end;
