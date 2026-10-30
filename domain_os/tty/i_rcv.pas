{ TTY_$I_RCV - take one received character: classify it and act on its
  class.

  Image addresses:
    sau2  0x00E1B92A  TTY_$I_RCV
    sau9  0x3C41E496  TTY_$I_RCV

  - A full input buffer notes an overrun.  The character is stripped to
    7 bits under tty_$if_strip; a 255 is stored once more under
    tty_$if_flag_errs.
  - After an end of file (tty_$st_eof_pend) the next character is
    normal.
  - The class's arm acts on it; the CR and CRLF classes may call the
    routine again with CR or LF.  The crash character stops the system
    when the MMU is not in normal mode.
  - A normal character raises the flow control at 192 buffered bytes,
    and in a break mode commits the input at once.

  Status stored: none.
}

{ TODO(pascal) the tab arm and the normal arm compare tail in different
  registers

  In the SAU2 image the tab arm compares tty.input.tail in next_tail's
  register (dead in that arm), where the normal arm, with next_tail
  live, uses a scratch register.  Which register the allocator chose for
  a value in a `case' arm is not known. }

[section(wired_proc, wired_data)]
procedure tty_$i_rcv(var tty: tty_$desc_t; ch: char);
  options(val_param);
label
  normal_char;
var
  state_flags: tty_$flags16_t;
  next_tail: tty_$buf_pos_t;
  char_class: integer;
  buffer_count: integer;
  pos: tty_$buf_pos_t;
begin
  { the producer position after this character }
  if tty.input.tail = tty_$buf_size then
    next_tail := 1
  else
    next_tail := tty.input.tail + 1;

  { the buffer is full: note the overrun }
  if next_tail = tty.input.head then
    tty.pending_signal := tty.pending_signal + [tty_$err_overflow];

  { 7 bits under member 5 (tty_$if_strip); else a 255 is stored once
    more under member 12 (tty_$if_flag_errs) }
  if tty_$if_strip in tty.input_flags then
    ch := chr(ord(ch) & 16#7F)
  else if (ch = chr(255)) and then (tty_$if_flag_errs in tty.input_flags) then
    tty_$i_buf_insert(ch, tty.input);

  { save the state flags, drop members 5..7 }
  state_flags := tty.state_flags;
  tty.state_flags :=
    tty.state_flags - [tty_$st_output_flush, tty_$st_eof_pend, 7];

  { the character's class }
  if tty_$st_eof_pend in state_flags then
    char_class := tty_$class_normal
  else
    char_class := tty.char_class[ch];

  { the dispatch, a jump table }
  case char_class of
    tty_$class_sigint: begin
      tty_$i_echo_char(tty, ch);
      tty_$i_flush_input(tty);
      tty_$i_signal(tty, tty_$sig_int);
    end;

    tty_$class_sigquit: begin
      tty_$i_echo_char(tty, ch);
      tty_$i_flush_input(tty);
      tty_$i_signal(tty, tty_$sig_quit);
    end;

    tty_$class_sigtstp: begin
      tty_$i_echo_char(tty, ch);
      tty_$i_flush_input(tty);
      tty_$i_signal(tty, tty_$sig_tstp);
    end;

    { stop the output }
    tty_$class_xoff: begin
      tty.state_flags := tty.state_flags + [tty_$st_output_stopped];
      if tty.xon_xoff_handler <> nil then
        tty.xon_xoff_handler^(tty.line_id, true);
    end;

    { start it again }
    tty_$class_xon: begin
      tty.state_flags := tty.state_flags - [tty_$st_output_stopped];
      if tty.xon_xoff_handler <> nil then
        tty.xon_xoff_handler^(tty.line_id, false);
      tty_$i_advance_ec(tty.output_ec^);
    end;

    { the crash character }
    tty_$class_crash: begin
      if not mmu_$normal_mode then
        crash_system(16#000B0008);  { manual stop: type G<ret>G *+2<ret>
                                      to continue }
    end;

    { flush the output once; echo the next ones }
    tty_$class_flushout: begin
      if not (tty_$st_output_flush in state_flags) then begin
        tty_$i_flush_output(tty);
        tty.state_flags := tty.state_flags + [tty_$st_output_flush];
      end
      else if tty_$if_echo in tty.input_flags then
        tty_$i_echo_char(tty, ch);
    end;

    tty_$class_del: begin
      tty.state_flags := tty.state_flags + (state_flags * [7]);
      tty_$i_delete_char(tty);
    end;

    tty_$class_werase: begin
      tty.state_flags := tty.state_flags + (state_flags * [7]);
      tty_$i_word_erase(tty);
    end;

    tty_$class_kill: begin
      tty.state_flags := tty.state_flags + (state_flags * [7]);
      tty_$i_kill_line(tty);
    end;

    { echo, back over the echo, commit the line }
    tty_$class_discard: begin
      tty_$i_echo_char(tty, ch);
      tty_$i_xmit_char(tty, chr(8));
      tty_$i_xmit_char(tty, chr(8));
      tty_$i_break_char(tty, ch);
    end;

    tty_$class_break, tty_$class_nl: begin
      tty_$i_break_char(tty, ch);
    end;

    { flag it; echo it and back over the echo }
    tty_$class_eof: begin
      tty.state_flags := tty.state_flags + [tty_$st_eof_pend];
      if tty_$if_echo in tty.input_flags then begin
        tty_$i_echo_char(tty, ch);
        tty_$i_xmit_char(tty, chr(8));
        tty_$i_xmit_char(tty, chr(8));
      end;
    end;

    { stored and echoed as it is }
    tty_$class_tab: begin
      if tty.input.tail = tty.input_head then
        tty.saved_input_flags := tty.column;
      tty_$i_buf_insert(ch, tty.input);
      if tty_$if_echo in tty.input_flags then
        tty_$i_xmit_char(tty, ch);
    end;

    { under member 4 (tty_$if_nl_to_cr), taken as CR unless member 3
      (tty_$if_cr_to_nl); else a break character }
    tty_$class_cr: begin
      if tty_$if_nl_to_cr in tty.input_flags then begin
        if not (tty_$if_cr_to_nl in tty.input_flags) then
          tty_$i_rcv(tty, chr(13));
      end
      else
        tty_$i_break_char(tty, ch);
    end;

    { ignored under member 9 (tty_$if_ignore_cr); under member 3
      (tty_$if_cr_to_nl) taken as LF unless member 4 (tty_$if_nl_to_cr);
      else a normal character }
    tty_$class_crlf: begin
      if not (tty_$if_ignore_cr in tty.input_flags) then
        if tty_$if_cr_to_nl in tty.input_flags then begin
          if not (tty_$if_nl_to_cr in tty.input_flags) then
            tty_$i_rcv(tty, chr(10));
        end
        else
          goto normal_char;
    end;

    { echo it, a new line, and the uncommitted input again }
    tty_$class_reprint: begin
      if tty_$if_echo in tty.input_flags then begin
        tty_$i_echo_char(tty, ch);
        tty_$i_newline(tty);
        pos := tty.input_head;
        while pos <> tty.input.tail do begin
          tty_$i_echo_char(tty, tty.input.data[pos]);
          if pos = tty_$buf_size then
            pos := 1
          else
            pos := pos + 1;
        end;
      end;
    end;

    { a normal character }
    tty_$class_normal: normal_char: begin
      { store it unless the buffer overran }
      if not (tty_$err_overflow in tty.pending_signal) then begin
        if tty.input.tail = tty.input_head then
          tty.saved_input_flags := tty.column;
        tty.input.data[tty.input.tail] := ch;
        tty.input.tail := next_tail;

        { hold the sender off when 0xC0 bytes wait }
        buffer_count := tty.input.tail - tty.input.head;
        if buffer_count < 0 then
          buffer_count := buffer_count + tty_$buf_size;
        if (buffer_count >= 192)
           and then (tty.flow_ctrl_handler <> nil) then
          tty.flow_ctrl_handler^(tty.line_id, true,
                                 tty_$if_ixoff in tty.input_flags);

        if 7 in state_flags then
          tty_$i_xmit_char(tty, '/');
        if tty_$if_echo in tty.input_flags then
          tty_$i_echo_char(tty, ch);
      end;

      { in a break mode the character commits the line at once }
      if tty.break_mode.break_type <> tty_$break_on_eol then begin
        tty.input_head := next_tail;
        tty_$i_advance_ec(tty.input_ec^);
        if tty_$st_sig_pend in tty.state_flags then
          tty_$i_signal(tty, tty_$sig_winch);
        if tty.break_mode.break_type = tty_$break_on_timer_or_count then
          time_$clock(tty.last_input_clock);
      end;
    end;
  end;
end;
