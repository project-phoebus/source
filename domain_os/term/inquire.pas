{ TERM_$INQUIRE - report an attribute of a terminal line.

  Image addresses:
    sau2  0x00E66D90  TERM_$INQUIRE
    sau3  0x00E67CFC  TERM_$INQUIRE
    sau4  0x0F870884  TERM_$INQUIRE

  - The option (0..32) picks a TTY_$K_ inquiry, the line's DTTE flag, or
    the serial parameters (SIO_$K_INQ_PARAM); the status is converted at
    the end, except for option 7 on a bad line.
  - Option 21 sets only bits 0..3 of the value.
  - Option 18 has no `otherwise'; another parity leaves the value as it
    was.

  Status stored:
    the inquiry's status, converted: a known option
    status_$term_invalid_option: an unknown option
}

{ TODO(pascal) TERM_$INQUIRE's frame has 18 bytes no object accounts for

  In the SAU2 image the objects addressed are params, pgroup, oflags,
  iflags, enabled, pgroup_ptr and flow (a word); real_line, held in a
  register, keeps a slot.  18 bytes are reached by no instruction: the
  stand-ins unused_32 and unused_44 below.  flow below a gap suggests an
  object of 8 bytes or more above it (an 8-byte alignment), which no
  instruction shows. }

procedure term_$inquire(in line: integer; in option: integer;
                        out value: univ term_$value_t;
                        out status: status_$t);
var
  params: sio_$params_t;                  { 0x16 bytes }
  pgroup: uid_$t;
  oflags: tty_$output_flag_set_t;
  iflags: tty_$input_flag_set_t;
  enabled: tty_$func_set_t;
  pgroup_ptr: ^uid_$t;
  real_line: pinteger;
  unused_32: array[1..12] of char;        { see the TODO }
  flow: term_$bits_t;
  unused_44: integer;                     { see the TODO }
begin
  case option of
    { the function characters }
    term_$opt_erase: begin
      tty_$k_inq_func_char(line, tty_$func_erase, value.c, status);
    end;
    term_$opt_kill: begin
      tty_$k_inq_func_char(line, tty_$func_kill, value.c, status);
    end;
    term_$opt_eofchr: begin
      tty_$k_inq_func_char(line, tty_$func_eof, value.c, status);
    end;
    term_$opt_quitchr: begin
      tty_$k_inq_func_char(line, tty_$func_quit, value.c, status);
    end;
    term_$opt_intchr: begin
      tty_$k_inq_func_char(line, tty_$func_int, value.c, status);
    end;
    term_$opt_suspchr: begin
      tty_$k_inq_func_char(line, tty_$func_susp, value.c, status);
    end;

    term_$opt_no_nl, term_$opt_raw_nl: begin
      tty_$k_inq_output_flags(line, oflags, status);
      value.b := tty_$of_nl_to_crnl in oflags;
    end;

    term_$opt_raw: begin
      tty_$i_inq_raw(line, value.b, status);
    end;

    term_$opt_no_echo: begin
      tty_$k_inq_input_flags(line, iflags, status);
      value.b := not (tty_$if_echo in iflags);
    end;

    { the line's DTTE flag }
    term_$opt_line_flag: begin
      real_line := term_$get_real_line(line, status);
      if status.all <> status_$ok then
        return;
      value.b := dtte[real_line].flags;
    end;

    { the flow control characters }
    term_$opt_host_sync: begin
      tty_$k_inq_func_enabled(line, enabled, status);
      value.b := (tty_$func_stop in enabled) and (tty_$func_start in enabled);
    end;

    term_$opt_input_sync: begin
      tty_$k_inq_input_flags(line, iflags, status);
      value.b := tty_$if_ixoff in iflags;
    end;

    term_$opt_quit_enable: begin
      tty_$k_inq_func_enabled(line, enabled, status);
      value.b := tty_$func_quit in enabled;
    end;
    term_$opt_int_enable: begin
      tty_$k_inq_func_enabled(line, enabled, status);
      value.b := tty_$func_int in enabled;
    end;
    term_$opt_susp_enable: begin
      tty_$k_inq_func_enabled(line, enabled, status);
      value.b := tty_$func_susp in enabled;
    end;

    term_$opt_pgroup: begin
      tty_$k_inq_pgroup(line, pgroup, status);
      pgroup_ptr := addr(value.uid);
      pgroup_ptr^ := pgroup;
    end;

    term_$opt_bp_enable: begin
      value.b := false;
    end;

    { the serial line's parameters }
    term_$opt_speed, term_$opt_speed_force: begin
      sio_$k_inq_param(line, params, [0], status);
      value.w := params.baud_rate.rx;
    end;
    term_$opt_bits_per_char: begin
      sio_$k_inq_param(line, params, [4], status);
      value.w := params.char_size;
    end;
    term_$opt_stop_bits: begin
      sio_$k_inq_param(line, params, [3], status);
      value.w := params.stop_bits;
    end;

    term_$opt_rts: begin
      sio_$k_inq_param(line, params, [5], status);
      value.b := 0 in params.flags1;
    end;
    term_$opt_dtr: begin
      sio_$k_inq_param(line, params, [6], status);
      value.b := 3 in params.flags1;
    end;
    term_$opt_cts: begin
      sio_$k_inq_param(line, params, [8], status);
      value.b := 1 in params.flags1;
    end;
    term_$opt_dcd: begin
      sio_$k_inq_param(line, params, [7], status);
      value.b := 2 in params.flags1;
    end;
    term_$opt_dcd_enable: begin
      sio_$k_inq_param(line, params, [11], status);
      value.b := 2 in params.flags2;
    end;
    term_$opt_cts_enable: begin
      sio_$k_inq_param(line, params, [10], status);
      value.b := 1 in params.flags2;
    end;
    term_$opt_hup_close: begin
      sio_$k_inq_param(line, params, [9], status);
      value.b := 0 in params.flags2;
    end;

    term_$opt_parity: begin
      sio_$k_inq_param(line, params, [2], status);
      case params.parity of
        sio_$even_parity: value.w := sio_$even_parity;
        sio_$odd_parity: value.w := sio_$odd_parity;
        sio_$no_parity: value.w := sio_$no_parity;
      end;
    end;
    term_$opt_ignored_9: begin
      value.w := 0;
    end;

    { the break mask's bits }
    term_$opt_err_enable: begin
      sio_$k_inq_param(line, params, [13], status);
      if 0 in params.break_mask then
        flow := flow + [0];
      if 1 in params.break_mask then
        flow := flow + [1];
      if 3 in params.break_mask then
        flow := flow + [2];
      if 4 in params.break_mask then
        flow := flow + [3];
      value.bits := flow;
    end;

    otherwise begin
      status.all := status_$term_invalid_option;
    end;
  end;

  term_$status_convert(status);
end;
