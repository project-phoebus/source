{ KBD_$GET_CHAR_AND_MODE - fetch one key and its mode code.

  Image addresses:
    sau2  0x00E724C4  KBD_$GET_CHAR_AND_MODE
    sau9  0x3C479EC0  KBD_$GET_CHAR_AND_MODE

  - The mode is mapped through kbd_$mode_table; the result is true when
    a key was there, false also when the line's lookup failed.
  - With `kbd_commands' the first call after KBD_$INIT or
    KBD_$CRASH_INIT sends the keyboard an 18-byte command (16#FF 16#12
    16#21 and zeros) before the fetch.

  Status stored:
    kbd_$get_desc's status: always
}

[section(procedure$, data$)]
function kbd_$get_char_and_mode(in line: pinteger; out char_out: char;
                                out mode_out: char; out status: status_$t):
  boolean;
var
%if kbd_commands %then
  cmd: static array[1..18] of char := [
    chr(16#FF), chr(16#12), chr(16#21), 15 of chr(0)];
%endif
  kbd: kbd_$desc_ptr_t;
  mode: integer;
begin
  kbd_$get_char_and_mode := false;
  kbd := kbd_$get_desc(line, status);
  if status.all <> status_$ok then
    return;
%if kbd_commands %then
  if not (kbd_$flag_cmd_sent in kbd^.flags) then begin
    kbd^.flags := kbd^.flags + [kbd_$flag_cmd_sent];
    kbd_$put_line(kbd^, 0, cmd, 18);
  end;
%endif
  kbd_$get_char_and_mode := kbd_$fetch_key(kbd^, char_out, mode);
  mode_out := kbd_$mode_table[mode];
end;
