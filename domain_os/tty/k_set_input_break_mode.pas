{ TTY_$K_SET_INPUT_BREAK_MODE - set a line's input break mode, for a
  caller of the kernel interface.

  Image addresses:
    sau2  0x00E6781E  TTY_$K_SET_INPUT_BREAK_MODE

  - In line mode (tty_$break_on_eol) the enabled line-ending functions
    (eol, cr, nl) are bound and the crash character gets the crash
    class; in the other modes they are made ordinary.
  - The tag is not checked.
  - The line-ending set is this routine's static, .DATA +0x28.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
}

procedure tty_$k_set_input_break_mode(in line: integer;
                                      in mode: tty_$input_break_mode_t;
                                      out status: status_$t);
var
  { .DATA +0x28, 4 bytes }
  line_end_funcs: static tty_$func_set_t :=
    [tty_$func_eol, tty_$func_cr, tty_$func_nl];    { [4, 6, 7] }
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  tty_$desc_ptr_t(tty)^.break_mode := mode;

  if mode.break_type = tty_$break_on_eol then begin
    { line mode }
    tty_$i_set_funcs(tty_$desc_ptr_t(tty)^, line_end_funcs, true);
    if tty_$desc_ptr_t(tty)^.crash_char <> chr(0) then
      tty_$desc_ptr_t(tty)^.char_class[tty_$desc_ptr_t(tty)^.crash_char] := tty_$class_crash;
  end
  else begin
    tty_$i_set_funcs(tty_$desc_ptr_t(tty)^, line_end_funcs, false);
    if tty_$desc_ptr_t(tty)^.crash_char <> chr(0) then
      tty_$desc_ptr_t(tty)^.char_class[tty_$desc_ptr_t(tty)^.crash_char] := tty_$class_normal;
  end;
end;
