{ TTY_$I_FLUSH_INPUT - discard all buffered input.

  Image addresses:
    sau2  0x00E1B7B0  TTY_$I_FLUSH_INPUT

  - A writer waiting for input is woken; the line's flow-control
    handler, when it has one, is told the flow is off.
  - saved_input_flags gets the column: it is the column at which the
    uncommitted input starts (tty_$i_calc_column's start), not a copy
    of flags.  The field keeps its name.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_flush_input(in out tty: tty_$desc_t);
begin
  { empty the input buffer }
  tty.input.tail := tty.input.head;
  tty.input_head := tty.input.tail;
  tty.saved_input_flags := tty.column;

  { wake a writer waiting for input }
  if tty_$st_input_wait in tty.state_flags then begin
    tty.state_flags := tty.state_flags - [tty_$st_input_wait];
    tty_$i_advance_ec(tty.output_ec^);
  end;

  { tell the driver's flow control }
  if tty.flow_ctrl_handler <> nil then
    tty.flow_ctrl_handler^(tty.line_id, false,
                           tty_$if_ixoff in tty.input_flags);
end;
