{ kbd_$send_mode - send the keyboard a mode command.

  Image addresses:
    sau6  0x7801EB0C  kbd_$send_mode (module-local)
    sau7  0x3C420DF8  kbd_$send_mode (module-local)
    sau9  0x3C41F748  kbd_$send_mode (module-local)

  - The command is 16#FF and a mode code: mode 1's for mode 1, mode
    0's for any other.

  Status stored: none.
}

procedure kbd_$send_mode(var kbd: kbd_$desc_t; mode: integer); internal;
var
  cmd: array[0..1] of char;
begin
  cmd[0] := chr(16#FF);
  if mode = 1 then
    cmd[1] := kbd_$mode_table[1]
  else
    cmd[1] := kbd_$mode_table[0];
  kbd_$put_line(kbd, 0, cmd, 2);
end;
