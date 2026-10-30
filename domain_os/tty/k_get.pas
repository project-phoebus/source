{ TTY_$K_GET - read characters from a line's input, for a caller of the
  kernel interface.

  Image addresses:
    sau2  0x00E1C3D2  TTY_$K_GET

  - Under the TTY lock.  options member 0 makes the get conditional,
    member 1 leaves the bytes in the input buffer.
  - In line mode (tty_$break_on_eol) only committed input is read, up
    to an end-of-file or suspend character (which signals the process
    group), or after a CR or NL.
  - In the other modes what there is, done once the break mode's count
    is read.
  - tty_$i_wait waits for more.  A pending error is reported at the end
    and the pending errors cleared.  The result is the number read.

  Status stored:
    tty_$i_get_desc's status: characters were read, or the line has no
      descriptor
    status_$tty_eof: an end-of-file character came first
    status_$tty_buffer_full: count characters were read without an end
    tty_$i_wait's status: a conditional get found nothing, or a quit
    the status handler's status: a pending callback error
    status_$tty_input_buffer_overrun: a pending overrun
}

[section(wired_proc, wired_data)]
function tty_$k_get(in line: integer; in options: tty_$flags16_t;
                    out buffer: univ tty_$chars_t; in count: tty_$uword_t;
                    out status: status_$t): tty_$uword_t;
type
  char_ptr_t = ^char;
var
  buf_ptr: char_ptr_t;
  tty: integer32;
  token: integer;
  chars_read: tty_$uword_t;
  read_pos: tty_$buf_pos_t;
  break_mode_flag: boolean;
  clear_flag: boolean;
  ch: char;
  char_class: integer;
  wait_flag: boolean;
  buffer_count: integer;
  eof_flag: boolean;
  done: boolean;
  unused_20: array[1..2] of integer;      { stand-in, see
                                            TTY_$K_FLUSH_INPUT's TODO }
begin
  chars_read := 0;
  tty := tty_$i_get_desc(line, status);
  if status.all = status_$ok then begin
    tty_$i_lock(tty_$desc_ptr_t(tty)^);

    { the options }
    wait_flag := 0 in options;
    clear_flag := 1 in options;
    done := false;
    eof_flag := false;

    repeat
      break_mode_flag := tty_$desc_ptr_t(tty)^.break_mode.break_type = tty_$break_on_eol;
      buf_ptr := addr(buffer[chars_read + 1]);
      read_pos := tty_$desc_ptr_t(tty)^.input.head;

      if break_mode_flag then begin
        { committed input, up to a terminator }
        if read_pos <> tty_$desc_ptr_t(tty)^.input_head then
          while (read_pos <> tty_$desc_ptr_t(tty)^.input.tail)
                and then (chars_read < count) do begin
            ch := tty_$desc_ptr_t(tty)^.input.data[read_pos];
            if not clear_flag then
              tty_$desc_ptr_t(tty)^.input.data[read_pos] := chr(0);
            if read_pos = tty_$buf_size then
              read_pos := 1
            else
              read_pos := read_pos + 1;
            char_class := tty_$desc_ptr_t(tty)^.char_class[ch];

            { end of file }
            if char_class = tty_$class_discard then begin
              if chars_read = 0 then
                status.all := status_$tty_eof;
              done := true;
              exit;
            end;

            { suspend }
            if char_class = tty_$class_break then begin
              tty_$i_signal(tty_$desc_ptr_t(tty)^, tty_$sig_tstp);
              exit;
            end;

            { store it; a CR or NL ends the line }
            buf_ptr^ := ch;
            buf_ptr := char_ptr_t(integer32(buf_ptr) + 1);
            chars_read := chars_read + 1;
            if (char_class = tty_$class_cr)
               or else (char_class = tty_$class_nl) then begin
              done := true;
              exit;
            end;
          end;
      end
      else begin
        { what there is, up to the count }
        while (read_pos <> tty_$desc_ptr_t(tty)^.input.tail)
              and then (chars_read < count) do begin
          buf_ptr^ := tty_$desc_ptr_t(tty)^.input.data[read_pos];
          if not clear_flag then
            tty_$desc_ptr_t(tty)^.input.data[read_pos] := chr(0);
          buf_ptr := char_ptr_t(integer32(buf_ptr) + 1);
          chars_read := chars_read + 1;
          if read_pos = tty_$buf_size then
            read_pos := 1
          else
            read_pos := read_pos + 1;
        end;
        done := chars_read = count;
      end;

      { consume what was read; release the flow control when the buffered
        input falls below 64 bytes }
      if not clear_flag then begin
        buffer_count := tty_$desc_ptr_t(tty)^.input.tail - tty_$desc_ptr_t(tty)^.input.head;
        if buffer_count < 0 then
          buffer_count := buffer_count + tty_$buf_size;
        if ((buffer_count - chars_read) < 64)
           and then (buffer_count >= 64)
           and then (tty_$desc_ptr_t(tty)^.flow_ctrl_handler <> nil) then begin
          token := ml_$spin_lock(tty_$spin_lock);
          tty_$desc_ptr_t(tty)^.flow_ctrl_handler^(tty_$desc_ptr_t(tty)^.line_id, false,
                                  tty_$if_ixoff in tty_$desc_ptr_t(tty)^.input_flags);
          ml_$spin_unlock(tty_$spin_lock, token);
        end;
        tty_$desc_ptr_t(tty)^.input.head := read_pos;
      end;

      if done then
        exit;

      { end of file, a full buffer, enough characters, or wait for more }
      if eof_flag then
        done := true
      else if chars_read >= count then
        status.all := status_$tty_buffer_full
      else if (not break_mode_flag)
              and then (chars_read >= tty_$desc_ptr_t(tty)^.break_mode.count) then
        done := true
      else
        tty_$i_wait(tty_$desc_ptr_t(tty)^, wait_flag, eof_flag, chars_read, status);

      if status.all <> status_$ok then
        done := true;
    until done;

    { report and clear the pending errors }
    if tty_$desc_ptr_t(tty)^.pending_signal <> [] then begin
      if tty_$err_callback in tty_$desc_ptr_t(tty)^.pending_signal then
        status.all := tty_$desc_ptr_t(tty)^.status_handler^(tty_$desc_ptr_t(tty)^.line_id, true)
      else if tty_$err_overflow in tty_$desc_ptr_t(tty)^.pending_signal then
        status.all := status_$tty_input_buffer_overrun;
      tty_$desc_ptr_t(tty)^.pending_signal := [];
    end;

    tty_$i_unlock(tty_$desc_ptr_t(tty)^);
  end;

  tty_$k_get := chars_read;
end;
