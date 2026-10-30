{ TTY_$K_PUT - write characters to a line's output, for a caller of the
  kernel interface.

  Image addresses:
    sau2  0x00E67BB2  TTY_$K_PUT

  - Under the TTY lock.  options member 1 asks only whether there is
    room (the free space less 64 bytes); member 0 makes the put
    conditional.  count is set to the number written.
  - The characters go to tty_$i_put_output, at most 64 at a time; while
    the output is busy an unconditional put waits for it, with the lock
    released, or for a quit.
  - A conditional put on busy output sets status_$tty_would_block and
    goes round again with the lock held; the status stays when all is
    written.

  Status stored:
    tty_$i_get_desc's status: all was written, or the line has no
      descriptor
    status_$tty_invalid_output_buffer_length: count is above 32767
    status_$tty_invalid_option: member 1 without member 0
    status_$tty_would_block: member 1, and less room than count; or a
      conditional put that met busy output
    status_$ok: member 1, and room for count
    the status handler's status: a pending callback error
    status_$tty_input_buffer_overrun: a pending overrun
    status_$tty_quit_while_waiting_for_input: a quit (noted as seen)
}

procedure tty_$k_put(in line: integer; in options: tty_$flags16_t;
                     in buffer: univ tty_$chars_t;
                     in out count: tty_$uword_t; out status: status_$t);
var
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  tty: integer32;
  chars_written: tty_$uword_t;
  avail_space: integer;
  result: integer;
  unused_20: integer32;                   { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  if integer(count) < 0 then begin
    status.all := status_$tty_invalid_output_buffer_length;
    return;
  end;

  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  chars_written := 0;
  tty_$i_lock(tty_$desc_ptr_t(tty)^);

  if 1 in options then begin
    { the room in the output buffer, less 64 }
    avail_space := tty_$desc_ptr_t(tty)^.output.head - tty_$desc_ptr_t(tty)^.output.tail - 1;
    if avail_space < 0 then
      avail_space := avail_space + tty_$buf_size;
    avail_space := avail_space - 64;
    tty_$i_unlock(tty_$desc_ptr_t(tty)^);

    { only for a conditional put }
    if not (0 in options) then begin
      status.all := status_$tty_invalid_option;
      return;
    end;
    if avail_space < count then begin
      status.all := status_$tty_would_block;
      return;
    end;
    status.all := status_$ok;
    return;
  end;

  while chars_written < count do begin
    { as many as the output buffer takes }
    chars_written := chars_written
                     + tty_$i_put_output(tty_$desc_ptr_t(tty)^, buffer[chars_written + 1],
                                         count - chars_written, 64);

    { report and clear the pending errors }
    if tty_$desc_ptr_t(tty)^.pending_signal <> [] then begin
      if tty_$err_callback in tty_$desc_ptr_t(tty)^.pending_signal then
        status.all := tty_$desc_ptr_t(tty)^.status_handler^(tty_$desc_ptr_t(tty)^.line_id, true)
      else if tty_$err_overflow in tty_$desc_ptr_t(tty)^.pending_signal then
        status.all := status_$tty_input_buffer_overrun;
      tty_$desc_ptr_t(tty)^.pending_signal := [];
      if status.all <> status_$ok then
        exit;
    end;

    if chars_written = count then
      exit;

    { the line's output eventcount }
    ecs[1] := tty_$desc_ptr_t(tty)^.output_ec;
    vals[1] := ecs[1]^.value + 1;

    { the quit eventcount of this address space }
    ecs[2] := addr(fim_$quit_ec[proc1_$as_id]);
    vals[2] := fim_$quit_value[proc1_$as_id] + 1;

    { the output is busy: wait for room, unless the put is conditional }
    if tty_$desc_ptr_t(tty)^.state_flags * [tty_$st_output_wait, tty_$st_input_wait,
                           tty_$st_output_stopped] <> [] then begin
      if 0 in options then
        { the loop goes round again }
        status.all := status_$tty_would_block
      else begin
        tty_$i_unlock(tty_$desc_ptr_t(tty)^);
        result := ec_$waitn(ecs, vals, 2);
        tty_$i_lock(tty_$desc_ptr_t(tty)^);

        if result = 2 then begin
          { a quit; note it as seen }
          status.all := status_$tty_quit_while_waiting_for_input;
          fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
          exit;
        end;
      end;
    end;
  end;

  count := chars_written;
  tty_$i_unlock(tty_$desc_ptr_t(tty)^);
end;
