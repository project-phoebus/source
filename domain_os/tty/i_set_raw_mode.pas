{ tty_$i_set_raw_mode - switch a line into or out of raw mode.

  Image addresses:
    sau2  0x00E1BF70  tty_$i_set_raw_mode (module-local)

  - Entering raw mode saves and removes input flags [2..5] and output
    flags [0..4], disables the default functions and the crash
    character, and sets break mode tty_$break_on_count with count 1.
  - Under the spin lock it then clears the wait and stopped flags,
    advancing the output eventcount if any was set.
  - Leaving it puts the saved flags back, sets tty_$break_on_eol and
    enables the default functions and the crash character again.  A
    line already in the mode asked for is left alone.
  - The two masks are this routine's statics, WIRED_DATA +0x20 (output)
    and +0x24 (input), declared in the order of their offsets.

  Status stored: none.
}

{ TODO(pascal) leaving raw mode uses two registers, entering it one

  In the SAU2 image, leaving raw mode puts the two unions through two
  data registers and indexes char_class through a third, where entering
  it uses one register for all of these.  No local or temporary of the
  source explains a second register (the frame has no room for one);
  the allocator's rule is not known. }

[section(wired_proc, wired_data)]
procedure tty_$i_set_raw_mode(in out tty: tty_$desc_t; raw: boolean); internal;
var
  { WIRED_DATA +0x20 }
  raw_output_mask: static tty_$output_flag_set_t :=
    [tty_$of_cr_to_crnl..tty_$of_xtabs];   { [0..4] }
  { WIRED_DATA +0x24 }
  raw_input_mask: static tty_$input_flag_set_t :=
    [tty_$if_ixany..tty_$if_strip];         { [2..5] }
  token: integer;
begin
  if raw then begin
    { enter raw mode }
    if tty.raw_mode then
      return;
    tty.raw_saved_input_flags := tty.input_flags * raw_input_mask;
    tty.input_flags := tty.input_flags - raw_input_mask;
    tty.raw_saved_output_flags := tty.output_flags * raw_output_mask;
    tty.output_flags := tty.output_flags - raw_output_mask;
    tty_$i_set_dfl_funcs(tty, false);
    if tty.crash_char <> chr(0) then
      tty.char_class[tty.crash_char] := tty_$class_normal;
    tty.break_mode.break_type := tty_$break_on_count;
    tty.break_mode.count := 1;
    token := ml_$spin_lock(tty_$spin_lock);
    if tty.state_flags * [tty_$st_output_wait, tty_$st_input_wait,
                          tty_$st_output_stopped] <> [] then begin
      tty.state_flags := tty.state_flags
                         - [tty_$st_output_wait, tty_$st_input_wait,
                            tty_$st_output_stopped];
      tty_$i_advance_ec(tty.output_ec^);
    end;
    ml_$spin_unlock(tty_$spin_lock, token);
    tty.raw_mode := true;
  end
  else begin
    { leave raw mode }
    if not tty.raw_mode then
      return;
    tty.input_flags := tty.input_flags + tty.raw_saved_input_flags;
    tty.output_flags := tty.output_flags + tty.raw_saved_output_flags;
    tty.raw_saved_input_flags := [];
    tty.raw_saved_output_flags := [];
    tty.break_mode.break_type := tty_$break_on_eol;
    tty_$i_set_dfl_funcs(tty, true);
    if tty.crash_char <> chr(0) then
      tty.char_class[tty.crash_char] := tty_$class_crash;
    tty.raw_mode := false;
  end;
end;
