{ TTY_$K_SET_PGROUP - set the process group of a line, for a caller of
  the kernel interface.

  Image addresses:
    sau2  0x00E67900  TTY_$K_SET_PGROUP

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_pgroup(in line: integer; in uid: uid_$t;
                            out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;
  tty_$desc_ptr_t(tty)^.pgroup_uid := uid;
end;
