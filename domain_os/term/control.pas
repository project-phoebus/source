{ TERM_$CONTROL - set an attribute of a terminal line.

  Image addresses:
    sau2  0x00E66916  TERM_$CONTROL
    sau3  0x00E67880  TERM_$CONTROL
    sau4  0x0F87040A  TERM_$CONTROL
    sau9  0x3C46D6C2  TERM_$CONTROL

  - The option (0..36) picks a TTY_$K_ setter, the line's DTTE flag, the
    keyboard mode, or the serial parameters (SIO_$K_SET_PARAM,
    SIO_$K_TIMED_BREAK); the status is converted at the end.
  - Options 7 (a bad line), 18, 19 and 20 (an unknown value) return
    without the conversion.  The serial parameter block is never
    cleared: only the fields the mask names are read.

  Status stored:
    the setter's status, converted: a known option
    status_$term_invalid_option: an unknown option, or an unknown value
      of 18, 19 or 20
}

{ TODO(pascal) TERM_$CONTROL's frame has 20 bytes no object accounts for

  In the SAU2 image the objects addressed are params, mask, pgroup_ptr
  and the expression temporary; the register-held real_line, flow and
  bits take 8 bytes of slots (register-held locals keep their slots).
  That leaves 20 bytes no instruction reaches; they are the stand-ins
  unused_20, unused_30 and unused_34 below (the 8 bytes at -0x34 two
  longwords: they do not start at a multiple of 8 from A6, where an
  8-byte object would be placed).  A local per option or `with'
  temporaries are the leads. }

procedure term_$control(in line: integer; in option: integer;
                        in value: univ term_$value_t;
                        out status: status_$t);
var
  params: sio_$params_t;                  { 0x16 bytes }
  mask: sio_$flags_t;
  unused_20: integer32;                   { see the TODO }
  pgroup_ptr: ^uid_$t;
  real_line: pinteger;
  flow: term_$bits_t;
  bits: sio_$flags_t;
  unused_30: integer32;                   { see the TODO }
  unused_34: integer32;
begin
  case option of
    { the function characters }
    term_$opt_erase: begin
      tty_$k_set_func_char(line, tty_$func_erase, value.c, status);
    end;
    term_$opt_kill: begin
      tty_$k_set_func_char(line, tty_$func_kill, value.c, status);
    end;
    term_$opt_eofchr: begin
      tty_$k_set_func_char(line, tty_$func_eof, value.c, status);
    end;
    term_$opt_quitchr: begin
      tty_$k_set_func_char(line, tty_$func_quit, value.c, status);
    end;
    term_$opt_intchr: begin
      tty_$k_set_func_char(line, tty_$func_int, value.c, status);
    end;
    term_$opt_suspchr: begin
      tty_$k_set_func_char(line, tty_$func_susp, value.c, status);
    end;

    term_$opt_raw: begin
      tty_$k_flush_input(line, status);
      tty_$i_set_raw(line, value.b, status);
    end;

    { the flags }
    term_$opt_no_nl: begin
      tty_$k_set_output_flag(line, tty_$of_nl_to_crnl, not value.b,
                             status);
    end;
    term_$opt_raw_nl: begin
      tty_$k_set_output_flag(line, tty_$of_nl_to_crnl, true, status);
    end;
    term_$opt_no_echo: begin
      tty_$k_set_input_flag(line, tty_$if_echo, not value.b, status);
    end;

    term_$opt_host_sync: begin
      tty_$k_enable_func(line, tty_$func_stop, value.b, status);
      tty_$k_enable_func(line, tty_$func_start, value.b, status);
    end;

    term_$opt_input_sync: begin
      tty_$k_set_input_flag(line, tty_$if_ixoff, value.b, status);
    end;

    { the signal functions, and this process's group }
    term_$opt_quit_enable: begin
      tty_$k_enable_func(line, tty_$func_quit, value.b, status);
      tty_$k_set_pgroup(line, proc2_$uid[proc1_$as_id], status);
    end;
    term_$opt_int_enable: begin
      tty_$k_enable_func(line, tty_$func_int, value.b, status);
      tty_$k_set_pgroup(line, proc2_$uid[proc1_$as_id], status);
    end;
    term_$opt_susp_enable: begin
      tty_$k_enable_func(line, tty_$func_susp, value.b, status);
      tty_$k_set_pgroup(line, proc2_$uid[proc1_$as_id], status);
    end;
    term_$opt_pgroup: begin
      pgroup_ptr := addr(value.uid);
      tty_$k_set_pgroup(line, pgroup_ptr^, status);
    end;

    term_$opt_flush_in: begin
      tty_$k_flush_input(line, status);
    end;
    term_$opt_flush_out: begin
      tty_$k_flush_output(line, status);
    end;
    term_$opt_drain_out: begin
      tty_$k_drain_output(line, status);
    end;

    { the line's DTTE flag }
    term_$opt_line_flag: begin
      real_line := term_$get_real_line(line, status);
      if status.all <> status_$ok then
        return;
      dtte[real_line].flags := value.b;
    end;

    term_$opt_kbd_mode: begin
      kbd_$set_kbd_mode(line, chr(value.w), status);
    end;

    { the serial line's parameters }
    term_$opt_hup_close: begin
      if value.b then
        params.flags2 := params.flags2 + [0]
      else
        params.flags2 := params.flags2 - [0];
      mask := [9];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_cts_enable: begin
      if value.b then
        params.flags2 := params.flags2 + [1]
      else
        params.flags2 := params.flags2 - [1];
      mask := [10];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_dcd_enable: begin
      if value.b then
        params.flags2 := params.flags2 + [2]
      else
        params.flags2 := params.flags2 - [2];
      tty_$k_set_pgroup(line, proc2_$uid[proc1_$as_id], status);
      mask := [11];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_speed: begin
      params.baud_rate.rx := value.w;
      params.baud_rate.tx := value.w;
      mask := [0];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_speed_force: begin
      params.baud_rate.rx := value.w;
      params.baud_rate.tx := value.w;
      mask := [1];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_rts: begin
      if value.b then
        params.flags1 := params.flags1 + [0]
      else
        params.flags1 := params.flags1 - [0];
      mask := [5];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_dtr: begin
      if value.b then
        params.flags1 := params.flags1 + [3]
      else
        params.flags1 := params.flags1 - [3];
      mask := [6];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_parity: begin
      case value.w of
        sio_$even_parity: begin
          params.parity := sio_$even_parity;
        end;
        sio_$odd_parity: begin
          params.parity := sio_$odd_parity;
        end;
        sio_$no_parity: begin
          params.parity := sio_$no_parity;
        end;
        otherwise begin
          status.all := status_$term_invalid_option;
          return;
        end;
      end;
      mask := [2];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_bits_per_char: begin
      case value.w of
        sio_$5bpc: begin
          params.char_size := sio_$5bpc;
        end;
        sio_$6bpc: begin
          params.char_size := sio_$6bpc;
        end;
        sio_$7bpc: begin
          params.char_size := sio_$7bpc;
        end;
        sio_$8bpc: begin
          params.char_size := sio_$8bpc;
        end;
        otherwise begin
          status.all := status_$term_invalid_option;
          return;
        end;
      end;
      mask := [4];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_stop_bits: begin
      case value.w of
        sio_$stop_1: begin
          params.stop_bits := sio_$stop_1;
        end;
        sio_$stop_1_point_5: begin
          params.stop_bits := sio_$stop_1_point_5;
        end;
        sio_$stop_2: begin
          params.stop_bits := sio_$stop_2;
        end;
        otherwise begin
          status.all := status_$term_invalid_option;
          return;
        end;
      end;
      mask := [3];
      sio_$k_set_param(line, params, mask, status);
    end;
    term_$opt_err_enable: begin
      bits := [];
      flow := value.bits;
      if 0 in flow then
        bits := [0];
      if 1 in flow then
        bits := bits + [1];
      if 2 in flow then
        bits := bits + [3];
      if 3 in flow then
        bits := bits + [4];
      params.break_mask := bits;
      mask := [13];
      sio_$k_set_param(line, params, mask, status);
    end;

    term_$opt_send_break: begin
      sio_$k_timed_break(line, value.w, status);
    end;

    { the empty arms: the table sends them to the join }
    term_$opt_ignored_9, term_$opt_bp_enable: { empty };

    otherwise begin
      status.all := status_$term_invalid_option;
    end;
  end;

  term_$status_convert(status);
end;
