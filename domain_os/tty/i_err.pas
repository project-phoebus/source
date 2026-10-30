{ TTY_$I_ERR - take a receive error: store a marker in the input, or flag
  the error and wake the waiters.

  Image addresses:
    sau2  0x00E1BCFC  tty_$i_store_parity (nested)
    sau2  0x00E1BE08  TTY_$I_ERR

  - The status handler's error is stored in the input: under
    tty_$if_queue_brk a framing error with no character or 0x36000B,
    under tty_$if_queue_par a framing or parity error.
  - Otherwise tty_$err_callback is added to pending_signal and the input
    and output eventcounts advanced.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_err(var tty: tty_$desc_t; ch: char);
  options(val_param);
var
  err_status: status_$t;

  { tty_$i_store_parity - store the error in the input: 255, 0 and the
    character under input_flags member 12 (tty_$if_flag_errs), otherwise
    a 0.  In a break mode other than tty_$break_on_eol, commit the input
    once the break mode's count of bytes wait (and signal a pending
    signal), or else, in mode 3 (tty_$break_on_timer_or_count), note the
    time. }
  procedure tty_$i_store_parity;
  var
    count: integer;
  begin
    { the marker }
    if tty_$if_flag_errs in tty.input_flags then begin
      tty_$i_buf_insert(chr(255), tty.input);
      tty_$i_buf_insert(chr(0), tty.input);
      tty_$i_buf_insert(ch, tty.input);
    end
    else
      tty_$i_buf_insert(chr(0), tty.input);

    { wake the reader in a break mode }
    if tty.break_mode.break_type <> tty_$break_on_eol then begin
      count := tty.input.tail - tty.input.head;
      if count < 0 then
        count := count + tty_$buf_size;
      if count >= tty.break_mode.count then begin
        if tty.input.tail = tty_$buf_size then
          tty.input_head := 1
        else
          tty.input_head := tty.input.tail + 1;
        tty_$i_advance_ec(tty.input_ec^);
        if tty_$st_sig_pend in tty.state_flags then
          tty_$i_signal(tty, tty_$sig_winch);
      end
      else if tty.break_mode.break_type = tty_$break_on_timer_or_count then
        time_$clock(tty.last_input_clock);
    end;
  end;

begin
  { what went wrong }
  err_status.all := tty.status_handler^(tty.line_id, true);

  { store it or flag it.  One `if' chain; the store call and the three
    flag statements are written in each part that takes them, and the
    compiler merged the copies into the last ones (see the header) }
  if (ord(ch) = 0) and then (err_status.all = status_$sio_framing_error)
     then begin
    if tty_$if_queue_brk in tty.input_flags then
      tty_$i_store_parity
    else begin
      tty.pending_signal := tty.pending_signal + [tty_$err_callback];
      tty_$i_advance_ec(tty.input_ec^);
      tty_$i_advance_ec(tty.output_ec^);
    end;
  end
  else if (err_status.all = status_$sio_code_0b)
          and (tty_$if_queue_brk in tty.input_flags) then
    tty_$i_store_parity
  else if not (tty_$if_queue_par in tty.input_flags) then begin
    tty.pending_signal := tty.pending_signal + [tty_$err_callback];
    tty_$i_advance_ec(tty.input_ec^);
    tty_$i_advance_ec(tty.output_ec^);
  end
  else if (err_status.all = status_$sio_framing_error)
          or else (err_status.all = status_$sio_parity_error) then
    tty_$i_store_parity
  else begin
    { flag it and wake the waiters }
    tty.pending_signal := tty.pending_signal + [tty_$err_callback];
    tty_$i_advance_ec(tty.input_ec^);
    tty_$i_advance_ec(tty.output_ec^);
  end;
end;
