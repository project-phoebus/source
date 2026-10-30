{ TTY_$I_ENABLE_CRASH_FUNC - make a character the line's crash character,
  or stop having one.

  Image addresses:
    sau2  0x00E67292  TTY_$I_ENABLE_CRASH_FUNC

  - Disabling makes ch, the argument, ordinary.

  Status stored: none.
}

procedure tty_$i_enable_crash_func(in out tty: tty_$desc_t; ch: char;
                                   enable: boolean);
  options(val_param);
begin
  if enable then begin
    tty.crash_char := ch;
    tty.char_class[ch] := tty_$class_crash;
  end
  else begin
    if tty.crash_char <> chr(0) then
      tty.char_class[ch] := tty_$class_normal;
    tty.crash_char := chr(0);
  end;
end;
