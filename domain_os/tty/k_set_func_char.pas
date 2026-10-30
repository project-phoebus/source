{ TTY_$K_SET_FUNC_CHAR - bind a function slot of a line to a character,
  for a caller of the kernel interface.

  Image addresses:
    sau2  0x00E674D2  TTY_$K_SET_FUNC_CHAR

  - An enabled slot's old character becomes ordinary; unless the line is
    raw the default functions are bound again.
  - The slot check is in_range (ref p. 4-104: the type's bound, compared
    unsigned), then above 17.

  Status stored:
    tty_$i_get_desc's status: the line has a descriptor, or not
    status_$tty_invalid_function: func is beyond tty_$func_reserved_18
}

{ TODO(pascal) in_range on a run-time value: code inferred

  in_range of a run-time value is not a known form (no site known before
  this one), so its code is inferred, not checked. }

procedure tty_$k_set_func_char(in line: integer; in func: tty_$func_t;
                               in ch: char; out status: status_$t);
var
  tty: integer32;
  unused_8: integer32;                    { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  { the slot must be one the descriptor stores }
  if not in_range(func) or else
     (func > tty_$func_reserved_18) then begin
    status.all := status_$tty_invalid_function;
    return;
  end;

  { unbind the old character }
  if func in tty_$desc_ptr_t(tty)^.func_enabled then
    tty_$desc_ptr_t(tty)^.char_class[tty_$desc_ptr_t(tty)^.func_chars[func]] := tty_$class_normal;

  tty_$desc_ptr_t(tty)^.func_chars[func] := ch;

  if not tty_$desc_ptr_t(tty)^.raw_mode then
    tty_$i_set_dfl_funcs(tty_$desc_ptr_t(tty)^, true);
end;
